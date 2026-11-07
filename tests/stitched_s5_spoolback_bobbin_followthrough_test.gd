extends SceneTree
## S5 spool-backed normal-foe follow-through: Spoolback Hound's Redline Reel and Bobbin Bat's
## Bobbin Drop.
##
## Pure source-record contract: the shipped run_enemies.json still carries each foe's untouched
## legacy card identity/intent plus its two original Stitched actions, and each kit gains exactly
## one appended authored action. The new records are validated by the real StitchedParts rules,
## resolved through the real StitchedEnemyCatalog normal-foe loader and matched to the existing
## authored attack3 paper-puppet poses. Per-ID lookups only: no catalog total or full ID order.
## No RNG, scene, render or reserved battle/status file is involved.

const RUN := "res://data/enemies/run_enemies.json"
const POSES := "res://data/art/move_poses.json"
const PHASE_TWO := "res://data/enemies/m05_behemoth_phase_two.json"

const HOUND := "spoolback_hound"
const BAT := "bobbin_bat"

const SPOOL_BITE := {
	"id": "spool_bite", "name": "Spool Bite", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [4, 6], "crit": 0, "effects": {}, "self_move": 0, "move": "attack2",
}
const BACK_SHOVE := {
	"id": "back_shove", "name": "Back Shove", "kind": "debuff",
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"push": 1}, "self_move": 0, "move": "skill",
}
const REDLINE_REEL := {
	"id": "redline_reel", "name": "Redline Reel", "kind": "ranged",
	"launch": [1, 2, 3], "target": [2, 3, 4], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [2, 4], "crit": 0, "effects": {"pull": 1}, "self_move": 0, "move": "attack3",
}
const HOUND_INTENT := {"target": "front", "actions": [
	{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
	{"type": "attack", "amount": 7, "weight": 3},
	{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
	{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
]}

const BOBBIN_DIVE := {
	"id": "bobbin_dive", "name": "Bobbin Dive", "kind": "melee",
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [3, 4], "crit": 0, "effects": {}, "self_move": 0, "move": "attack2",
}
const SONAR_SHRIEK := {
	"id": "sonar_shriek", "name": "Sonar Shriek", "kind": "debuff",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": false,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"weak": 1}, "self_move": 0, "move": "skill",
}
const BOBBIN_DROP := {
	"id": "bobbin_drop", "name": "Bobbin Drop", "kind": "ranged",
	"launch": [2, 3, 4], "target": [2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 84, "dmg": [2, 3], "crit": 0, "effects": {}, "self_move": 0, "move": "attack3",
}
const BAT_INTENT := {"target": "lowest_living_hp", "actions": [
	{"type": "attack", "amount": 7, "hits": 2, "weight": 4},
	{"type": "debuff", "status": "weak", "amount": 1, "weight": 1},
	{"type": "block", "amount": 4, "weight": 1},
	{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
	{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
]}

var catalog: Dictionary
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"AC4: the real S5 catalog still loads: " + str(catalog.get("error", "")))
	if bool(catalog.get("ok", false)):
		_test_hound()
		_test_bat()
		_test_catalog_refusals()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_spoolback_bobbin_followthrough_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _source(enemy_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	_check(parsed is Array, "AC1: " + RUN + " parses as a JSON array")
	if not parsed is Array:
		return {}
	var matches: Array = parsed.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == enemy_id)
	_check(matches.size() == 1, "AC1: exactly one shipped record for " + enemy_id)
	return matches[0] if matches.size() == 1 else {}


func _authored(record: Dictionary, ability_id: String) -> Array:
	var abilities: Array = record.get("stitched", {}).get("abilities", [])
	return abilities.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == ability_id)


func _pose(enemy_id: String, move: String) -> Dictionary:
	var poses: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	_check(poses is Dictionary, "AC2/AC3: " + POSES + " parses as a JSON object")
	if not poses is Dictionary:
		return {}
	return poses.get("enemies", {}).get(enemy_id, {}).get(move, {})


func _check_ranks(ability: Dictionary, launch: Array, target: Array, label: String) -> void:
	_check(int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask(launch)
		and int(ability.get("target_mask", 0)) == StitchedParts.rank_mask(target),
		"AC2/AC3: %s derives exactly its authored launch/target masks" % label)
	for rank in range(1, 5):
		_check(StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), rank)
			== launch.has(rank),
			"AC2/AC3: %s launch rank %d mask matches the authored list" % [label, rank])
		_check(StitchedParts.ranks_allowed(int(ability.get("target_mask", 0)), rank)
			== target.has(rank),
			"AC2/AC3: %s target rank %d mask matches the authored list" % [label, rank])


func _test_common(enemy_id: String, name: String, legacy_hp: int, flag: String,
		legacy_intent: Dictionary, trophy: String, old_abilities: Array,
		new_ability: Dictionary) -> Dictionary:
	var record := _source(enemy_id)
	if record.is_empty():
		return {}
	_check(str(record.get("name", "")) == name and int(record.get("max_hp", 0)) == legacy_hp
		and bool(record.get(flag, false))
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/%s.png" % enemy_id,
		"AC1: %s legacy name, HP, flag and art path stay exact" % enemy_id)
	_check(record.get("intent") == _json(legacy_intent),
		"AC1: %s entire weighted legacy intent stays exact" % enemy_id)
	var profile: Dictionary = record.get("stitched", {})
	_check(int(profile.get("max_hp", 0)) == legacy_hp
		and int(profile.get("speed", -1)) > 0 and int(profile.get("dodge", -1)) >= 0
		and int(profile.get("acc", -1)) == 0 and int(profile.get("prot", -1)) >= 0
		and not bool(profile.get("is_boss", true))
		and int(profile.get("turns_per_round", 0)) == 1
		and str(profile.get("trophy", "")) == trophy,
		"AC1: %s Stitched stats, one turn and trophy stay exact" % enemy_id)
	var abilities: Array = profile.get("abilities", [])
	var seen: Dictionary = {}
	for ability in abilities:
		var ability_id := str(ability.get("id", ""))
		_check(not seen.has(ability_id) and not ability_id.is_empty(),
			"AC1: %s kit keeps unique ability ids, never overwriting one" % enemy_id)
		seen[ability_id] = true
	var old_ids: Dictionary = {}
	for expected in old_abilities:
		var old_id := str(expected["id"])
		old_ids[old_id] = true
		var matches := _authored(record, old_id)
		_check(matches.size() == 1 and matches[0] == _json(expected),
			"AC1: %s original %s stays byte-exact" % [enemy_id, old_id])
	var appended: Array = []
	for ability in abilities:
		if not old_ids.has(str(ability.get("id", ""))):
			appended.append(ability)
	_check(appended.size() == 1 and appended[0] == _json(new_ability),
		"AC1: %s kit gains exactly the one authored follow-through record" % enemy_id)
	_check(_authored(record, str(new_ability["id"])).size() == 1,
		"AC1: %s names %s exactly once in its kit" % [enemy_id, str(new_ability["id"])])
	return record


func _test_hound() -> void:
	var record := _test_common(HOUND, "Spoolback Hound", 28, "enrage", HOUND_INTENT,
		"spoolback_hound_spool_hide", [SPOOL_BITE, BACK_SHOVE], REDLINE_REEL)
	if record.is_empty():
		return
	var validated := StitchedParts.validate_ability(REDLINE_REEL, "redline_reel")
	_check(bool(validated.get("ok", false)),
		"AC2: Redline Reel validates through the real ability rules: "
			+ str(validated.get("error", "")))
	if not bool(validated.get("ok", false)):
		return
	var ability: Dictionary = validated["ability"]
	_check(str(ability["id"]) == "redline_reel" and str(ability["name"]) == "Redline Reel"
		and str(ability["kind"]) == "ranged" and ability["launch"] == [1, 2, 3]
		and ability["target"] == [2, 3, 4] and str(ability["target_side"]) == "enemy"
		and not bool(ability["multi"]) and int(ability["acc"]) == 87
		and ability["dmg"] == [2, 4] and int(ability["crit"]) == 0
		and int(ability["mark_damage"]) == 0 and ability["effects"] == {"pull": 1}
		and int(ability["self_move"]) == 0 and str(ability["move"]) == "attack3",
		"AC2: Redline Reel is the authored single-target ranged ACC-87 2-4 pull-one action")
	_check_ranks(ability, [1, 2, 3], [2, 3, 4], "Redline Reel")
	_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), 1)
		and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 2)
		and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 3)
		and not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 4),
		"AC2: Redline Reel launches from ranks 1-3 and never rank 4")
	_check(StitchedParts.ranks_allowed(int(ability["target_mask"]), 2)
		and StitchedParts.ranks_allowed(int(ability["target_mask"]), 3)
		and StitchedParts.ranks_allowed(int(ability["target_mask"]), 4)
		and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 1),
		"AC2: Redline Reel reaches target ranks 2-4 and excludes rank 1")
	var pose := _pose(HOUND, "attack3")
	_check(str(pose.get("name", "")) == "Thread Snap"
		and str(pose.get("art", "")) == "res://assets/paper/enemies/spoolback_hound_attack3.png",
		"AC2: Redline Reel keeps its authored attack3 Thread Snap paper-puppet art")
	_check_catalog(HOUND, "Spoolback Hound", "spoolback_hound_spool_hide",
		REDLINE_REEL, ["spool_bite", "back_shove"])
	_check_refusals(record, "redline_reel", {"effects": {"pull": 2}},
		{"launch": [5]}, "Redline Reel")


