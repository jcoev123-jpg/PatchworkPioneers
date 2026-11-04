class_name StitchedEnemyCatalog
extends RefCounted
## Design v4 "Stitched" S5 enemy roster loader (STITCHED_DESIGN.md section 12).
##
## The canonical enemy catalogs in data/enemies/ now carry an authored "stitched" profile beside
## their untouched legacy card fields. This file is the one pure, scene-free place that reads and
## validates those profiles and matches each foe to its one droppable foreign part in
## data/parts/enemy_parts.json. Nothing here reads a scene, rolls randomness or mutates state.
##
## A profile is:
##   {"max_hp", "speed", "dodge", "acc", "prot",
##    "is_boss": bool, "turns_per_round": 1|2, "trophy": "<part id>",
##    "abilities": [StitchedParts ability records]}
## Bosses alone author turns_per_round 2 (the two-turn exception). Every foe owns exactly one
## unique, owner-"any", tier-I/II/III part. A repeated enemy id (the tough-normal records also
## shipped in run_enemies.json) must repeat the identical record and profile.
##
## The behemoth's second phase lives beside its legacy intent in
## data/enemies/m05_behemoth_phase_two.json under "stitched_phase_two"; it is validated as a
## distinct, legal ability kit and exposed by foe_for(..., PHASE_TWO) without changing phase one.

const TIER_NORMAL := "normal"
const TIER_ELITE := "elite"
const TIER_BOSS := "boss"
const CATALOGS := [
	{"path": "res://data/enemies/starter_enemies.json", "tier": TIER_NORMAL},
	{"path": "res://data/enemies/run_enemies.json", "tier": TIER_NORMAL},
	{"path": "res://data/enemies/v3_tough_normals.json", "tier": TIER_NORMAL},
	{"path": "res://data/enemies/m04_elites.json", "tier": TIER_ELITE},
	{"path": "res://data/enemies/boss.json", "tier": TIER_BOSS},
]
const PHASE_TWO_PATH := "res://data/enemies/m05_behemoth_phase_two.json"
const PARTS_PATH := "res://data/parts/enemy_parts.json"
const PROFILE_FIELDS := [
	"max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round", "trophy",
	"abilities",
]
const PHASE_ONE := "first"
const PHASE_TWO := "second"
const MAX_PROFILE_HP := 500
const MAX_SPEED := 20
const MAX_DODGE := 50
const MAX_ACC := 50
const MAX_PROT := 80


## Reads every canonical enemy catalog, the behemoth phase-two record and the enemy part catalog.
## A missing, unreadable or malformed file fails closed; it never returns partial data.
static func load_catalog(parts_path: String = PARTS_PATH) -> Dictionary:
	var documents: Array = []
	for entry in CATALOGS:
		var parsed: Variant = _read_json(str(entry["path"]))
		if not parsed is Array:
			return _error("enemy catalog is missing or not an array: " + str(entry["path"]))
		documents.append({"path": str(entry["path"]), "tier": str(entry["tier"]), "entries": parsed})
	var phase_two: Variant = _read_json(PHASE_TWO_PATH)
	if not phase_two is Dictionary:
		return _error("enemy phase-two record is missing or not an object: " + PHASE_TWO_PATH)
	var parts_document: Variant = _read_json(parts_path)
	if not parts_document is Dictionary or not parts_document.has("parts"):
		return _error("enemy parts catalog is missing or has no parts: " + parts_path)
	return build_catalog(documents, phase_two, parts_document["parts"])


