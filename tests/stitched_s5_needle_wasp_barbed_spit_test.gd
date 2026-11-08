extends SceneTree
## Needle Wasp barbed rear-line volley and expanded rank-legal sting (S5).
## Contract: the canonical record keeps its identity, weighted intent, Wasp Dart (self_move 1)
## and gains only explicit Sting launch/target [1,2,3] plus a third multi-target Needle Spit
## across hero ranks 2-3. Real seeded four-doll battles commit it through the live rules:
## independent ACC 86 rolls, 2-3 damage, Bleed 2 only on hit, no rank 1/4 victims, blocked-dart
## fallthrough, rank legality, fail-closed refusals and fixed-seed replay.
## Records are found by named id, never by a catalog total or an ordered id list.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const POSES := "res://data/art/move_poses.json"
const FOE := "needle_wasp"
const PARTNER := "felt_bulwark"
const STING := {
	"id": "needle_sting", "name": "Needle Sting", "kind": "melee",
	"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [3, 4], "crit": 0, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack2",
}
const DART := {
	"id": "wasp_dart", "name": "Wasp Dart", "kind": "move",
	"launch": [1, 3], "target": [1, 3], "target_side": "self", "multi": false,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"dodge": 5, "duration": 1},
	"self_move": 1, "move": "skill",
}
const SPIT := {
	"id": "needle_spit", "name": "Needle Spit", "kind": "ranged",
	"launch": [1, 2, 3, 4], "target": [2, 3], "target_side": "enemy", "multi": true,
	"acc": 86, "dmg": [2, 3], "crit": 0, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack3",
}
## Named earlier records that must keep their authored identity (never a catalog total).
const EARLIER_FOES := {
	"fray_scavenger": "Fray Scavenger",
	"button_guard": "Button Guard",
	"spool_stalker": "Spool Stalker",
	"seam_ripper": "Seam Ripper",
	"felt_bulwark": "Felt Bulwark",
	"moth_scribe": "Moth Scribe",
	"pin_skitter": "Pin Skitter",
	"thread_biter": "Thread Biter",
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
	var hit_seed := 0
	var miss_seed := 0
	recording = false
	for seed_value in range(1, 33):
		var witnessed := _witness(seed_value)
		if witnessed.is_empty():
			continue
		if bool(witnessed["any_hit"]) and hit_seed == 0:
			hit_seed = seed_value
		if not bool(witnessed["any_hit"]) and miss_seed == 0:
			miss_seed = seed_value
		if hit_seed > 0 and miss_seed > 0:
			break
	recording = true
	_check(hit_seed > 0 and miss_seed > 0,
		"AC2: bounded seeds 1..32 witness a natural Needle Spit hit AND a natural miss")
	if hit_seed > 0:
		_hit_trace(hit_seed)
	if miss_seed > 0:
		_miss_trace(miss_seed)
	for seed_value in [hit_seed, miss_seed]:
		if seed_value > 0:
			var first := _scripted_trace(seed_value)
			var replay := _scripted_trace(seed_value)
			_check(not first.is_empty() and first == replay,
				"AC4: fixed seed " + str(seed_value)
				+ " replays identical intents, receipts, status clocks, RNG and snapshots")
	_rank_legality()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_needle_wasp_barbed_spit_test: ",
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
	_check(matches.size() == 1, "AC1: exactly one canonical Needle Wasp record")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(str(record.get("name", "")) == "Needle Wasp" and int(record.get("max_hp", 0)) == 22
		and record.get("bleed_on_attack") == true
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/needle_wasp.png",
		"AC1: legacy name, 22 HP, bleed_on_attack flag and art path are preserved")
	var intent: Dictionary = record.get("intent", {})
	var expected_actions: Variant = JSON.parse_string(JSON.stringify([
		{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
		{"type": "attack", "amount": 8, "hits": 2, "weight": 3},
		{"type": "attack", "amount": 7, "move": "attack2", "weight": 1},
	]))
	_check(intent.get("target") == "lowest_living_hp"
		and intent.get("actions", []) == expected_actions,
		"AC1: the complete legacy weighted intent is preserved")
	var profile: Dictionary = record.get("stitched", {})
	_check(int(profile.get("max_hp", 0)) == 22 and int(profile.get("speed", -1)) == 7
		and int(profile.get("dodge", -1)) == 8 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 0 and profile.get("is_boss") == false
		and int(profile.get("turns_per_round", 0)) == 1
		and str(profile.get("trophy", "")) == "needle_wasp_stinger",
		"AC1: the Stitched profile keeps 22 HP, SPEED 7, DODGE 8, ACC 0, PROT 0 and the stinger trophy")
	var abilities: Array = profile.get("abilities", [])
	var ids: Array = abilities.map(func(ability: Dictionary) -> String:
		return str(ability.get("id", "")))
	_check(ids == ["needle_sting", "wasp_dart", "needle_spit"],
		"AC1: Sting stays first, Wasp Dart second and exactly one third Needle Spit is appended")
	for pair in [["needle_sting", STING], ["wasp_dart", DART], ["needle_spit", SPIT]]:
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
	_check(not foe.is_empty() and int(foe.get("max_hp", 0)) == 22
		and int(foe.get("speed", -1)) == 7 and int(foe.get("dodge", -1)) == 8
		and int(foe.get("acc", -1)) == 0 and int(foe.get("prot", -1)) == 0
		and foe.get("is_boss") == false and int(foe.get("turns_per_round", 0)) == 1
		and StitchedEnemyCatalog.trophy_for(catalog, FOE) == "needle_wasp_stinger",
		"AC1: the real loader publishes the unchanged Needle Wasp profile and trophy")
	var loaded: Array = foe.get("abilities", [])
	_check(loaded.size() == 3
		and str(loaded[0].get("id", "")) == "needle_sting"
		and str(loaded[1].get("id", "")) == "wasp_dart"
		and str(loaded[2].get("id", "")) == "needle_spit",
		"AC1: the normalized kit keeps the authored order")
	var sting_mask := int(loaded[0].get("launch_mask", -1))
	var sting_target := int(loaded[0].get("target_mask", -1))
	_check(int(loaded[0].get("launch_mask", -1)) == StitchedParts.rank_mask([1, 2, 3])
		and int(loaded[0].get("target_mask", -1)) == StitchedParts.rank_mask([1, 2, 3]),
		"AC1: normalized Needle Sting widens exactly its launch and target masks to [1,2,3]")
	for rank in [1, 2, 3]:
		_check(StitchedParts.ranks_allowed(sting_mask, rank)
			and StitchedParts.ranks_allowed(sting_target, rank),
			"AC1: Needle Sting may launch from and bite rank " + str(rank))
	_check(not StitchedParts.ranks_allowed(sting_mask, 4)
		and not StitchedParts.ranks_allowed(sting_target, 4),
		"AC1: Needle Sting never launches from nor bites rank 4")
	var dart: Dictionary = loaded[1]
	_check(dart.get("launch") == [1, 3] and dart.get("target") == [1, 3]
		and int(dart.get("acc", -1)) == 100 and dart.get("dmg") == [0, 0]
		and dart.get("effects") == {"dodge": 5, "duration": 1}
		and int(dart.get("self_move", -2)) == 1 and str(dart.get("move", "")) == "skill",
		"AC1: normalized Wasp Dart keeps its dodge 5, duration 1 and self_move +1 exactly")
	var spit: Dictionary = loaded[2]
	_check(spit.get("launch") == [1, 2, 3, 4] and spit.get("target") == [2, 3]
		and int(spit.get("launch_mask", -1)) == StitchedParts.rank_mask([1, 2, 3, 4])
		and int(spit.get("target_mask", -1)) == StitchedParts.rank_mask([2, 3])
		and bool(spit.get("multi", false)) and int(spit.get("acc", -1)) == 86
		and spit.get("dmg") == [2, 3] and int(spit.get("crit", -1)) == 0
		and spit.get("effects") == {"bleed": 2}
		and int(spit.get("self_move", -2)) == 0
		and str(spit.get("move", "")) == "attack3",
		"AC1: normalized Needle Spit volleys multi-target ranks 2-3 with ACC 86, 2-3 damage and Bleed 2")
	for rank in [2, 3]:
		_check(StitchedParts.ranks_allowed(int(spit.get("target_mask", 0)), rank),
			"AC1: Needle Spit reaches hero rank " + str(rank))
	for rank in [1, 4]:
		_check(not StitchedParts.ranks_allowed(int(spit.get("target_mask", 0)), rank),
			"AC1: Needle Spit never reaches hero rank " + str(rank))
	# Named earlier records keep their identity; no catalog total or ordered list is asserted.
	for earlier_id in EARLIER_FOES:
		var earlier: Array = raw.filter(func(entry: Dictionary) -> bool:
			return str(entry.get("id", "")) == earlier_id)
		_check(earlier.size() == 1
			and str(earlier[0].get("name", "")) == str(EARLIER_FOES[earlier_id]),
			"AC1: the earlier named record stays authored: " + earlier_id)
	# The existing authored attack3 pose and its PNG carry the new volley; no art or pose edit.
	var pose_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	_check(pose_doc is Dictionary, "AC1: the authored move-pose manifest loads")
	if pose_doc is Dictionary:
		var poses: Dictionary = pose_doc.get("enemies", {}).get(FOE, {})
		var spit_pose: Dictionary = poses.get("attack3", {})
		_check(str(spit_pose.get("name", "")) == "Needle Spit"
			and (spit_pose.get("covers", []) as Array).has("attack")
			and str(spit_pose.get("art", "")) == "res://assets/paper/enemies/needle_wasp_attack3.png"
			and FileAccess.file_exists(str(spit_pose.get("art", ""))),
			"AC1: the existing attack3 pose and PNG carry Needle Spit")
		_check(poses.has("skill") and poses.has("attack2")
			and str(SPIT["move"]) == "attack3" and str(DART["move"]) == "skill"
			and str(STING["move"]) == "attack2",
			"AC1: every move keeps its existing authored pose")


# ---------------------------------------------------------------- fixtures

func _config(ids: Array, seed_value: int) -> Dictionary:
	var config: Dictionary = preview.duplicate(true)
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"].duplicate(true))
	config["foes"] = []
	for enemy_id in ids:
		config["foes"].append(StitchedEnemyCatalog.foe_for(catalog, str(enemy_id)))
	return config


func _battle(seed_value: int, ids: Array = [FOE, PARTNER]) -> StitchedRules:
	var created := StitchedRules.create(_config(ids, seed_value))
	_check(bool(created.get("ok", false)),
		"AC2: a genuine seeded four-versus-" + str(ids.size()) + " fight builds")
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size()
		and battle.candle() == 100,
		"AC2: real four-doll line and bright fixed candle")
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


## The victim's NEXT own turn: first spends its current turn when it is already acting,
## so a tick can never be counted twice or skipped.
func _own_turn(battle: StitchedRules, actor_id: String, receipts: Array,
		snapshots: Array) -> bool:
	if battle.current_actor_id() == actor_id:
		var spent := battle.pass_turn()
		if not bool(spent.get("ok", false)):
			return false
		receipts.append(spent)
		snapshots.append(battle.state_snapshot())
	return _to(battle, actor_id, receipts, snapshots)


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
		"AC3: " + expected + " refuses without a state, turn or RNG spend")


