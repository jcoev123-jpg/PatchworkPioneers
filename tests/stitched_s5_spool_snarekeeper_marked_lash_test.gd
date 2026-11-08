extends SceneTree
## S5 Spool Snarekeeper: the canonical Snare Lash cuts the struck doll's seam (Tangled 1 + Snip 1),
## its read-only chooser severs the most-frayed legal Marked doll, and the real live foe driver
## commits that choice. Uses the shipped elite catalog, the four-hero preview fixture, the
## authored pose manifest and public seeded battle receipts.

const ELITE_PATH := "res://data/enemies/m04_elites.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const POSES_PATH := "res://data/art/move_poses.json"
const POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const FOE := "spool_snarekeeper"
const LASH := {
	"id": "snare_lash", "name": "Snare Lash", "kind": "melee",
	"launch": [1, 3], "target": [1, 2, 3], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [4, 5], "crit": 0, "mark_damage": 3,
	"effects": {"tangled": 1, "snip": 1}, "self_move": 0, "move": "attack2",
}
const SNARE := {
	"id": "spool_snare", "name": "Spool Snare", "kind": "debuff",
	"launch": [1, 4], "target": [2, 3, 4], "target_side": "enemy", "multi": false,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"pull": 1, "fray": 6, "mark": 3},
	"self_move": 0, "move": "skill",
}

var failures: Array[String] = []
var checks := 0
var recording := true
var catalog: Dictionary = {}
var preview: Dictionary = {}
var pose_doc: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_spool_snarekeeper_marked_lash_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not recording:
		return
	checks += 1
	if not condition:
		failures.append(message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed_preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	var parsed_poses: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES_PATH))
	_check(bool(catalog.get("ok", false)) and parsed_preview is Dictionary and parsed_poses is Dictionary,
		"AC1: the real elite catalog, four-hero preview fixture and pose manifest load")
	if not bool(catalog.get("ok", false)) or not parsed_preview is Dictionary \
			or not parsed_poses is Dictionary:
		_finish()
		return
	preview = parsed_preview
	pose_doc = parsed_poses
	_contract()
	_priority_cases()
	_reel_then_hunt()
	_lash_receipts()
	await _live_driver()
	_finish()


# ---------------------------------------------------------------- AC1 authored contract