func _test_bat() -> void:
	var record := _test_common(BAT, "Bobbin Bat", 27, "drain", BAT_INTENT,
		"bobbin_bat_wing", [BOBBIN_DIVE, SONAR_SHRIEK], BOBBIN_DROP)
	if record.is_empty():
		return
	var validated := StitchedParts.validate_ability(BOBBIN_DROP, "bobbin_drop")
	_check(bool(validated.get("ok", false)),
		"AC3: Bobbin Drop validates through the real ability rules: "
			+ str(validated.get("error", "")))
	if not bool(validated.get("ok", false)):
		return
	var ability: Dictionary = validated["ability"]
	_check(str(ability["id"]) == "bobbin_drop" and str(ability["name"]) == "Bobbin Drop"
		and str(ability["kind"]) == "ranged" and ability["launch"] == [2, 3, 4]
		and ability["target"] == [2, 3, 4] and str(ability["target_side"]) == "enemy"
		and bool(ability["multi"]) and int(ability["acc"]) == 84
		and ability["dmg"] == [2, 3] and int(ability["crit"]) == 0
		and int(ability["mark_damage"]) == 0 and ability["effects"] == {}
		and int(ability["self_move"]) == 0 and str(ability["move"]) == "attack3",
		"AC3: Bobbin Drop is the authored multi-target ranged ACC-84 2-3 empty-effect action")
	_check_ranks(ability, [2, 3, 4], [2, 3, 4], "Bobbin Drop")
	_check(int(ability["launch_mask"]) == int(ability["target_mask"]),
		"AC3: Bobbin Drop authorises the same ranks to launch from and reach")
	_check(not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 1)
		and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 2)
		and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 3)
		and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 4),
		"AC3: Bobbin Drop launches from ranks 2-4 and excludes launch rank 1")
	_check(not StitchedParts.ranks_allowed(int(ability["target_mask"]), 1)
		and StitchedParts.ranks_allowed(int(ability["target_mask"]), 2)
		and StitchedParts.ranks_allowed(int(ability["target_mask"]), 3)
		and StitchedParts.ranks_allowed(int(ability["target_mask"]), 4),
		"AC3: Bobbin Drop reaches target ranks 2-4 and excludes target rank 1")
	var pose := _pose(BAT, "attack3")
	_check(str(pose.get("name", "")) == "Bobbin Drop"
		and str(pose.get("art", "")) == "res://assets/paper/enemies/bobbin_bat_attack3.png",
		"AC3: Bobbin Drop keeps its authored attack3 paper-puppet art")
	_check_catalog(BAT, "Bobbin Bat", "bobbin_bat_wing",
		BOBBIN_DROP, ["bobbin_dive", "sonar_shriek"])
	_check_refusals(record, "bobbin_drop", {"effects": {"pull": 2}},
		{"target": [1, 5]}, "Bobbin Drop")