# ---------------------------------------------------------------- AC2/3 seeded spit

func _possible_damage(battle: StitchedRules, foe: Dictionary, victim: Dictionary,
		crit: bool) -> Array:
	var possible: Array = []
	var base_rolls: Array = [StitchedRules.crit_damage(int(SPIT["dmg"][1]))] if crit \
		else [int(SPIT["dmg"][0]), int(SPIT["dmg"][1])]
	for base in base_rolls:
		possible.append(StitchedRules.damage_after_modifiers(
			StitchedS1BEffects.enemy_damage(int(base) + int(foe.get("dmg_bonus", 0)),
				battle.candle()),
			foe["statuses"], victim["statuses"], false, 0,
			int(victim.get("prot", 0))))
	return possible


func _spit_turn(battle: StitchedRules, receipts: Array, snapshots: Array) -> Dictionary:
	## Reaches the wasp's round-two turn and projects the volley read-only.
	if not _to(battle, FOE, receipts, snapshots, 2):
		return {}
	var quiet_state := battle.state_snapshot()
	var quiet_rng := battle.rng_state()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	var repeat := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(choice == repeat and quiet_state == battle.state_snapshot()
		and quiet_rng == battle.rng_state(),
		"AC3: repeated Needle Spit projection reads no state, RNG or turn")
	return choice