func _contract() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITE_PATH))
	_check(raw is Array and not (raw as Array).is_empty(),
		"AC1: the real elite catalog is a nonempty array")
	if not raw is Array:
		return
	var record: Dictionary = {}
	var anchor: Dictionary = {}
	var lash_holders: Array = []
	for entry in raw:
		if not entry is Dictionary:
			continue
		var enemy_id := str(entry.get("id", ""))
		if enemy_id == FOE:
			record = entry
		elif enemy_id == "zipper_hauler":
			anchor = entry
		for ability in entry.get("stitched", {}).get("abilities", []):
			if str(ability.get("id", "")) == "snare_lash":
				lash_holders.append(enemy_id)
	_check(not record.is_empty(), "AC1: the canonical Spool Snarekeeper record is present")
	_check(not anchor.is_empty(), "AC1: a named untouched elite anchor is present instead of a catalog total")
	_check(lash_holders == [FOE],
		"AC1: only the Spool Snarekeeper authors the Snare Lash id")
	if record.is_empty():
		return
	var profile: Dictionary = record.get("stitched", {})
	_check(int(profile.get("max_hp", 0)) == 40 and int(profile.get("speed", -1)) == 4
		and int(profile.get("dodge", -1)) == 5 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 8 and profile.get("is_boss") == false
		and int(profile.get("turns_per_round", 0)) == 1
		and str(profile.get("trophy", "")) == "spool_snarekeeper_snare",
		"AC1: HP, SPEED, DODGE, ACC, PROT, tier and trophy stay canonical")
	_check(str(record.get("name", "")) == "Spool Snarekeeper"
		and int(record.get("max_hp", 0)) == 40
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/spool_snarekeeper.png",
		"AC1: legacy name, health and art path are preserved")
	var legacy: Dictionary = record.get("intent", {})
	var actions: Array = legacy.get("actions", [])
	_check(legacy.get("target") == "front" and actions.size() == 5
		and str(actions[0].get("type", "")) == "shove" and int(actions[0].get("weight", 0)) == 2
		and int(actions[2].get("amount", 0)) == 8 and str(actions[3].get("move", "")) == "attack2"
		and int(actions[4].get("hits", 0)) == 2,
		"AC1: the untouched legacy weighted intent keeps its target, order and numbers")
	var abilities: Array = profile.get("abilities", [])
	var lash_found: Array = abilities.filter(func(ability: Dictionary) -> bool:
		return str(ability.get("id", "")) == "snare_lash")
	var snare_found: Array = abilities.filter(func(ability: Dictionary) -> bool:
		return str(ability.get("id", "")) == "spool_snare")
	_check(lash_found.size() == 1
		and lash_found[0] == JSON.parse_string(JSON.stringify(LASH)),
		"AC1: Snare Lash keeps its ranks, ACC 88, 4-5 damage, Mark 3 and Tangled 1, now with Snip 1")
	_check(snare_found.size() == 1
		and snare_found[0] == JSON.parse_string(JSON.stringify(SNARE)),
		"AC1: Spool Snare stays exactly authored with pull 1, Fray 6 and Mark 3")
	for authored in [LASH, SNARE]:
		var validated := StitchedParts.validate_ability(authored)
		_check(bool(validated.get("ok", false)),
			"AC1: StitchedParts still accepts " + str(authored["id"]))
	var anchor_ids: Array = anchor.get("stitched", {}).get("abilities", []).map(
		func(ability: Dictionary) -> String: return str(ability.get("id", "")))
	var anchor_drag: Dictionary = anchor.get("stitched", {}).get("abilities", [])[1].get("effects", {})
	_check(anchor_ids == ["hauler_slam", "chain_drag"]
		and anchor_drag.size() == 2 and int(anchor_drag.get("pull", 0)) == 1
		and int(anchor_drag.get("fray", 0)) == 4,
		"AC1: the neighbouring Zipper Hauler record is untouched")
	var foe := StitchedEnemyCatalog.foe_for(catalog, FOE)
	var loaded: Array = foe.get("abilities", []).filter(func(ability: Dictionary) -> bool:
		return str(ability.get("id", "")) == "snare_lash")
	var validated_lash := StitchedParts.validate_ability(LASH)
	_check(not foe.is_empty() and bool(validated_lash.get("ok", false))
		and loaded.size() == 1 and loaded[0] == validated_lash.get("ability", {})
		and int(loaded[0].get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(loaded[0].get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3])
		and loaded[0].get("effects") == {"tangled": 1, "snip": 1}
		and int(foe.get("prot", 0)) == 8
		and StitchedEnemyCatalog.trophy_for(catalog, FOE) == "spool_snarekeeper_snare",
		"AC1: the real loader publishes the normalised Lash with Snip 1 and unchanged profile")
	var poses: Dictionary = pose_doc.get("enemies", {}).get(FOE, {})
	_check(str(LASH["move"]) == "attack2" and str(SNARE["move"]) == "skill"
		and str(poses.get("attack2", {}).get("name", "")) == "Hook Yank"
		and str(poses.get("attack2", {}).get("art", "")) == "res://assets/paper/enemies/spool_snarekeeper_attack2.png"
		and str(poses.get("skill", {}).get("name", "")) == "Set the Trap"
		and str(poses.get("skill", {}).get("art", "")) == "res://assets/paper/enemies/spool_snarekeeper_skill.png",
		"AC1: both abilities keep their existing authored attack2 and skill poses")
	var pools: Variant = JSON.parse_string(FileAccess.get_file_as_string(POOLS_PATH))
	var routed := 0
	if pools is Dictionary:
		for section in pools:
			if not pools[section] is Dictionary:
				continue
			for pool_id in pools[section]:
				if (pools[section][pool_id].get("enemy_ids", []) as Array).has(FOE):
					routed += 1
	_check(routed >= 1,
		"AC1: the unchanged typed Fight/Elite pool still pairs the Snarekeeper with its guard")


