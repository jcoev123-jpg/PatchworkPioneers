extends SceneTree
## Spool Stalker Knot Stab: canonical three-action kit, the live Tangled-prey chooser, a real
## committed hit/miss through use_foe_ability, fail-closed refusals and fixed-seed replay.
## Uses the shipped catalog loader, preview roster, authored pose manifest and seeded turns.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const POSES := "res://data/art/move_poses.json"
const FOE := "spool_stalker"
const LASH := {
	"id": "spool_lash", "name": "Spool Lash", "kind": "melee",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [3, 4], "crit": 0, "effects": {"tangled": 2},
	"self_move": 0, "move": "attack2",
}
const KNOT := {
	"id": "knot_stab", "name": "Knot Stab", "kind": "melee",
	"launch": [1, 3], "target": [1, 2, 3], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [4, 6], "crit": 0, "effects": {"snip": 1, "fray": 4},
	"self_move": 0, "move": "attack3",
}
const STALK := {
	"id": "spool_stalk", "name": "Spool Stalk", "kind": "buff",
	"launch": [1, 3], "target": [1, 3], "target_side": "self", "multi": false,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"dodge": 5, "duration": 1},
	"self_move": 0, "move": "skill",
}

var failures: Array[String] = []
var checks := 0
var recording := true
var catalog: Dictionary = {}
var preview: Dictionary = {}


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(bool(catalog.get("ok", false)) and parsed is Dictionary,
		"AC1: the real enemy catalog and shipped four-hero preview load")
	if not bool(catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	preview = parsed
	_contract()
	_rotation()
	var hit_seed := 0
	var miss_seed := 0
	var lash_seed := 0
	recording = false
	for seed_value in range(1, 97):
		var trace := _trace(seed_value, false)
		if trace.is_empty():
			continue
		if bool(trace["hit"]) and hit_seed == 0:
			hit_seed = seed_value
		if not bool(trace["hit"]) and miss_seed == 0:
			miss_seed = seed_value
		if bool(trace["lash_hit"]) and lash_seed == 0:
			lash_seed = seed_value
		if hit_seed > 0 and miss_seed > 0 and lash_seed > 0:
			break
	recording = true
	_check(hit_seed > 0 and miss_seed > 0,
		"AC3: bounded seeds witness a natural Knot Stab hit AND a natural miss")
	_check(lash_seed > 0, "AC2: bounded seed witnesses a natural round-one Spool Lash Tangled hit")
	for seed_value in [hit_seed, miss_seed, lash_seed]:
		if seed_value <= 0:
			continue
		var first := _trace(seed_value, true)
		var replay := _trace(seed_value, true)
		_check(not first.is_empty() and first == replay,
			"AC4: fixed seed " + str(seed_value) + " replays receipts, snapshots, order and RNG")
	_rank_preference()
	_prohibited_launch()
	_unrelated_policies()
	if hit_seed > 0:
		_driver(hit_seed)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_spool_stalker_knot_stab_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not recording:
		return
	checks += 1
	if not condition:
		failures.append(message)


# ---------------------------------------------------------------- AC1 source contract

func _contract() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	_check(raw is Array, "AC1: the canonical run enemy catalog is an array")
	if not raw is Array:
		return
	var matches: Array = raw.filter(func(entry: Dictionary) -> bool:
		return str(entry.get("id", "")) == FOE)
	_check(matches.size() == 1, "AC1: exactly one canonical Spool Stalker record")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	var profile: Dictionary = record.get("stitched", {})
	_check(int(profile.get("max_hp", 0)) == 14 and int(profile.get("speed", -1)) == 6
		and int(profile.get("dodge", -1)) == 8 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 0 and profile.get("is_boss") == false
		and int(profile.get("turns_per_round", 0)) == 1
		and str(profile.get("trophy", "")) == "spool_stalker_thread_legs",
		"AC1: the foe profile and its foreign-part trophy stay unchanged")
	_check(str(record.get("name", "")) == "Spool Stalker" and int(record.get("max_hp", 0)) == 14
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/spool_stalker.png"
		and record.get("intent", {}).get("target") == "exposed"
		and (record.get("intent", {}).get("actions", []) as Array).size() == 6,
		"AC1: legacy name, health, art and weighted intent are preserved")
	var abilities: Array = profile.get("abilities", [])
	var ids: Array = abilities.map(func(ability: Dictionary) -> String:
		return str(ability.get("id", "")))
	_check(ids == ["spool_lash", "knot_stab", "spool_stalk"],
		"AC1: the authored order is Lash as move one, Knot Stab as move two, Spool Stalk as move three")
	for pair in [["spool_lash", LASH], ["knot_stab", KNOT], ["spool_stalk", STALK]]:
		var ability_id: String = pair[0]
		var expected: Dictionary = pair[1]
		var found: Array = abilities.filter(func(ability: Dictionary) -> bool:
			return str(ability.get("id", "")) == ability_id)
		_check(found.size() == 1
			and found[0] == JSON.parse_string(JSON.stringify(expected)),
			"AC1: exact authored " + ability_id + " fields and numbers")
		var validated := StitchedParts.validate_ability(expected)
		_check(bool(validated.get("ok", false)),
			"AC1: StitchedParts accepts the authored " + ability_id)
	var foe := StitchedEnemyCatalog.foe_for(catalog, FOE)
	var validated_knot := StitchedParts.validate_ability(KNOT)
	var loaded: Array = foe.get("abilities", []).filter(func(ability: Dictionary) -> bool:
		return str(ability.get("id", "")) == "knot_stab")
	_check(not foe.is_empty() and bool(validated_knot.get("ok", false))
		and loaded.size() == 1 and loaded[0] == validated_knot.get("ability", {})
		and int(foe.get("max_hp", 0)) == 14 and int(foe.get("speed", -1)) == 6
		and int(foe.get("dodge", -1)) == 8 and int(loaded[0].get("target_mask", 0)) == 14
		and int(loaded[0].get("launch_mask", 0)) == 10
		and StitchedEnemyCatalog.trophy_for(catalog, FOE) == "spool_stalker_thread_legs",
		"AC1: the real loader publishes the normalised Knot Stab kit and profile")
	var pose_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	_check(pose_doc is Dictionary, "AC1: the authored move-pose manifest loads")
	if pose_doc is Dictionary:
		var leg_stab: Dictionary = pose_doc.get("enemies", {}).get(FOE, {}).get("attack3", {})
		_check(leg_stab.get("name") == "Leg Stab"
			and str(leg_stab.get("art", "")) == "res://assets/paper/enemies/spool_stalker_attack3.png"
			and (leg_stab.get("covers", []) as Array).has("attack")
			and str(KNOT["move"]) == "attack3",
			"AC1: Knot Stab selects the existing authored Leg Stab pose art")
	# Named neighbouring records are checked by id, never by a catalog total or ordered list.
	var crab_matches: Array = raw.filter(func(entry: Dictionary) -> bool:
		return str(entry.get("id", "")) == "scissor_crab")
	if crab_matches.size() == 1:
		var crab: Dictionary = crab_matches[0]
		var crab_ids: Array = crab.get("stitched", {}).get("abilities", []).map(
			func(ability: Dictionary) -> String: return str(ability.get("id", "")))
		_check(crab_ids == ["pinch", "thread_snip"]
			and int(crab.get("stitched", {}).get("max_hp", 0)) == 22,
			"AC1: the neighbouring Scissor Crab kit and profile are untouched")


# ---------------------------------------------------------------- fixtures

func _rotation() -> void:
	var pools: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/encounters/m03_typed_battle_pools.json"))
	_check(pools is Dictionary, "AC1: the typed Fight pool document loads")
	if not pools is Dictionary:
		return
	var fights: Dictionary = pools.get("Fight", {})
	var routed := 0
	for pool_id in fights:
		var pool: Dictionary = fights[pool_id]
		if not (pool.get("enemy_ids", []) as Array).has(FOE):
			continue
		routed += 1
		_check(FileAccess.file_exists(str(pool.get("schedule", ""))),
			"AC1: live Fight pool " + str(pool_id) + " keeps its authored schedule file")
	_check(routed >= 1,
		"AC1: the changed Spool Stalker kit reaches the real Fight rotation without a new encounter")


func _config(ids: Array, seed_value: int) -> Dictionary:
	var config: Dictionary = preview.duplicate(true)
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"].duplicate(true))
	config["foes"] = []
	for enemy_id in ids:
		config["foes"].append(StitchedEnemyCatalog.foe_for(catalog, str(enemy_id)))
	return config


func _battle(seed_value: int, ids: Array = [FOE, "scissor_crab"]) -> StitchedRules:
	var created := StitchedRules.create(_config(ids, seed_value))
	_check(bool(created.get("ok", false)),
		"AC2: a genuine seeded four-versus-" + str(ids.size()) + " fight builds")
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size()
		and int(battle.get_unit(FOE).get("rank", 0)) == ids.find(FOE) + 1
		and battle.candle() == 100,
		"AC2: real four-doll line, authored foe rank and bright candle")
	return battle