func _witness(seed_value: int) -> Dictionary:
	## Round-two commit through the real rules; classifies natural hit/miss only.
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	var choice := _spit_turn(battle, receipts, snapshots)
	if str(choice.get("ability_id", "")) != "needle_spit":
		return {}
	var cast := battle.use_foe_ability("needle_spit", 2)
	if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 2:
		return {}
	var any_hit := false
	for result in cast["results"]:
		if bool(result.get("hit", false)):
			any_hit = true
	return {"any_hit": any_hit}


func _spit_receipt_checks(battle: StitchedRules, cast: Dictionary,
		before: Dictionary, foe_before: Dictionary) -> Dictionary:
	## Verifies one committed volley: two independent rolls, exact damage, Bleed-on-hit only.
	## The victim may be the very next actor and have already ticked its first Bleed.
	_check(bool(cast.get("ok", false)) and str(cast.get("actor", "")) == FOE
		and str(cast.get("ability", "")) == "needle_spit",
		"AC2: the real foe turn commits exactly one Needle Spit")
	var results: Array = cast.get("results", [])
	var seen_ranks: Array = []
	var seen_targets: Dictionary = {}
	var results_by_target: Dictionary = {}
	var any_hit := false
	var first_hit_id := ""
	var streak := int(foe_before.get("miss_streak", 0))
	for result in results:
		var target_id := str(result.get("target", ""))
		var rank := int(result.get("target_rank", 0))
		seen_ranks.append(rank)
		seen_targets[target_id] = true
		results_by_target[target_id] = result
		_check(rank >= 2 and rank <= 3 and not target_id.is_empty()
			and target_id == _hero_at(battle, rank),
			"AC2: every volley receipt names the living doll really occupying rank " + str(rank))
		var victim_before: Dictionary = before[target_id]
		var chance := StitchedRules.hit_chance(
			int(SPIT["acc"]) + int(foe_before.get("acc", 0))
			+ int(battle.candle_band()["enemy_acc"]),
			StitchedRules.effective_dodge(victim_before),
			streak)
		var hit := bool(result.get("hit", false))
		_check(hit == (int(result.get("roll", 101)) <= chance)
			and int(result.get("hit_chance", -1)) == chance,
			"AC2: rank " + str(rank) + " rolls one independent ACC 86 attack against real DODGE")
		streak = 0 if hit else streak + 1
		var victim_after := battle.get_unit(target_id)
		if hit:
			any_hit = true
			if first_hit_id.is_empty():
				first_hit_id = target_id
			var possible := _possible_damage(battle, foe_before, victim_before,
				bool(result.get("crit", false)))
			_check(possible.has(int(result.get("damage", -1)))
				and int(result.get("damage", 0)) >= 2 and int(result.get("damage", 0)) <= 4
				and int(result.get("target_hp", -1))
					== int(victim_before["hp"]) - int(result["damage"]),
				"AC2: a landed spit deals its exact rolled 2-3 damage (crit 4) after real modifiers")
			var already_ticked := battle.current_actor_id() == target_id
			var live_bleed := int(victim_after["statuses"].get("bleed", 0))
			_check(result.get("statuses") == [{"status": "bleed", "duration": 2}]
				and ((not already_ticked and live_bleed == 2
						and int(victim_after["hp"]) == int(result.get("target_hp", -1)))
					or (already_ticked and live_bleed == 1
						and int(victim_after["hp"]) == int(result.get("target_hp", -1)) - 2)),
				"AC2: only a hit attaches Bleed 2 to the middle-rank doll")
		else:
			_check(int(result.get("damage", -1)) == 0 and result.get("statuses") == []
				and int(victim_after["hp"]) == int(victim_before["hp"])
				and int(victim_after["statuses"].get("bleed", 0)) == 0,
				"AC2: a natural miss deals no damage and applies no Bleed")
	_check(results.size() == 2 and seen_ranks == [2, 3]
		and seen_targets.size() == 2,
		"AC2: both living hero ranks 2 and 3 are resolved exactly once each")
	# Rank 1 and rank 4 are never recipients of the volley.
	var front: Dictionary = before.get(_hero_at(battle, 1), {})
	var rear: Dictionary = before.get(_hero_at(battle, 4), {})
	_check(not front.is_empty() and not rear.is_empty()
		and int(battle.get_unit(_hero_at(battle, 1))["hp"]) == int(front["hp"])
		and int(battle.get_unit(_hero_at(battle, 4))["hp"]) == int(rear["hp"])
		and int(battle.get_unit(_hero_at(battle, 1))["statuses"].get("bleed", 0)) == 0
		and int(battle.get_unit(_hero_at(battle, 4))["statuses"].get("bleed", 0)) == 0
		and not seen_targets.has(_hero_at(battle, 1))
		and not seen_targets.has(_hero_at(battle, 4)),
		"AC2: hero ranks 1 and 4 keep their HP and stay free of the volley's Bleed")
	return {"any_hit": any_hit, "first_hit_id": first_hit_id,
		"results_by_target": results_by_target}