# ---------------------------------------------------------------- fixtures

func _config(ids: Array, seed_value: int) -> Dictionary:
	var config: Dictionary = preview.duplicate(true)
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog.get("parts", []).duplicate(true))
	config["foes"] = []
	for enemy_id in ids:
		config["foes"].append(StitchedEnemyCatalog.foe_for(catalog, str(enemy_id)))
	return config


func _battle(ids: Array, seed_value: int) -> StitchedRules:
	var created := StitchedRules.create(_config(ids, seed_value))
	_check(bool(created.get("ok", false)),
		"AC2: a real seeded four-versus-" + str(ids.size()) + " fight builds")
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size(),
		"AC2: the fixture really seats four dolls and its authored foes")
	return battle


func _to(battle: StitchedRules, actor_id: String, wanted_round: int) -> bool:
	for step in range(200):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id and battle.round_number() == wanted_round:
			return true
		if battle.round_number() > wanted_round:
			return false
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _hero_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _snarekeeper(battle: StitchedRules) -> Dictionary:
	return StitchedFoeIntent.choose(battle, battle.get_unit(FOE))


# ---------------------------------------------------------------- AC2 chooser priority

func _restore(battle: StitchedRules, baseline: Dictionary) -> void:
	for unit_id in baseline:
		battle._units[unit_id] = baseline[unit_id].duplicate(true)


## One labelled test-only priority fixture: ranks map to [FRAY, marked], and the optional flags
## map mutates a rank's authoritative unit record (dead, lost, hp) the way a real fight would.
func _case(battle: StitchedRules, baseline: Dictionary, marks: Dictionary,
		expected_rank: int, note: String, flags: Dictionary = {}) -> void:
	_restore(battle, baseline)
	for rank in marks:
		var unit_id := _hero_at(battle, int(rank))
		var reading: Array = marks[rank]
		battle._units[unit_id]["fray"] = int(reading[0])
		if bool(reading[1]):
			battle._units[unit_id]["statuses"]["mark"] = 3
	for rank in flags:
		var unit_id := _hero_at(battle, int(rank))
		for key in flags[rank]:
			battle._units[unit_id][str(key)] = flags[rank][key]
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var choice := _snarekeeper(battle)
	_check(str(choice.get("ability_id", "")) == "snare_lash"
		and int(choice.get("target_rank", 0)) == expected_rank
		and choice.get("affected_ranks") == [expected_rank]
		and str(choice.get("target_side", "")) == "hero"
		and int(choice.get("base_mark_damage", 0)) == 3
		and choice.get("base_effects") == {"tangled": 1, "snip": 1}, note)
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		note + ": chooser remains read-only and spends no RNG")


func _priority_cases() -> void:
	var battle := _battle([FOE, "ragling"], 11)
	if battle == null:
		return
	_check(_to(battle, FOE, 3), "AC2: seeded four-versus-two fight reaches round three's Lash turn")
	if battle.current_actor_id() != FOE or battle.round_number() != 3:
		return
	var baseline: Dictionary = {}
	for hero in battle.get_heroes():
		baseline[str(hero["id"])] = hero.duplicate(true)
	_check(baseline.size() == 4 and not _hero_at(battle, 4).is_empty(),
		"AC2: precondition: four ranked dolls exist, including an out-of-reach rank 4")
	var opening := _snarekeeper(battle)
	_check(str(opening.get("ability_id", "")) == "snare_lash"
		and int(opening.get("target_rank", 0)) == 1,
		"AC2: an unmarked round-three Lash still starts at the nearest legal rank 1")
	_case(battle, baseline, {1: [10, true], 2: [40, true], 3: [90, false]}, 2,
		"AC2: among two Marked dolls the greater FRAY wins even when it sits further back")
	_case(battle, baseline, {1: [90, false], 2: [50, true], 3: [50, true]}, 2,
		"AC2: equal-FRAY Marked rivals keep the lower, nearer rank")
	_case(battle, baseline, {1: [50, true], 2: [50, true], 3: [50, true]}, 1,
		"AC2: a three-way equal-FRAY tie still keeps the front rank")
	_case(battle, baseline, {1: [10, false], 2: [40, false], 3: [50, false]}, 1,
		"AC2: expired Mark fall back to the ordinary nearest legal rank")
	_case(battle, baseline, {1: [10, true], 4: [90, true]}, 1,
		"AC2: a Marked rank 4 cannot win because Snare Lash's authored reach stops at rank 3")
	_case(battle, baseline, {1: [10, true], 2: [40, true]}, 2,
		"AC2: a Marked but dead doll is excluded", {1: {"dead": true}})
	_case(battle, baseline, {1: [10, true], 2: [40, true]}, 1,
		"AC2: a Marked but LOST doll is excluded", {2: {"lost": true}})
	_case(battle, baseline, {1: [10, true], 2: [40, true]}, 1,
		"AC2: a Marked non-living zero-HP doll is excluded", {2: {"hp": 0}})
	_restore(battle, baseline)
	var restored := _snarekeeper(battle)
	_check(str(restored.get("ability_id", "")) == "snare_lash"
		and int(restored.get("target_rank", 0)) == 1,
		"AC2: restoring the authoritative fixture returns the ordinary rank-1 fallback")