## The real normal-foe loader publishes both foes with their original trophy and normalized kit.
func _check_catalog(enemy_id: String, name: String, trophy: String, new_ability: Dictionary,
		old_ids: Array) -> void:
	_check(StitchedEnemyCatalog.trophy_for(catalog, enemy_id) == trophy,
		"AC4: the loader still awards the original trophy for " + enemy_id)
	var foe := StitchedEnemyCatalog.foe_for(catalog, enemy_id)
	_check(not foe.is_empty() and str(foe.get("name", "")) == name
		and str(catalog.get("enemies", {}).get(enemy_id, {}).get("tier", ""))
			== StitchedEnemyCatalog.TIER_NORMAL,
		"AC4: the real S5 loader resolves " + enemy_id + " as a valid normal foe")
	if foe.is_empty():
		return
	var normalized: Dictionary = StitchedParts.validate_ability(new_ability)["ability"]
	var matches: Array = foe.get("abilities", []).filter(func(entry: Dictionary) -> bool:
		return str(entry.get("id", "")) == str(new_ability["id"]))
	_check(matches.size() == 1 and matches[0] == normalized,
		"AC4: the loader publishes the exact normalized follow-through for " + enemy_id)
	for old_id in old_ids:
		var old_matches: Array = foe.get("abilities", []).filter(func(entry: Dictionary) -> bool:
			return str(entry.get("id", "")) == str(old_id))
		_check(old_matches.size() == 1,
			"AC4: the loader still publishes original " + str(old_id) + " for " + enemy_id)
	var other := BAT if enemy_id == HOUND else HOUND
	_check(StitchedEnemyCatalog.trophy_for(catalog, other)
		!= StitchedEnemyCatalog.trophy_for(catalog, enemy_id),
		"AC4: the two spool-backed foes keep distinct trophy identities")