func _hit_trace(seed_value: int) -> void:
	var battle := _battle(seed_value)
	if battle == null:
		return
	var receipts: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	# Round one still opens with the unchanged nearest-rank Needle Sting projection.
	if not _to(battle, FOE, receipts, snapshots, 1):
		_check(false, "AC2: the hit witness reaches the wasp's round-one turn")
		return
	var opening := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	_check(str(opening.get("ability_id", "")) == "needle_sting"
		and int(opening.get("target_rank", 0)) == 1
		and opening.get("affected_ranks", []) == [1]
		and not bool(opening.get("multi", true))
		and opening.get("base_damage", []) == [3, 4]
		and opening.get("base_effects", {}) == {"bleed": 2},
		"AC1: round one still opens with the unchanged nearest-rank Needle Sting")
	var choice := _spit_turn(battle, receipts, snapshots)
	_check(str(choice.get("ability_id", "")) == "needle_spit"
		and str(choice.get("ability_name", "")) == "Needle Spit"
		and str(choice.get("ability_kind", "")) == "ranged"
		and str(choice.get("target_side", "")) == "hero"
		and int(choice.get("target_rank", 0)) == 2
		and choice.get("affected_ranks", []) == [2, 3]
		and bool(choice.get("multi", false))
		and int(choice.get("base_acc", -1)) == 86
		and choice.get("base_damage", []) == [2, 3]
		and int(choice.get("base_crit", -1)) == 0
		and choice.get("base_effects", {}) == {"bleed": 2}
		and not bool(choice.get("pass", true)),
		"AC2: with Wasp Dart blocked the round-two projection falls through to the exact authored volley")
	_check(not _hero_at(battle, 2).is_empty() and not _hero_at(battle, 3).is_empty(),
		"AC2: precondition: living dolls really occupy hero ranks 2 and 3")
	if str(choice.get("ability_id", "")) != "needle_spit":
		return
	_refuse(battle, "needle_spit", 1, "no legal target in rank 1")
	_refuse(battle, "needle_spit", 4, "no legal target in rank 4")
	var before := {}
	for hero in battle.get_heroes():
		before[str(hero["id"])] = hero.duplicate(true)
	var foe_before := battle.get_unit(FOE)
	var cast := battle.use_foe_ability("needle_spit", 2)
	var checked := _spit_receipt_checks(battle, cast, before, foe_before)
	_check(bool(checked.get("any_hit", false)),
		"AC2: the hit witness really contains a natural landed volley")
	var victim_id := str(checked.get("first_hit_id", ""))
	if victim_id.is_empty():
		return
	# Bleed 2 ticks its current value on each of the victim's own turns (2, then the last
	# pip of 1), straight past any PROT, and expires when the last pip is spent.
	# The victim may already be the current actor with its first tick applied.
	var receipt_hp := int((checked["results_by_target"][victim_id]).get("target_hp", -1))
	var remaining := int(battle.get_unit(victim_id)["statuses"].get("bleed", 0))
	_check(remaining == 1 or remaining == 2,
		"AC2: precondition: the hit victim carries one or two unexpired Bleed")
	if remaining == 1:
		_check(int(battle.get_unit(victim_id)["hp"]) == receipt_hp - 2,
			"AC2: an already-started victim turn has ticked exactly its first Bleed 2")
	# Clearly labelled test-only fixture state: a high PROT seam, never a fabricated receipt.
	battle._units[victim_id]["prot"] = 50
	if remaining == 2:
		if not _own_turn(battle, victim_id, receipts, snapshots):
			_check(false, "AC2: the bleeding victim reaches its own next turn")
			return
		var ticked := battle.get_unit(victim_id)
		_check(int(ticked["hp"]) == receipt_hp - 2
			and int(ticked["statuses"].get("bleed", 0)) == 1,
			"AC2: the victim's own turn ticks exactly Bleed 2 straight past PROT 50")
	if not _own_turn(battle, victim_id, receipts, snapshots):
		_check(false, "AC2: the victim reaches its second bleeding turn")
		return
	var expired := battle.get_unit(victim_id)
	_check(int(expired["hp"]) == receipt_hp - 3
		and not expired["statuses"].has("bleed"),
		"AC2: the final own turn ticks the last Bleed pip straight past PROT 50 and expires the status")