func _to(battle: StitchedRules, actor_id: String, receipts: Array, snapshots: Array,
		wanted_round: int = 0) -> bool:
	for step in range(130):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id \
				and (wanted_round == 0 or battle.round_number() == wanted_round):
			return true
		if wanted_round > 0 and battle.round_number() > wanted_round:
			return false
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
		receipts.append(passed)
		snapshots.append(battle.state_snapshot())
	return false


func _hero_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _refuse(battle: StitchedRules, ability_id: String, rank: int, expected: String) -> void:
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor := battle.current_actor_id()
	var refused := battle.use_foe_ability(ability_id, rank)
	_check(not bool(refused.get("ok", true)) and refused.get("error") == expected
		and battle.state_snapshot() == snapshot and battle.rng_state() == rng
		and battle.current_actor_id() == actor,
		"AC4: " + expected + " refuses without a state, turn or RNG spend")


# ---------------------------------------------------------------- AC2/3/A4 seeded trace

func _trace(seed_value: int, deep: bool) -> Dictionary:
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	if not _to(battle, FOE, receipts, snapshots, 1):
		return {}
	var front_id := _hero_at(battle, 1)
	var lash_choice := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(str(lash_choice.get("ability_id", "")) == "spool_lash"
		and int(lash_choice.get("target_rank", 0)) == 1
		and lash_choice.get("base_effects") == {"tangled": 2}
		and int(lash_choice.get("base_acc", -1)) == 86
		and lash_choice.get("base_damage") == [3, 4]
		and not bool(lash_choice.get("pass", true)),
		"AC2: round one still opens with the nearest-rank Spool Lash Tangled action")
	var lash := battle.use_foe_ability("spool_lash", 1)
	receipts.append(lash)
	snapshots.append(battle.state_snapshot())
	if not bool(lash.get("ok", false)) or lash.get("results", []).size() != 1:
		return {}
	var lash_result: Dictionary = lash["results"][0]
	var lash_hit := bool(lash_result.get("hit", false))
	var tangled_entries := 0
	for entry in lash_result.get("statuses", []):
		if str(entry.get("status", "")) == "tangled":
			tangled_entries += 1
	if deep:
		var after_lash := battle.get_unit(front_id)
		_check(lash_result.get("target") == front_id
			and int(lash_result.get("target_rank", 0)) == 1
			and lash_result.get("hit") == (int(lash_result.get("roll", 101))
				<= int(lash_result.get("hit_chance", 0)))
			and tangled_entries == (1 if lash_hit else 0)
			and (not lash_hit or (int(after_lash["statuses"].get("tangled", 0)) >= 1
				and int(after_lash["statuses"].get("tangled", 0)) <= 2))
			and (lash_hit or not after_lash["statuses"].has("tangled")),
			"AC2: natural Spool Lash binds Tangled 2 only on its seeded hit")
	if not _to(battle, FOE, receipts, snapshots, 2):
		return {}
	var quiet_state := battle.state_snapshot()
	var quiet_rng := battle.rng_state()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	var rank := int(choice.get("target_rank", 0))
	_check(str(choice.get("ability_id", "")) == "knot_stab"
		and str(choice.get("ability_name", "")) == "Knot Stab"
		and str(choice.get("ability_kind", "")) == "melee"
		and str(choice.get("target_side", "")) == "hero"
		and rank >= 1 and rank <= 3
		and choice.get("affected_ranks") == [rank]
		and not bool(choice.get("multi", true))
		and int(choice.get("base_acc", -1)) == 87
		and choice.get("base_damage") == [4, 6]
		and int(choice.get("base_crit", -1)) == 0
		and choice.get("base_effects") == {"snip": 1, "fray": 4}
		and not bool(choice.get("pass", true))
		and quiet_state == battle.state_snapshot() and quiet_rng == battle.rng_state(),
		"AC2/4: round two advertises the exact authored Knot Stab with no state or RNG mutation")
	if str(choice.get("ability_id", "")) != "knot_stab":
		return {}
	for bad in [0, 4, 5]:
		_refuse(battle, "knot_stab", int(bad), "no legal target in rank " + str(int(bad)))
	var victim_id := _hero_at(battle, rank)
	_check(not victim_id.is_empty(), "AC3: a real living doll occupies the projected rank")
	if victim_id.is_empty():
		return {}
	var foe_before := battle.get_unit(FOE)
	var before := battle.get_unit(victim_id)
	var turn_before := battle.state_snapshot()
	var chance := StitchedRules.hit_chance(87 + int(foe_before.get("acc", 0))
		+ int(battle.candle_band()["enemy_acc"]), StitchedRules.effective_dodge(before),
		int(foe_before.get("miss_streak", 0)))
	var cast := battle.use_foe_ability("knot_stab", rank)
	receipts.append(cast)
	snapshots.append(battle.state_snapshot())
	if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 1:
		return {}
	_check(str(cast.get("actor", "")) == FOE and str(cast.get("ability", "")) == "knot_stab",
		"AC3: the real foe turn commits exactly one Knot Stab")
	var result: Dictionary = cast["results"][0]
	_check(result.get("target") == victim_id and int(result.get("target_rank", 0)) == rank
		and int(result.get("hit_chance", -1)) == chance
		and result.get("hit") == (int(result.get("roll", 101)) <= chance),
		"AC3: Knot Stab rolls its seeded hit against ACC 87 and the victim's real DODGE")
	var hit := bool(result.get("hit", false))
	var after := battle.get_unit(victim_id)
	if hit:
		var possible: Array = []
		var base_rolls: Array = [StitchedRules.crit_damage(6)] \
			if bool(result.get("crit", false)) else [4, 5, 6]
		for base in base_rolls:
			possible.append(StitchedRules.damage_after_modifiers(
				StitchedS1BEffects.enemy_damage(int(base) + int(foe_before.get("dmg_bonus", 0)),
					battle.candle()),
				foe_before["statuses"], before["statuses"], false, 0,
				int(before.get("prot", 0))))
		var expected_fray := 4 + (10 if bool(result.get("crit", false)) else 0)
		_check(possible.has(int(result.get("damage", -1)))
			and int(result.get("damage", 0)) > 0
			and int(result.get("target_hp", -1)) == int(before["hp"]) - int(result["damage"])
			and int(after["hp"]) == int(result["target_hp"])
			and result.get("statuses") == []
			and result.get("snip", {}).get("ok") == true
			and int(result.get("snip", {}).get("after_rank", -1)) == rank
			and battle.thread_cuts() == {victim_id: rank}
			and result.get("fray_event", {}).get("ok") == true
			and int(result.get("fray_event", {}).get("change", -1)) == 4
			and int(after["fray"]) == int(before["fray"]) + expected_fray,
			"AC3: a landed Knot Stab deals legal rolled damage, SNIP 1 behind its victim and FRAY +4")
	else:
		_check(int(result.get("damage", -1)) == 0 and result.get("statuses") == []
			and not result.has("snip") and not result.has("fray_event")
			and battle.thread_cuts().is_empty()
			and int(after["hp"]) == int(before["hp"])
			and int(after["fray"]) == int(before["fray"]),
			"AC3/4: a true seeded miss deals no damage, no cut and no extra fray")
	_check(battle.round_number() > int(turn_before["round"])
		or int(battle.state_snapshot()["turn_index"]) > int(turn_before["turn_index"]),
		"AC3: a committed Knot Stab spends exactly one foe turn")
	return {"hit": hit, "lash_hit": lash_hit, "receipts": receipts,
		"snapshots": snapshots, "state": battle.state_snapshot(),
		"order": battle.turn_order(), "rng": battle.rng_state()}