## Invalid test-only copies fail closed and never mutate the shipped record.
func _check_refusals(record: Dictionary, ability_id: String, effects_change: Dictionary,
		rank_change: Dictionary, label: String) -> void:
	var before: Array = _json(_authored(record, ability_id))
	_check(before.size() == 1, "AC4: " + label + " shipped record is available to copy")
	if before.size() != 1:
		return
	var bad_pull: Dictionary = before[0].duplicate(true)
	for key in effects_change:
		bad_pull[key] = effects_change[key].duplicate(true)
	_check(not bool(StitchedParts.validate_ability(bad_pull).get("ok", true)),
		"AC4: %s with pull=2 fails closed" % label)
	var bad_rank: Dictionary = before[0].duplicate(true)
	for key in rank_change:
		bad_rank[key] = rank_change[key].duplicate(true)
	_check(not bool(StitchedParts.validate_ability(bad_rank).get("ok", true)),
		"AC4: %s with an out-of-range rank fails closed" % label)
	var after: Array = _json(_authored(_source(record.get("id", "")), ability_id))
	_check(before == after,
		"AC4: the rejected copies leave the shipped " + label + " record byte-exact")


## The full canonical build refuses in-memory copies of each new record with bad pull / ranks.
func _test_catalog_refusals() -> void:
	var parts: Array = _parts()
	_check(not parts.is_empty(), "AC4: the real enemy part catalog is available")
	for pair in [[HOUND, "redline_reel"], [BAT, "bobbin_drop"]]:
		var enemy_id := str(pair[0])
		var ability_id := str(pair[1])
		var bad_pull := _build_with(enemy_id, ability_id, {"effects": {"pull": 2}})
		_check(not bool(bad_pull.get("ok", true)),
			"AC4: the normal-foe catalog rejects " + ability_id + " with pull=2")
		var bad_rank := _build_with(enemy_id, ability_id, {"target": [1, 5]})
		_check(not bool(bad_rank.get("ok", true)),
			"AC4: the normal-foe catalog rejects " + ability_id + " with target rank 5")
	_check(bool(catalog.get("ok", false)) and not parts.is_empty(),
		"AC4: the shipped catalog still validates after every in-memory refusal probe")


func _parts() -> Array:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		StitchedEnemyCatalog.PARTS_PATH))
	if document is Dictionary and document.get("parts") is Array:
		return document["parts"]
	return []


func _build_with(enemy_id: String, ability_id: String, change: Dictionary) -> Dictionary:
	var documents: Array = []
	for entry in StitchedEnemyCatalog.CATALOGS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(entry["path"])))
		_check(parsed is Array, "AC4: the probe re-reads a real catalog: " + str(entry["path"]))
		if not parsed is Array:
			return {"ok": false, "error": "catalog did not parse: " + str(entry["path"])}
		documents.append({"path": str(entry["path"]), "tier": str(entry["tier"]),
			"entries": parsed})
	var mutated := false
	for document in documents:
		for record in document["entries"]:
			if not record is Dictionary or str(record.get("id", "")) != enemy_id:
				continue
			for ability in record.get("stitched", {}).get("abilities", []):
				if str(ability.get("id", "")) != ability_id:
					continue
				for key in change:
					ability[key] = change[key].duplicate(true)
				mutated = true
	_check(mutated, "AC4: the in-memory probe found " + ability_id + " to mutate")
	var phase: Variant = JSON.parse_string(FileAccess.get_file_as_string(PHASE_TWO))
	return StitchedEnemyCatalog.build_catalog(documents, phase, _parts())