# ---------------------------------------------------------------- AC4 reel then hunt

func _reel_trace(seed_value: int) -> Dictionary:
	var battle := _battle([FOE, "ragling"], seed_value)
	if battle == null or not _to(battle, FOE, 2):
		return {}
	var choice := _snarekeeper(battle)
	if str(choice.get("ability_id", "")) != "spool_snare" \
			or int(choice.get("target_rank", 0)) != 4:
		return {}
	var before := battle.get_unit(_hero_at(battle, 4))
	var reel := battle.use_foe_ability("spool_snare", 4)
	var results: Array = reel.get("results", [])
	if not bool(reel.get("ok", false)) or results.size() != 1 or not bool(results[0].get("hit", false)):
		return {}
	var reeled_id := str(results[0].get("target", ""))
	if reeled_id.is_empty() or not _to(battle, FOE, 3):
		return {}
	return {
		"battle": battle,
		"before": before,
		"reel": reel,
		"reeled": battle.get_unit(reeled_id),
		"hunt": _snarekeeper(battle),
	}


func _reel_then_hunt() -> void:
	var witness: Dictionary = {}
	recording = false
	for seed_value in range(1, 97):
		var trace := _reel_trace(seed_value)
		if not trace.is_empty():
			witness = trace
			witness["seed"] = seed_value
			break
	recording = true
	_check(not witness.is_empty(),
		"AC4: bounded seeds witness the round-two Spool Snare pulling and Marking a rear doll")
	if witness.is_empty():
		return
	var reeled: Dictionary = witness["reeled"]
	var result: Dictionary = witness["reel"]["results"][0]
	_check(int(reeled.get("rank", 0)) == 3
		and int(reeled["statuses"].get("mark", 0)) > 0
		and int(reeled.get("fray", 0)) == int(witness["before"].get("fray", 0)) + 6
		and result.get("shift") == {"ok": true, "from": 4, "to": 3, "swapped": _hero_at(witness["battle"], 4)},
		"AC4: the real Spool Snare reels rank 4 to rank 3 with authored Fray 6 and Mark 3")
	var hunt: Dictionary = witness["hunt"]
	_check(str(hunt.get("ability_id", "")) == "snare_lash"
		and int(hunt.get("target_rank", 0)) == 3
		and hunt.get("affected_ranks") == [3]
		and int(hunt.get("base_mark_damage", 0)) == 3,
		"AC4: the following Lash turn still chases the Marked doll pulled into rank 3")


# ---------------------------------------------------------------- AC3 real receipts