func _miss_trace(seed_value: int) -> void:
	var battle := _battle(seed_value)
	if battle == null:
		return
	var receipts: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	var choice := _spit_turn(battle, receipts, snapshots)
	if str(choice.get("ability_id", "")) != "needle_spit":
		_check(false, "AC2: the miss witness reaches the round-two volley")
		return
	var before := {}
	for hero in battle.get_heroes():
		before[str(hero["id"])] = hero.duplicate(true)
	var foe_before := battle.get_unit(FOE)
	var cast := battle.use_foe_ability("needle_spit", 2)
	var checked := _spit_receipt_checks(battle, cast, before, foe_before)
	_check(not bool(checked.get("any_hit", true)),
		"AC2: the witnessed round-two volley really missed every living recipient")
	for rank in [2, 3]:
		var hero_id := _hero_at(battle, rank)
		if hero_id.is_empty():
			continue
		if _to(battle, hero_id, receipts, snapshots):
			_check(int(battle.get_unit(hero_id)["hp"]) == int(before[hero_id]["hp"])
				and not battle.get_unit(hero_id)["statuses"].has("bleed"),
				"AC2: a fully missed rank " + str(rank)
				+ " ticks no phantom damage or Bleed on its own turn")


# ---------------------------------------------------------------- AC3 rank legality