## Pure validation over already-parsed data. Returns
## {"ok": true, "error": "", "enemies", "foes", "trophies", "phase_two", "parts",
##  "parts_by_id", "order"} or {"ok": false, "error": message, ...empty maps}.
static func build_catalog(documents: Variant, phase_two: Variant, part_entries: Variant) -> Dictionary:
	if not documents is Array or documents.is_empty():
		return _error("enemy catalogs are not a nonempty array")
	var parts := StitchedParts.build_catalog(part_entries)
	if not bool(parts.get("ok", false)):
		return _error(str(parts.get("error", "invalid enemy parts")))
	var records: Dictionary = {}
	var tiers: Dictionary = {}
	var order: Array = []
	for raw_document in documents:
		if not raw_document is Dictionary:
			return _error("enemy catalog entry is not a dictionary")
		var document: Dictionary = raw_document
		var tier := _text(document.get("tier"))
		if not tier in [TIER_NORMAL, TIER_ELITE, TIER_BOSS]:
			return _error("enemy catalog has an unknown tier: " + str(document.get("tier")))
		var entries: Variant = document.get("entries")
		if not entries is Array:
			return _error("enemy catalog entries are not an array: " + str(document.get("path", "")))
		for raw_record in entries:
			if not raw_record is Dictionary:
				return _error("enemy record is not a dictionary in " + str(document.get("path", "")))
			var record: Dictionary = raw_record
			var enemy_id := _text(record.get("id"))
			if enemy_id.is_empty():
				return _error("enemy record needs a nonempty id")
			if _text(record.get("name")).is_empty():
				return _error("enemy " + enemy_id + " needs a nonempty name")
			if _positive_int(record.get("max_hp")) <= 0:
				return _error("enemy " + enemy_id + " needs positive max_hp")
			if records.has(enemy_id):
				if records[enemy_id] != record:
					return _error("enemy " + enemy_id + " is repeated with a mismatched record")
				if str(tiers[enemy_id]) != tier:
					return _error("enemy " + enemy_id + " is repeated across different catalogs")
				continue
			records[enemy_id] = record
			tiers[enemy_id] = tier
			order.append(enemy_id)
	if records.is_empty():
		return _error("no authored enemies were found")
	var enemies: Dictionary = {}
	var foes: Dictionary = {}
	var trophies: Dictionary = {}
	var owners: Dictionary = {}
	for enemy_id in order:
		var validated := _validate_profile(records[enemy_id], str(tiers[enemy_id]), parts)
		if not bool(validated.get("ok", false)):
			return _error(str(validated.get("error", "invalid enemy profile")))
		var trophy := str(validated["trophy"])
		if owners.has(trophy):
			return _error(
				"enemy trophy is shared by %s and %s: %s" % [str(owners[trophy]), enemy_id, trophy]
			)
		owners[trophy] = enemy_id
		enemies[enemy_id] = validated["enemy"]
		foes[enemy_id] = validated["foe"]
		trophies[enemy_id] = trophy
	var second_phase := _validate_phase_two(phase_two, records, tiers, foes, parts)
	if not bool(second_phase.get("ok", false)):
		return _error(str(second_phase.get("error", "invalid phase-two record")))
	return {
		"ok": true,
		"error": "",
		"enemies": enemies,
		"foes": foes,
		"trophies": trophies,
		"phase_two": second_phase["kits"],
		"parts": parts["parts"],
		"parts_by_id": parts["by_id"],
		"order": order,
	}


## A StitchedRules-ready foe definition for one canonical enemy id. The returned dictionary can be
## passed straight into StitchedRules.create({"foes": [foe]}); empty when the id is unknown.
static func foe_for(catalog: Dictionary, enemy_id: String, phase: String = PHASE_ONE) -> Dictionary:
	if not bool(catalog.get("ok", false)):
		return {}
	var foes: Dictionary = catalog.get("foes", {})
	if not foes.has(enemy_id):
		return {}
	var stored: Dictionary = foes[enemy_id]
	var foe: Dictionary = stored.duplicate(true)
	if phase == PHASE_TWO:
		var kits: Dictionary = catalog.get("phase_two", {})
		if not kits.has(enemy_id):
			return {}
		var kit: Dictionary = kits[enemy_id]
		foe["abilities"] = kit["abilities"].duplicate(true)
	elif phase != PHASE_ONE:
		return {}
	return foe


## The single foreign part dropped by one canonical enemy id, or "" when unknown.
static func trophy_for(catalog: Dictionary, enemy_id: String) -> String:
	if not bool(catalog.get("ok", false)):
		return ""
	return str(catalog.get("trophies", {}).get(enemy_id, ""))