## One unforced round-one Lash: pass to the Snarekeeper's turn, project the legal rank, inject an
## optional test-only Mark, then commit through the public use_foe_ability.
func _lash_trace(seed_value: int, marked: bool) -> Dictionary:
	var battle := _battle([FOE, "ragling"], seed_value)
	if battle == null or not _to(battle, FOE, 1):
		return {}
	var choice := _snarekeeper(battle)
	if str(choice.get("ability_id", "")) != "snare_lash":
		return {}
	var rank := int(choice.get("target_rank", 0))
	var target_id := _hero_at(battle, rank)
	if target_id.is_empty():
		return {}
	if marked:
		battle._units[target_id]["statuses"]["mark"] = 3
	var before := battle.get_unit(target_id)
	var receipt := battle.use_foe_ability("snare_lash", rank)
	return {
		"battle": battle,
		"choice": choice,
		"target_id": target_id,
		"before": before,
		"receipt": receipt,
		"state": battle.state_snapshot(),
		"rng": battle.rng_state(),
	}


func _single_result(receipt: Dictionary) -> Dictionary:
	var results: Array = receipt.get("results", [])
	return results[0] if results.size() == 1 else {}


func _lash_receipts() -> void:
	var hit_seed := 0
	var miss_seed := 0
	recording = false
	for seed_value in range(1, 129):
		var trace := _lash_trace(seed_value, false)
		if trace.is_empty():
			continue
		var result := _single_result(trace["receipt"])
		if result.is_empty():
			continue
		if bool(result.get("hit", false)) and hit_seed == 0:
			hit_seed = seed_value
		elif not bool(result.get("hit", true)) and miss_seed == 0:
			miss_seed = seed_value
		if hit_seed > 0 and miss_seed > 0:
			break
	recording = true
	_check(hit_seed > 0 and miss_seed > 0,
		"AC3: bounded seeds witness a natural Snare Lash hit AND a natural miss")
	if hit_seed > 0:
		var hit := _lash_trace(hit_seed, false)
		var result := _single_result(hit["receipt"])
		var target_id: String = hit["target_id"]
		var battle: StitchedRules = hit["battle"]
		var cut := battle.thread_cuts()
		_check(bool(result.get("hit", false)) and int(result.get("damage", 0)) > 0
			and int(result.get("target_rank", 0)) == int(hit["choice"].get("target_rank", 0))
			and str(result.get("target", "")) == target_id,
			"AC3: the hit seed really strikes the projected legal doll")
		_check(result.get("statuses") == [{"status": "tangled", "duration": 1}]
			and int(battle.get_unit(target_id)["statuses"].get("tangled", 0))
				== (0 if battle.current_actor_id() == target_id else 1),
			"AC3: a confirmed Snare Lash hit still applies Tangled 1")
		_check(result.get("snip") == {"ok": true, "action": "snip", "hero": target_id,
				"after_rank": int(result.get("target_rank", 0))}
			and cut.has(target_id) and int(cut[target_id]) == int(result.get("target_rank", 0)),
			"AC3: the same hit severs the struck doll's seam behind its rank")
		var bases: Array = [StitchedRules.crit_damage(5)] if bool(result.get("crit", false)) else [4, 5]
		var plain_expected: Array = []
		for base in bases:
			plain_expected.append(StitchedRules.damage_after_modifiers(
				base, {}, hit["before"]["statuses"], false, 0, int(hit["before"].get("prot", 0))))
		_check(plain_expected.has(int(result.get("damage", -1))),
			"AC3: an unmarked Lash takes its ordinary 4-5 (or crit) damage before PROT")
		var marked := _lash_trace(hit_seed, true)
		var marked_result := _single_result(marked["receipt"])
		var marked_expected: Array = []
		for base in bases:
			marked_expected.append(StitchedRules.damage_after_modifiers(
				base, {}, marked["before"]["statuses"], true, 3,
				int(marked["before"].get("prot", 0))))
		_check(not marked_result.is_empty() and bool(marked_result.get("hit", false))
			and int(marked_result.get("roll", 0)) == int(result.get("roll", 0))
			and bool(marked_result.get("crit", false)) == bool(result.get("crit", false)),
			"AC3: the same seed replays the identical hit and crit rolls against Marked prey")
		_check(marked_expected.has(int(marked_result.get("damage", -1)))
			and int(marked_result.get("damage", 0)) > int(result.get("damage", 0)),
			"AC3: the authored +3 versus Mark still lands on the marked hit")
		_check(marked_result.get("statuses") == [{"status": "tangled", "duration": 1}]
			and marked_result.get("snip", {}).get("ok") == true,
			"AC3: the Mark bonus never displaces the hit's Tangled 1 and Snip 1")
		var replay := _lash_trace(hit_seed, false)
		_check(not replay.is_empty() and replay["receipt"] == hit["receipt"]
			and replay["state"] == hit["state"] and replay["rng"] == hit["rng"]
			and replay["choice"] == hit["choice"],
			"AC3: the same seed twice matches receipts, HP/status, actor/target and RNG")
	if miss_seed > 0:
		var miss := _lash_trace(miss_seed, false)
		var result := _single_result(miss["receipt"])
		var target_id: String = miss["target_id"]
		var battle: StitchedRules = miss["battle"]
		_check(not bool(result.get("hit", true)) and int(result.get("damage", -1)) == 0
			and result.get("statuses", []).is_empty() and not result.has("snip")
			and int(battle.get_unit(target_id)["statuses"].get("tangled", 0)) == 0
			and int(battle.get_unit(target_id)["hp"]) == int(miss["before"].get("hp", -1))
			and not battle.thread_cuts().has(target_id),
			"AC3: a natural miss cuts nothing, applies no Tangled and keeps the target's HP")