func _rank_legality() -> void:
	# A rank-one wasp keeps the ordinary Sting, and every illegal request fails closed.
	var front := _battle(700301)
	if front == null:
		return
	var receipts: Array = []
	var snapshots: Array = [front.state_snapshot()]
	if not _to(front, FOE, receipts, snapshots, 1):
		_check(false, "AC3: the rank-one fixture reaches the wasp's round-one turn")
		return
	_check(int(front.get_unit(FOE)["rank"]) == 1,
		"AC3: precondition: the wasp really stands in foe rank 1")
	var sting := StitchedFoeIntent.choose(front, front.get_unit(FOE))
	_check(str(sting.get("ability_id", "")) == "needle_sting"
		and int(sting.get("target_rank", 0)) == 1
		and sting.get("affected_ranks", []) == [1],
		"AC3: the rank-one wasp still opens with the nearest-rank Needle Sting")
	_refuse(front, "needle_sting", 4, "no legal target in rank 4")
	_refuse(front, "wasp_dart", 1, "self move is blocked: rank 2 is taken")
	_refuse(front, "not_a_wasp_move", 2, "the foe has no ability not_a_wasp_move")
	var committed := front.use_foe_ability("needle_sting", 1)
	_check(bool(committed.get("ok", false)) and committed.get("results", []).size() == 1
		and int(committed["results"][0].get("target_rank", 0)) == 1,
		"AC3: the real rank-one Sting still commits on the front doll")

	# A rank-two wasp can now legally launch the Sting (the widened explicit mask).
	var middle := _battle(700302, [PARTNER, FOE])
	if middle == null:
		return
	var middle_receipts: Array = []
	var middle_snapshots: Array = [middle.state_snapshot()]
	if not _to(middle, FOE, middle_receipts, middle_snapshots, 1):
		_check(false, "AC3: the rank-two fixture reaches the wasp's round-one turn")
		return
	_check(int(middle.get_unit(FOE)["rank"]) == 2,
		"AC3: precondition: the wasp really stands in foe rank 2")
	var mid_sting := StitchedFoeIntent.choose(middle, middle.get_unit(FOE))
	_check(str(mid_sting.get("ability_id", "")) == "needle_sting"
		and int(mid_sting.get("target_rank", 0)) == 1,
		"AC3: a rank-two wasp strikes through its newly legal middle launch rank")
	var mid_cast := middle.use_foe_ability("needle_sting", 1)
	_check(bool(mid_cast.get("ok", false)) and mid_cast.get("results", []).size() == 1,
		"AC3: the rank-two Sting really commits through the live rules")

	# A rank-three wasp: round-two Wasp Dart retreats legally into empty rank 4, and the
	# rotation then reaches Needle Spit on round three while Sting stays launchable.
	var rear := _battle(700303, [PARTNER, "fray_scavenger", FOE])
	if rear == null:
		return
	var rear_receipts: Array = []
	var rear_snapshots: Array = [rear.state_snapshot()]
	if not _to(rear, FOE, rear_receipts, rear_snapshots, 2):
		_check(false, "AC3: the rank-three fixture reaches the wasp's round-two turn")
		return
	_check(int(rear.get_unit(FOE)["rank"]) == 3,
		"AC3: precondition: the wasp really stands in foe rank 3")
	var dart_choice := StitchedFoeIntent.choose(rear, rear.get_unit(FOE))
	_check(str(dart_choice.get("ability_id", "")) == "wasp_dart"
		and str(dart_choice.get("target_side", "")) == "foe"
		and dart_choice.get("base_effects", {}) == {"dodge": 5, "duration": 1},
		"AC3: the unchanged Wasp Dart keeps its defensive round-two retreat")
	var dart_cast := rear.use_foe_ability("wasp_dart", 3)
	_check(bool(dart_cast.get("ok", false))
		and dart_cast.get("results", []).size() == 1
		and dart_cast.get("self_move", {}).get("to", -1) == 4
		and int(rear.get_unit(FOE)["rank"]) == 4
		and int(rear.get_unit(FOE).get("dodge_buff", {}).get("amount", 0)) == 5,
		"AC3: Wasp Dart shifts the wasp one empty rank back with its Dodge 5 buff")
	if not _to(rear, FOE, rear_receipts, rear_snapshots, 3):
		_check(false, "AC3: the rank-three fixture reaches the wasp's round-three turn")
		return
	# The legal Dart retreat has moved the wasp into foe rank 4 (fights start with 2-3 foes,
	# so rank 4 is reached through the wasp's own lawful movement, never a fake fixture).
	_check(int(rear.get_unit(FOE)["rank"]) == 4,
		"AC3: precondition: the legal retreat really stands the wasp in foe rank 4")
	_refuse(rear, "needle_sting", 1, "ability cannot launch from rank 4")
	_refuse(rear, "wasp_dart", 4, "ability cannot launch from rank 4")
	var rotated := StitchedFoeIntent.choose(rear, rear.get_unit(FOE))
	_check(str(rotated.get("ability_id", "")) == "needle_spit"
		and rotated.get("affected_ranks", []) == [2, 3],
		"AC3: from rank 4, and on the rotated third round, only Needle Spit can launch")
	var rotated_cast := rear.use_foe_ability("needle_spit", 2)
	_check(bool(rotated_cast.get("ok", false))
		and rotated_cast.get("results", []).size() == 2,
		"AC3: the rotated rank-four volley really commits across both middle ranks")