# ---------------------------------------------------------------- AC2 rank preference

func _rank_seed() -> int:
	for seed_value in range(1, 65):
		var battle := _battle(seed_value)
		if battle == null:
			continue
		var receipts: Array = []
		var snapshots: Array = [battle.state_snapshot()]
		if not _to(battle, FOE, receipts, snapshots, 2):
			continue
		if _hero_at(battle, 3).is_empty() or _hero_at(battle, 2).is_empty():
			continue
		return seed_value
	return 0


func _rank_preference() -> void:
	var seed_value := _rank_seed()
	_check(seed_value > 0, "AC2: a bounded seed reaches the live round-two Spool Stalker turn")
	if seed_value <= 0:
		return
	var battle := _battle(seed_value)
	if battle == null:
		return
	var receipts: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	if not _to(battle, FOE, receipts, snapshots, 2):
		_check(false, "AC2: the rank fixture really reaches the foe's second-round turn")
		return
	var front := _hero_at(battle, 1)
	var middle := _hero_at(battle, 2)
	var far := _hero_at(battle, 3)
	_check(not front.is_empty() and not middle.is_empty() and not far.is_empty()
		and battle.get_unit(front)["statuses"].is_empty()
		and battle.get_unit(middle)["statuses"].is_empty()
		and battle.get_unit(far)["statuses"].is_empty(),
		"AC2: precondition: four healthy, untangled dolls and no earlier cut")
	var plain := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(str(plain.get("ability_id", "")) == "knot_stab"
		and int(plain.get("target_rank", 0)) == 1 and plain.get("affected_ranks") == [1],
		"AC2: with no Tangled doll Knot Stab keeps the ordinary nearest-legal rank-1 fallback")
	# Test-only status setup: a clear, labelled fixture state, never a fabricated attack receipt.
	# Knot Stab's prey preference is proven here without pretending the Lash landed.
	battle._units[far]["statuses"]["tangled"] = 2
	var quiet_state := battle.state_snapshot()
	var quiet_rng := battle.rng_state()
	var hunt := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(str(hunt.get("ability_id", "")) == "knot_stab"
		and int(hunt.get("target_rank", 0)) == 3 and hunt.get("affected_ranks") == [3]
		and not battle.get_unit(front)["statuses"].has("tangled")
		and quiet_state == battle.state_snapshot() and quiet_rng == battle.rng_state(),
		"AC2: the farther legal Tangled doll is chosen past an untangled nearer doll, read-only")
	battle._units[middle]["statuses"]["tangled"] = 2
	var lowest := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(str(lowest.get("ability_id", "")) == "knot_stab"
		and int(lowest.get("target_rank", 0)) == 2 and lowest.get("affected_ranks") == [2],
		"AC2: two legal Tangled dolls keep the lowest legal rank")
	battle._units[middle]["statuses"].erase("tangled")
	var far_again := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(int(far_again.get("target_rank", 0)) == 3,
		"AC2: clearing the nearer Tangled doll returns the first farther legal Tangled rank")
	# A lost Tangled doll is never a legal prey, so the next legal Tangled rank is chosen.
	battle._units[middle]["statuses"]["tangled"] = 2
	battle._units[middle]["lost"] = true
	var skipping := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(int(skipping.get("target_rank", 0)) == 3,
		"AC4: a lost Tangled doll is skipped for the next legal Tangled rank")
	battle._units[middle]["lost"] = false
	battle._units[middle]["statuses"].erase("tangled")
	battle._units[far]["statuses"].erase("tangled")
	var restored := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(int(restored.get("target_rank", 0)) == 1 and restored.get("affected_ranks") == [1],
		"AC2: once the Tangled prey clears, the ordinary nearest target returns")
	# The real foe turn then commits the very preference the intent projected.
	battle._units[far]["statuses"]["tangled"] = 2
	var victim_before := battle.get_unit(far)
	var commit := battle.use_foe_ability("knot_stab", 3)
	_check(bool(commit.get("ok", false))
		and str(commit.get("actor", "")) == FOE
		and str(commit.get("ability", "")) == "knot_stab"
		and commit.get("results", []).size() == 1
		and commit["results"][0].get("target") == far
		and int(commit["results"][0].get("target_rank", 0)) == 3
		and (not bool(commit["results"][0].get("hit", false))
			or (int(commit["results"][0].get("snip", {}).get("after_rank", -1)) == 3
				and int(battle.thread_cuts().get(far, -1)) == 3
				and int(battle.get_unit(far)["fray"]) == int(victim_before["fray"]) + 4
					+ (10 if bool(commit["results"][0].get("crit", false)) else 0))),
		"AC2/3: the real foe turn lands Knot Stab on the farther Tangled doll it chose")
	if not _to(battle, FOE, receipts, snapshots, 3):
		_check(false, "AC4: the fixture reaches the foe's ordinary third-round turn")
		return
	var third := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(str(third.get("ability_id", "")) == "spool_stalk"
		and str(third.get("target_side", "")) == "foe"
		and int(third.get("target_rank", 0)) == int(battle.get_unit(FOE)["rank"])
		and third.get("base_effects") == {"dodge": 5, "duration": 1},
		"AC1/4: the ordinary authored rotation reaches the unchanged Spool Stalk third")