# ---------------------------------------------------------------- live foe driver

func _live_driver() -> void:
	var host := Control.new()
	host.name = "SnarekeeperLashHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var stage := StitchedBattleScreen.new()
	var started := stage.begin(_config([FOE, "ragling"], 11))
	_check(started, "AC2: the real battle screen accepts the canonical four-versus-two fight")
	host.add_child(stage)
	await process_frame
	var battle := stage.battle
	if battle == null or not started:
		_check(false, "AC2: the mounted battle exists for the live driver")
		host.free()
		return
	var reached := false
	for step in range(200):
		if battle.is_over() or battle.round_number() > 3:
			break
		if battle.current_actor_id() == FOE and battle.round_number() == 3:
			reached = true
			break
		if not bool(battle.pass_turn().get("ok", false)):
			break
	_check(reached, "AC2: the live battle reaches the Snarekeeper's round-three Lash turn")
	if reached:
		var marked_id := _hero_at(battle, 2)
		battle._units[marked_id]["statuses"]["mark"] = 3
		battle._units[marked_id]["fray"] = 40
		var projected := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
		_check(str(projected.get("ability_id", "")) == "snare_lash"
			and int(projected.get("target_rank", 0)) == 2
			and projected.get("base_effects") == {"tangled": 1, "snip": 1},
			"AC2: the live projection on that turn names the highest-FRAY legal Marked doll")
		var before := stage.receipts.size()
		stage._drive_foes()
		var receipt: Dictionary = {}
		for index in range(before, stage.receipts.size()):
			var item: Dictionary = stage.receipts[index]
			if str(item.get("actor", "")) == FOE and str(item.get("ability", "")) == "snare_lash":
				receipt = item
				break
		var result := _single_result(receipt)
		_check(not receipt.is_empty() and not result.is_empty(),
			"AC2: the unchanged live foe driver commits exactly one real Snare Lash")
		_check(str(result.get("target", "")) == marked_id and int(result.get("target_rank", 0)) == 2,
			"AC2: the live driver severs the highest-FRAY legal Marked doll, not the nearest")
		if bool(result.get("hit", false)):
			_check(battle.thread_cuts().has(marked_id)
				and int(battle.get_unit(marked_id)["statuses"].get("tangled", 0))
					== (0 if battle.current_actor_id() == marked_id else 1),
				"AC3: the live committed hit cuts the doll's seam and applies Tangled 1")
		else:
			_check(not battle.thread_cuts().has(marked_id)
				and int(battle.get_unit(marked_id)["statuses"].get("tangled", 0)) == 0,
				"AC3: a live committed miss cuts nothing and applies no Tangled")
	host.free()