# ---------------------------------------------------------------- AC4 scripted replay

func _scripted_trace(seed_value: int) -> Dictionary:
	## Identical seed plus identical lawful choices must replay identically.
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	var events: Array = []
	if not _to(battle, FOE, [], [], 1):
		return {}
	var opening := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	events.append({"round": 1, "intent": _norm(opening),
		"receipt": _norm(battle.use_foe_ability(str(opening.get("ability_id")),
			int(opening.get("target_rank", 1))))})
	if not _to(battle, FOE, [], [], 2):
		return {}
	var second := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	events.append({"round": 2, "intent": _norm(second),
		"refusal": _norm(battle.use_foe_ability("needle_spit", 1))})
	events.append({"round": 2, "intent": _norm(second),
		"receipt": _norm(battle.use_foe_ability("needle_spit", 2))})
	if not _to(battle, FOE, [], [], 3):
		return {}
	var third := StitchedFoeIntent.choose(battle, battle.get_unit(FOE))
	events.append({"round": 3, "intent": _norm(third),
		"receipt": _norm(battle.use_foe_ability("needle_spit", 2))})
	return {
		"events": _norm(events),
		"snapshot": _norm(battle.state_snapshot()),
		"order": _norm(battle.turn_order()),
		"rng": battle.rng_state(),
	}


func _norm(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))