## True when the catalog has an authored kit for the id and it is the boss tier.
static func is_boss(catalog: Dictionary, enemy_id: String) -> bool:
	return bool(catalog.get("foes", {}).get(enemy_id, {}).get("is_boss", false))


static func _validate_profile(record: Dictionary, tier: String, parts: Dictionary) -> Dictionary:
	var enemy_id := str(record["id"])
	var raw_profile: Variant = record.get("stitched")
	if not raw_profile is Dictionary:
		return _profile_error(enemy_id, "has no stitched profile")
	var profile: Dictionary = raw_profile
	for field in profile:
		if not field is String or not field in PROFILE_FIELDS:
			return _profile_error(enemy_id, "has an unknown profile field: " + str(field))
	for field in PROFILE_FIELDS:
		if not profile.has(field):
			return _profile_error(enemy_id, "is missing the profile field: " + field)
	var max_hp := _positive_int(profile.get("max_hp"))
	if max_hp <= 0 or max_hp > MAX_PROFILE_HP:
		return _profile_error(enemy_id, "needs a positive profile max_hp")
	var speed := _nonnegative_int(profile.get("speed"))
	var dodge := _nonnegative_int(profile.get("dodge"))
	var acc := _nonnegative_int(profile.get("acc"))
	var prot := _nonnegative_int(profile.get("prot"))
	if speed < 0 or speed > MAX_SPEED:
		return _profile_error(enemy_id, "has an illegal SPEED")
	if dodge < 0 or dodge > MAX_DODGE:
		return _profile_error(enemy_id, "has an illegal DODGE")
	if acc < 0 or acc > MAX_ACC:
		return _profile_error(enemy_id, "has an illegal ACC")
	if prot < 0 or prot > MAX_PROT:
		return _profile_error(enemy_id, "has an illegal PROT")
	var boss: Variant = profile.get("is_boss")
	if not boss is bool:
		return _profile_error(enemy_id, "is_boss must be a boolean")
	if bool(boss) != (tier == TIER_BOSS):
		return _profile_error(enemy_id, "is_boss must match its canonical catalog tier")
	var turns := _positive_int(profile.get("turns_per_round"))
	var expected_turns := 2 if bool(boss) else 1
	if turns != expected_turns:
		return _profile_error(
			enemy_id, "must take exactly %d turn(s) per round" % expected_turns
		)
	var trophy := _text(profile.get("trophy"))
	if trophy.is_empty():
		return _profile_error(enemy_id, "needs a trophy part id")
	var by_id: Dictionary = parts["by_id"]
	if not by_id.has(trophy):
		return _profile_error(enemy_id, "names an unknown trophy part: " + trophy)
	var part: Dictionary = by_id[trophy]
	if str(part["owner"]) != "any":
		return _profile_error(enemy_id, "trophy is not a foreign any-owner part: " + trophy)
	var part_tiers: Dictionary = part["tiers"]
	if not part_tiers.has("2") or not part_tiers.has("3"):
		return _profile_error(enemy_id, "trophy needs stitch tiers II and III: " + trophy)
	var abilities_result := _validate_abilities(profile.get("abilities"), "enemy " + enemy_id)
	if not bool(abilities_result.get("ok", false)):
		return _profile_error(enemy_id, str(abilities_result["error"]))
	var abilities: Array = abilities_result["abilities"]
	var attacks := 0
	for ability in abilities:
		if str(ability["target_side"]) == "enemy":
			attacks += 1
	if attacks == 0:
		return _profile_error(enemy_id, "needs at least one enemy-targeted action")
	var foe := {
		"id": enemy_id,
		"name": str(record["name"]),
		"max_hp": max_hp,
		"speed": speed,
		"dodge": dodge,
		"acc": acc,
		"prot": prot,
		"is_boss": bool(boss),
		"turns_per_round": turns,
		"abilities": abilities,
	}
	var enemy := {
		"id": enemy_id,
		"name": str(record["name"]),
		"tier": tier,
		"max_hp": max_hp,
		"trophy": trophy,
		"is_boss": bool(boss),
		"turns_per_round": turns,
	}
	return {"ok": true, "error": "", "foe": foe, "enemy": enemy, "trophy": trophy}