# ---------------------------------------------------------------- AC4 fail-closed launch

func _prohibited_launch() -> void:
	var built := 0
	for seed_value in range(1, 49):
		var battle := _battle(seed_value, ["scissor_crab", FOE, "fray_scavenger"])
		if battle == null:
			continue
		var receipts: Array = []
		var snapshots: Array = [battle.state_snapshot()]
		if not _to(battle, FOE, receipts, snapshots, 2):
			continue
		built += 1
		_check(int(battle.get_unit(FOE)["rank"]) == 2,
			"AC4: a real rank-two Spool Stalker sits outside its authored launch ranks")
		var state := battle.state_snapshot()
		var rng := battle.rng_state()
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
		_check(bool(intent.get("pass", false))
			and str(intent.get("ability_id", "")) == ""
			and int(intent.get("target_rank", -1)) == 0
			and intent.get("affected_ranks", []) == []
			and state == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: with no legal launch rank the intent invents no ability or target")
		_refuse(battle, "knot_stab", 1, "ability cannot launch from rank 2")
		_check(bool(battle.pass_turn().get("ok", false)),
			"AC4: the refused launch leaves its turn available for a legal pass")
		break
	_check(built == 1, "AC4: non-vacuous prohibited-launch fixture")


# ---------------------------------------------------------------- AC4 other target policies

func _unrelated_policies() -> void:
	var pull := _battle(11, ["spool_snarekeeper", "ragling"])
	if pull != null:
		var receipts: Array = []
		var snapshots: Array = [pull.state_snapshot()]
		if _to(pull, "spool_snarekeeper", receipts, snapshots, 2):
			var reel := StitchedFoeIntent.choose(pull, pull.get_unit("spool_snarekeeper"))
			_check(str(reel.get("ability_id", "")) == "spool_snare"
				and int(reel.get("target_rank", 0)) == 4
				and reel.get("affected_ranks") == [4],
				"AC4: the Spool Snarekeeper's unchanged pull still hunts the deepest legal rank")
		else:
			_check(false, "AC4: the pull fixture reaches its second-round turn")
	var hexer := _battle(11, ["spool_hexer", "ragling"])
	if hexer != null:
		var receipts: Array = []
		var snapshots: Array = [hexer.state_snapshot()]
		if _to(hexer, "spool_hexer", receipts, snapshots, 1):
			var plain := StitchedFoeIntent.choose(hexer, hexer.get_unit("spool_hexer"))
			_check(str(plain.get("ability_id", "")) == "hex_bolt"
				and int(plain.get("target_rank", 0)) == 1,
				"AC4: the Spool Hexer's unchanged mark hunt starts at the nearest legal rank")
			# A clearly labelled test-only mark proves the mark policy still outranks distance.
			hexer._units[_hero_at(hexer, 3)]["statuses"]["mark"] = 3
			var marked := StitchedFoeIntent.choose(hexer, hexer.get_unit("spool_hexer"))
			_check(str(marked.get("ability_id", "")) == "hex_bolt"
				and int(marked.get("target_rank", 0)) == 3
				and int(marked.get("base_mark_damage", 0)) == 3,
				"AC4: the Spool Hexer still hunts an existing Mark ahead of a closer doll")
		else:
			_check(false, "AC4: the mark fixture reaches its first-round turn")


# ---------------------------------------------------------------- live screen driver

func _driver(seed_value: int) -> void:
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(_config([FOE, "scissor_crab"], seed_value)),
		"AC2: the real battle screen accepts the canonical four-versus-two Spool Stalker fight")
	if stage.battle == null:
		stage.free()
		return
	var receipts: Array = []
	var snapshots: Array = [stage.battle.state_snapshot()]
	if not _to(stage.battle, FOE, receipts, snapshots, 2):
		_check(false, "AC2: the mounted battle reaches the round-two Spool Stalker turn")
		stage.free()
		return
	stage._drive_foes()
	var observed := -1
	for receipt in stage.receipts:
		if str(receipt.get("actor", "")) == FOE \
				and str(receipt.get("ability", "")) == "knot_stab":
			observed = receipt.get("results", []).size()
			break
	_check(observed == 1,
		"AC2/3: the existing live foe driver commits exactly one real Knot Stab through use_foe_ability")
	stage.free()
