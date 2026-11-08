class_name StitchedDeeperSeams
extends RefCounted
## S15 Deeper Seams: the layer a run adds to each live battle's foes. Per-foe resists
## (which sewn patch rarity pierces), the foe attacks that carry Rot, and floor-depth
## scaling with a slightly softer boss. The authored enemy records stay as they are.

const PATH := "res://data/stitched/s15_deeper_seams.json"
## Ordinary foes grow tougher deeper in the house; the boss itself is a touch softer.
const DEPTH_HP_PERCENT := 5
const DEPTH_DMG_FLOORS := 4
const BOSS_HP_PERCENT := 60
## The boss acts twice a round, so its blows are trimmed too (rounded, never below 1).
const BOSS_DMG_PERCENT := 70
const ROT_MAX := 4

static var _cache: Dictionary = {}


## {"resists": {foe_id: {group: percent}}, "rot_attacks": {foe_id: {ability_id: turns}}},
## or {} when the file (or a passed document) is malformed. Callers get a detached copy.
static func table(document: Variant = null) -> Dictionary:
	var from_file := document == null
	if from_file and not _cache.is_empty():
		return _cache.duplicate(true)
	if document == null:
		document = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not document is Dictionary or not document.get("resists") is Dictionary \
			or not document.get("rot_attacks") is Dictionary:
		return {}
	var resists := {}
	for foe_id in document.resists:
		var raw: Variant = document.resists[foe_id]
		if not foe_id is String or not raw is Dictionary or raw.is_empty():
			return {}
		var resist := {}
		for key in raw:
			if not key in StitchedRules.RESIST_KEYS or not StitchedParts._integral(raw[key]) \
					or int(raw[key]) < 0 or int(raw[key]) > StitchedRules.RESIST_MAX:
				return {}
			resist[key] = int(raw[key])
		resists[foe_id] = resist
	var rot_attacks := {}
	for foe_id in document.rot_attacks:
		var raw: Variant = document.rot_attacks[foe_id]
		if not foe_id is String or not raw is Dictionary or raw.is_empty():
			return {}
		var attacks := {}
		for ability_id in raw:
			if not ability_id is String or not StitchedParts._integral(raw[ability_id]) \
					or int(raw[ability_id]) <= 0 or int(raw[ability_id]) > ROT_MAX:
				return {}
			attacks[ability_id] = int(raw[ability_id])
		rot_attacks[foe_id] = attacks
	var built := {"resists": resists, "rot_attacks": rot_attacks}
	if from_file:
		_cache = built.duplicate(true)
	return built


## Deepens one live-battle foe in place for the given floor and battle kind.
static func apply(foe: Dictionary, floor_number: int, kind: String) -> void:
	var seams := table()
	var foe_id := str(foe.get("id", ""))
	var resist: Dictionary = seams.get("resists", {}).get(foe_id, {})
	if not resist.is_empty():
		foe["resist"] = resist
	var rot: Dictionary = seams.get("rot_attacks", {}).get(foe_id, {})
	for ability in foe.get("abilities", []):
		if rot.has(str(ability.get("id", ""))):
			ability["effects"]["rot"] = int(rot[str(ability.id)])
	depth_scale(foe, floor_number, kind)


static func boss_blow(amount: int) -> int:
	return maxi(1, (amount * BOSS_DMG_PERCENT + 50) / 100)


static func depth_scale(foe: Dictionary, floor_number: int, kind: String) -> void:
	if bool(foe.get("is_boss", false)):
		foe["max_hp"] = maxi(1, int(foe["max_hp"]) * BOSS_HP_PERCENT / 100)
		for ability in foe.get("abilities", []):
			var blow: Array = ability.get("dmg", [0, 0])
			if blow.size() == 2 and int(blow[1]) > 0:
				ability["dmg"] = [boss_blow(int(blow[0])), boss_blow(int(blow[1]))]
		return
	if kind == "Boss" or floor_number <= 1:
		return
	foe["max_hp"] = int(foe["max_hp"]) * (100 + DEPTH_HP_PERCENT * (floor_number - 1)) / 100
	var bonus := (floor_number - 1) / DEPTH_DMG_FLOORS
	if bonus <= 0:
		return
	for ability in foe.get("abilities", []):
		var dmg: Array = ability.get("dmg", [0, 0])
		if dmg.size() == 2 and int(dmg[1]) > 0:
			ability["dmg"] = [int(dmg[0]) + bonus, int(dmg[1]) + bonus]