static func _validate_phase_two(
	phase_two: Variant, records: Dictionary, tiers: Dictionary, foes: Dictionary, parts: Dictionary
) -> Dictionary:
	if not phase_two is Dictionary:
		return {"ok": false, "error": "enemy phase-two record is not an object", "kits": {}}
	var record: Dictionary = phase_two
	var boss_id := _text(record.get("boss_id"))
	if boss_id.is_empty() or not records.has(boss_id):
		return {"ok": false, "error": "phase-two boss_id is not a canonical enemy", "kits": {}}
	if str(tiers.get(boss_id, "")) != TIER_BOSS:
		return {"ok": false, "error": "phase-two boss_id is not a boss", "kits": {}}
	if not _integral(record.get("phase")) or int(record.get("phase")) != 2:
		return {"ok": false, "error": "phase-two phase must be 2", "kits": {}}
	var threshold := _positive_int(record.get("threshold_hp"))
	var boss_foe: Dictionary = foes[boss_id]
	var boss_hp := int(boss_foe["max_hp"])
	if threshold <= 0 or threshold >= boss_hp:
		return {"ok": false, "error": "phase-two threshold_hp must fall inside the boss HP", "kits": {}}
	var raw_kit: Variant = record.get("stitched_phase_two")
	if not raw_kit is Dictionary:
		return {"ok": false, "error": "phase-two record has no stitched_phase_two kit", "kits": {}}
	var kit: Dictionary = raw_kit
	for field in kit:
		if not field is String or str(field) != "abilities":
			return {"ok": false, "error": "phase-two kit has an unknown field: " + str(field)}
	var result := _validate_abilities(kit.get("abilities"), "enemy " + boss_id + " phase two")
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": str(result["error"]), "kits": {}}
	var abilities: Array = result["abilities"]
	var phase_one_ids: Dictionary = {}
	var phase_one: Array = boss_foe["abilities"]
	for ability in phase_one:
		phase_one_ids[str(ability["id"])] = true
	# A phase-two kit must change its actions, not merely repeat a phase-one id.
	for ability in abilities:
		if phase_one_ids.has(str(ability["id"])):
			return {
				"ok": false,
				"error": "phase-two ability repeats a phase-one id: " + str(ability["id"]),
				"kits": {},
			}
	return {
		"ok": true,
		"error": "",
		"kits": {
			boss_id: {
				"threshold_hp": threshold,
				"abilities": abilities,
			},
		},
	}


static func _validate_abilities(value: Variant, label: String) -> Dictionary:
	if not value is Array or value.is_empty():
		return {"ok": false, "error": label + " needs at least one ability", "abilities": []}
	var abilities: Array = []
	var seen: Dictionary = {}
	for entry in value:
		var result := StitchedParts.validate_ability(entry, label + " ability")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": str(result["error"]), "abilities": []}
		var ability: Dictionary = result["ability"]
		var ability_id := str(ability["id"])
		if seen.has(ability_id):
			return {
				"ok": false,
				"error": label + " repeats the ability id " + ability_id,
				"abilities": [],
			}
		seen[ability_id] = true
		abilities.append(ability)
	return {"ok": true, "error": "", "abilities": abilities}


static func _read_json(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return null
	return JSON.parse_string(source)


static func _integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value)


static func _positive_int(value: Variant) -> int:
	if not _integral(value):
		return -1
	return int(value)


static func _nonnegative_int(value: Variant) -> int:
	if not _integral(value) or int(value) < 0:
		return -1
	return int(value)


static func _text(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var text: String = value
	if text.is_empty() or text != text.strip_edges():
		return ""
	return text


static func _profile_error(enemy_id: String, message: String) -> Dictionary:
	return {"ok": false, "error": "enemy " + enemy_id + " " + message, "foe": {}, "enemy": {}, "trophy": ""}


static func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"enemies": {},
		"foes": {},
		"trophies": {},
		"phase_two": {},
		"parts": [],
		"parts_by_id": {},
		"order": [],
	}
