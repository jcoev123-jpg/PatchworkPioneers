extends SceneTree
## Canonical Zipper Hauler JSON -> real StitchedEnemyCatalog -> seeded StitchedRules and
## StitchedFoeIntent. The shipped rules core is the only combat engine used here.

const ZIPPER := "zipper_hauler"
const SNAKE := "spool_snarekeeper"
const RAGLING := "ragling"
const HERO_IDS := ["warden", "seamstress", "tinker", "lantern_monk"]
const ELITE_PATH := "res://data/enemies/m04_elites.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _run() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"canonical S5 catalog loads: " + str(catalog.get("error", "")))
	if bool(catalog.get("ok", false)):
		_test_authored()
		_test_authored_spool()
		_test_drag(2)
		_test_drag(4)
		_test_slam()
		_test_spool_pull_and_miss()
		_test_spool_mark_combo()
		_test_spool_refusals()
		_test_refusals_miss_and_blocked_pull()
		_test_intent_and_replay()
		_test_spool_replay()
		await _test_live_driver()
		await _test_live_spool_driver()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_zipper_haul_combo_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- AC1 authored data

func _test_authored() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITE_PATH))
	_check(parsed is Array and not (parsed as Array).is_empty(),
		"real m04 elite JSON is a nonempty array")
	if not parsed is Array:
		return
	var raw: Dictionary = {}
	var anchor: Dictionary = {}
	for record in parsed:
		if not record is Dictionary:
			continue
		if str(record.get("id", "")) == ZIPPER:
			raw = record
		elif str(record.get("id", "")) == "scissor_bailiff":
			anchor = record
	_check(not raw.is_empty(), "Zipper Hauler is present in the shipped elite catalog")
	_check(not anchor.is_empty(), "named untouched Scissor Bailiff anchor is present")
	if raw.is_empty():
		return
	var slam := {
		"id": "hauler_slam", "name": "Hauler Slam", "kind": "melee",
		"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
		"acc": 84, "dmg": [5, 7], "crit": 0, "effects": {"exposed": 2},
		"self_move": 0, "move": "attack2",
	}
	var drag := {
		"id": "chain_drag", "name": "Chain Drag", "kind": "debuff",
		"launch": [1, 2, 3, 4], "target": [2, 3, 4], "target_side": "enemy", "multi": false,
		"acc": 88, "dmg": [0, 0], "crit": 0, "effects": {"pull": 1, "fray": 4},
		"self_move": 0, "move": "skill",
	}
	var profile := {
		"max_hp": 38, "speed": 3, "dodge": 3, "acc": 0, "prot": 10,
		"is_boss": false, "turns_per_round": 1, "trophy": "zipper_hauler_chain",
		"abilities": [slam, drag],
	}
	_check(raw.get("stitched") == JSON.parse_string(JSON.stringify(profile)),
		"AC1: exact Stitched profile changes only the two named moves")
	var legacy := raw.duplicate(true)
	legacy.erase("stitched")
	_check(legacy == JSON.parse_string(JSON.stringify({
		"id": "zipper_hauler", "name": "Zipper Hauler", "max_hp": 38,
		"art_path": "res://assets/paper/enemies/zipper_hauler.png",
		"intent": {"target": "front", "actions": [
			{"type": "shove", "amount": 0, "direction": -1, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
			{"type": "attack", "amount": 8, "weight": 2},
			{"type": "attack", "amount": 10, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
		]},
	})), "AC1: Zipper's entire legacy record stays unchanged")
	var foe := StitchedEnemyCatalog.foe_for(catalog, ZIPPER)
	_check(foe.get("id") == ZIPPER and foe.get("name") == "Zipper Hauler"
		and foe.get("max_hp") == 38 and foe.get("speed") == 3 and foe.get("dodge") == 3
		and foe.get("acc") == 0 and foe.get("prot") == 10 and foe.get("is_boss") == false
		and foe.get("turns_per_round") == 1
		and StitchedEnemyCatalog.trophy_for(catalog, ZIPPER) == "zipper_hauler_chain",
		"AC1: foe_for keeps HP/SPEED/DODGE/ACC/PROT/tier/trophy")
	var ids: Array = []
	for ability in foe.get("abilities", []):
		ids.append(str(ability["id"]))
	_check(ids == ["hauler_slam", "chain_drag"],
		"AC1: the shipped kit carries exactly the two edited Stitched moves")
	for authored in [slam, drag]:
		var validated := StitchedParts.validate_ability(authored)
		_check(bool(validated.get("ok", false)),
			"AC1: " + str(authored["id"]) + " validates through the real parts rules")
		if bool(validated.get("ok", false)):
			_check(foe["abilities"].has(validated["ability"]),
				"AC1: foe_for carries the exact validated " + str(authored["id"]))
	for ability in foe.get("abilities", []):
		_check(str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
			and int(ability["crit"]) == 0 and int(ability["self_move"]) == 0,
			"AC1: " + str(ability["id"]) + " stays single-target enemy-side with crit/self_move 0")
	var anchor_profile: Dictionary = anchor.get("stitched", {})
	var anchor_ids: Array = []
	for ability in anchor_profile.get("abilities", []):
		anchor_ids.append(str(ability["id"]))
	_check(anchor_profile.get("max_hp") == 36 and anchor_profile.get("speed") == 4
		and anchor_profile.get("dodge") == 5 and anchor_profile.get("prot") == 8
		and anchor_profile.get("trophy") == "scissor_bailiff_shears"
		and anchor_ids == ["bailiff_snip", "seize_thread", "bailiff_unpick"],
		"AC1: untouched Scissor Bailiff anchor keeps its Stitched identity")


# ---------------------------------------------------------------- AC1 Snarekeeper authored data

func _test_authored_spool() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITE_PATH))
	_check(parsed is Array and not (parsed as Array).is_empty(),
		"real m04 elite JSON is a nonempty array")
	if not parsed is Array:
		return
	var raw: Dictionary = {}
	var anchor: Dictionary = {}
	for record in parsed:
		if not record is Dictionary:
			continue
		if str(record.get("id", "")) == SNAKE:
			raw = record
		elif str(record.get("id", "")) == ZIPPER:
			anchor = record
	_check(not raw.is_empty(), "Spool Snarekeeper is present in the shipped elite catalog")
	_check(not anchor.is_empty(), "named untouched Zipper Hauler anchor is present")
	if raw.is_empty():
		return
	var lash := {
		"id": "snare_lash", "name": "Snare Lash", "kind": "melee",
		"launch": [1, 3], "target": [1, 2, 3], "target_side": "enemy", "multi": false,
		"acc": 88, "dmg": [4, 5], "crit": 0, "mark_damage": 3,
		"effects": {"tangled": 1, "snip": 1},
		"self_move": 0, "move": "attack2",
	}
	var snare := {
		"id": "spool_snare", "name": "Spool Snare", "kind": "debuff",
		"launch": [1, 4], "target": [2, 3, 4], "target_side": "enemy", "multi": false,
		"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"pull": 1, "fray": 6, "mark": 3},
		"self_move": 0, "move": "skill",
	}
	var profile := {
		"max_hp": 40, "speed": 4, "dodge": 5, "acc": 0, "prot": 8,
		"is_boss": false, "turns_per_round": 1, "trophy": "spool_snarekeeper_snare",
		"abilities": [lash, snare],
	}
	_check(raw.get("stitched") == JSON.parse_string(JSON.stringify(profile)),
		"AC1: Snarekeeper profile keeps its identity and changes only Spool Snare")
	var legacy := raw.duplicate(true)
	legacy.erase("stitched")
	_check(legacy == JSON.parse_string(JSON.stringify({
		"id": "spool_snarekeeper", "name": "Spool Snarekeeper", "max_hp": 40,
		"art_path": "res://assets/paper/enemies/spool_snarekeeper.png",
		"intent": {"target": "front", "actions": [
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "debuff", "amount": 2, "status": "weak", "weight": 2},
			{"type": "attack", "amount": 8, "weight": 3},
			{"type": "attack", "amount": 9, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
		]},
	})), "AC1: Snarekeeper's entire legacy record stays unchanged")
	var foe := StitchedEnemyCatalog.foe_for(catalog, SNAKE)
	_check(foe.get("id") == SNAKE and foe.get("name") == "Spool Snarekeeper"
		and foe.get("max_hp") == 40 and foe.get("speed") == 4 and foe.get("dodge") == 5
		and foe.get("acc") == 0 and foe.get("prot") == 8 and foe.get("is_boss") == false
		and foe.get("turns_per_round") == 1
		and StitchedEnemyCatalog.trophy_for(catalog, SNAKE) == "spool_snarekeeper_snare",
		"AC1: foe_for keeps HP/SPEED/DODGE/ACC/PROT/tier/trophy")
	var ids: Array = []
	for ability in foe.get("abilities", []):
		ids.append(str(ability["id"]))
	_check(ids == ["snare_lash", "spool_snare"],
		"AC1: the shipped kit carries exactly the two canonical Snarekeeper moves")
	for authored in [lash, snare]:
		var validated := StitchedParts.validate_ability(authored)
		_check(bool(validated.get("ok", false)),
			"AC1: " + str(authored["id"]) + " validates through the real parts rules")
		if bool(validated.get("ok", false)):
			_check(foe["abilities"].has(validated["ability"]),
				"AC1: foe_for carries the exact validated " + str(authored["id"]))
	var selected: Dictionary = {}
	var lash_selected: Dictionary = {}
	for ability in foe.get("abilities", []):
		if str(ability["id"]) == "spool_snare":
			selected = ability
		elif str(ability["id"]) == "snare_lash":
			lash_selected = ability
	_check(not selected.is_empty() and selected.get("target") == [2, 3, 4]
		and selected.get("effects") == {"pull": 1, "fray": 6, "mark": 3}
		and int(selected.get("acc", 0)) == 90 and selected.get("dmg") == [0, 0],
		"AC1: Spool Snare reaches ranks 2/3/4 with authored pull 1, Fray 6 and Mark 3")
	_check(not lash_selected.is_empty() and lash_selected.get("target") == [1, 2, 3]
		and int(lash_selected.get("mark_damage", 0)) == 3
		and lash_selected.get("effects") == {"tangled": 1, "snip": 1}
		and int(lash_selected.get("acc", 0)) == 88 and lash_selected.get("dmg") == [4, 5],
		"AC1: Snare Lash reaches ranks 1/2/3 and keeps Tangled 1, ACC 88 and damage 4-5, now with Snip 1")
	var anchor_foe := StitchedEnemyCatalog.foe_for(catalog, ZIPPER)
	var anchor_ids: Array = []
	for ability in anchor_foe.get("abilities", []):
		anchor_ids.append(str(ability["id"]))
	_check(anchor_ids == ["hauler_slam", "chain_drag"]
		and anchor_foe["abilities"][1].get("target") == [2, 3, 4]
		and anchor_foe["abilities"][1].get("effects") == {"pull": 1, "fray": 4},
		"AC1: Zipper Hauler's canonical Slam and Chain Drag stay exactly authored")


# ---------------------------------------------------------------- live battle helpers

func _config(seed_value: int, primary: String = ZIPPER) -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"].duplicate(true))
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(catalog, primary),
		StitchedEnemyCatalog.foe_for(catalog, RAGLING),
	]
	return config


func _battle(seed_value: int, primary: String = ZIPPER) -> StitchedRules:
	var built := StitchedRules.create(_config(seed_value, primary))
	_check(bool(built.get("ok", false)),
		"seed %d builds a real 4v2 battle: %s" % [seed_value, str(built.get("error", ""))])
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.is_valid() and battle.get_heroes().size() == 4 and battle.get_foes().size() == 2
		and battle.candle() == 100,
		"seed %d has four living heroes, two foes and candle 100" % seed_value)
	return battle


func _to(battle: StitchedRules, actor: String, minimum_round: int = 1) -> bool:
	for step in range(80):
		if battle.is_over():
			break
		if battle.current_actor_id() == actor and battle.round_number() >= minimum_round:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			break
	_check(false, "failed to reach a legal turn for " + actor)
	return false


func _hero_ranks(battle: StitchedRules) -> Dictionary:
	var ranks: Dictionary = {}
	for hero in battle.get_heroes():
		ranks[str(hero["id"])] = int(hero["rank"])
	return ranks


func _with_swap(ranks: Dictionary, first: String, first_rank: int, second: String, second_rank: int) -> Dictionary:
	var expected := ranks.duplicate(true)
	expected[first] = first_rank
	expected[second] = second_rank
	return expected


# ---------------------------------------------------------------- AC2 pulls and swap

func _test_drag(target_rank: int) -> void:
	var witnesses := 0
	for seed_value in range(1, 49):
		var b := _battle(seed_value)
		if b == null or not _to(b, ZIPPER):
			continue
		var target_id: String = HERO_IDS[target_rank - 1]
		var front_id: String = HERO_IDS[target_rank - 2]
		var before_target := b.get_unit(target_id)
		var before_front := b.get_unit(front_id)
		var before_ranks := _hero_ranks(b)
		var receipt := b.use_foe_ability("chain_drag", target_rank)
		_check(bool(receipt.get("ok", false)) and receipt.get("ability") == "chain_drag"
			and receipt.get("actor") == ZIPPER and receipt.get("results", []).size() == 1,
			"seed %d commits one real Chain Drag result" % seed_value)
		if receipt.get("results", []).size() != 1:
			continue
		var result: Dictionary = receipt["results"][0]
		_check(result.get("target") == target_id and int(result.get("target_rank", 0)) == target_rank,
			"seed %d Chain Drag targets the rank-%d hero" % [seed_value, target_rank])
		if not bool(result.get("hit", false)):
			_check(int(result.get("damage", -1)) == 0 and not result.has("shift")
				and not result.has("fray_event") and result.get("statuses", []).is_empty(),
				"missed rank-%d drag has no damage, shift, Fray or status" % target_rank)
			_check(_hero_ranks(b) == before_ranks
				and int(b.get_unit(target_id)["fray"]) == int(before_target["fray"]),
				"missed rank-%d drag leaves every hero rank and Fray unchanged" % target_rank)
			continue
		witnesses += 1
		_check(int(result.get("damage", -1)) == 0
			and int(result.get("target_hp", -1)) == int(before_target["hp"]),
			"landed rank-%d drag is a true zero-damage hit" % target_rank)
		_check(result.get("fray_event") == {
			"ok": true, "action": "fray", "actor": target_id,
			"before": int(before_target["fray"]), "change": 4,
			"after": int(before_target["fray"]) + 4, "transition": "",
		}, "landed rank-%d drag adds exactly four actual Fray at candle 100" % target_rank)
		_check(result.get("shift") == {
			"ok": true, "from": target_rank, "to": target_rank - 1, "swapped": front_id,
		}, "landed rank-%d drag reports the exact forward swap" % target_rank)
		var expected_target := before_target.duplicate(true)
		expected_target["rank"] = target_rank - 1
		expected_target["fray"] = int(before_target["fray"]) + 4
		var expected_front := before_front.duplicate(true)
		expected_front["rank"] = target_rank
		_check(b.get_unit(target_id) == expected_target,
			"pulled rank-%d hero keeps identity and arrives one rank forward" % target_rank)
		_check(b.get_unit(front_id) == expected_front,
			"former rank-%d ally swaps back with every other field kept" % (target_rank - 1))
		_check(_hero_ranks(b) == _with_swap(before_ranks, target_id, target_rank - 1,
			front_id, target_rank),
			"rank-%d drag swaps exactly the two heroes and moves no other hero" % target_rank)
		for hero in b.get_heroes():
			if str(hero["id"]) != target_id and str(hero["id"]) != front_id:
				_check(int(hero["rank"]) == int(before_ranks[str(hero["id"])]),
					"rank-%d drag leaves the other rank in place" % target_rank)
		_check(int(b.get_unit(ZIPPER)["rank"]) == 1 and int(b.get_unit(RAGLING)["rank"]) == 2,
			"rank-%d drag leaves both foes in their ranks" % target_rank)
		break
	_check(witnesses > 0, "nonvacuous confirmed rank-%d Chain Drag witness" % target_rank)


# ---------------------------------------------------------------- AC2 Spool Snare pull

func _hero_at_rank(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _spool_ready(seed_value: int) -> StitchedRules:
	var b := _battle(seed_value, SNAKE)
	if b == null:
		return null
	if not _to(b, SNAKE, 2):
		return null
	var choice := StitchedFoeIntent.choose(b, b.get_unit(SNAKE))
	if str(choice.get("ability_id", "")) != "spool_snare" \
			or int(choice.get("target_rank", 0)) != 4:
		return null
	return b


func _test_spool_pull_and_miss() -> void:
	var hit_seed := -1
	var miss_seed := -1
	for seed_value in range(1, 97):
		if hit_seed < 0:
			var b := _spool_ready(seed_value)
			if b != null:
				var target_id := _hero_at_rank(b, 4)
				var front_id := _hero_at_rank(b, 3)
				var before_target := b.get_unit(target_id)
				var before_front := b.get_unit(front_id)
				var before_ranks := _hero_ranks(b)
				var before_rng := b.rng_state()
				var receipt := b.use_foe_ability("spool_snare", 4)
				var results: Array = receipt.get("results", [])
				if bool(receipt.get("ok", false)) and results.size() == 1 \
						and bool(results[0].get("hit", false)):
					hit_seed = seed_value
					var result: Dictionary = results[0]
					_check(result.get("target") == target_id
						and int(result.get("target_rank", 0)) == 4,
						"AC2: landed Spool Snare targets the deep rank-4 doll")
					_check(int(result.get("damage", -1)) == 0
						and int(result.get("target_hp", -1)) == int(before_target["hp"]),
						"AC2: landed Spool Snare deals no direct damage")
					_check(result.get("fray_event") == {
						"ok": true, "action": "fray", "actor": target_id,
						"before": int(before_target["fray"]), "change": 6,
						"after": int(before_target["fray"]) + 6, "transition": "",
					}, "AC2: landed Spool Snare adds exactly six actual Fray at candle 100")
					_check(result.get("shift") == {
						"ok": true, "from": 4, "to": 3, "swapped": front_id,
					}, "AC2: landed Spool Snare reports the exact one-rank forward swap")
					var immediate_tick := b.current_actor_id() == target_id
					_check(result.get("statuses") == [{"status": "mark", "duration": 3}]
						and int(b.get_unit(target_id)["statuses"].get("mark", 0))
							== 3 - (1 if immediate_tick else 0),
						"AC2: landed Spool Snare starts Mark 3 on the reeled doll")
					var expected_target := before_target.duplicate(true)
					expected_target["rank"] = 3
					expected_target["fray"] = int(before_target["fray"]) + 6
					expected_target["statuses"]["mark"] = 3 - (1 if immediate_tick else 0)
					var expected_front := before_front.duplicate(true)
					expected_front["rank"] = 4
					_check(b.get_unit(target_id) == expected_target,
						"AC2: the reeled doll keeps its identity and arrives at rank 3")
					_check(b.get_unit(front_id) == expected_front,
						"AC2: the former rank-3 ally swaps back with every other field kept")
					_check(_hero_ranks(b) == _with_swap(before_ranks, target_id, 3, front_id, 4),
						"AC2: Spool Snare swaps exactly the two dolls and moves no other hero")
					_check(before_rng != b.rng_state() and int(result.get("roll", 0)) <=
						int(result.get("hit_chance", 0)),
						"AC2: the landed pull is a genuine authored hit roll")
		if miss_seed < 0:
			var m := _spool_ready(seed_value)
			if m != null:
				var target_id := _hero_at_rank(m, 4)
				var before_target := m.get_unit(target_id)
				var before_ranks := _hero_ranks(m)
				var before_rng := m.rng_state()
				var receipt := m.use_foe_ability("spool_snare", 4)
				var results: Array = receipt.get("results", [])
				if bool(receipt.get("ok", false)) and results.size() == 1 \
						and not bool(results[0].get("hit", true)):
					miss_seed = seed_value
					var result: Dictionary = results[0]
					_check(before_rng != m.rng_state(),
						"AC2: a missed Spool Snare still spends its real hit roll")
					_check(int(result.get("damage", -1)) == 0 and not result.has("shift")
						and not result.has("fray_event") and result.get("statuses", []).is_empty(),
						"AC2: a missed Spool Snare applies no damage, pull, Fray or status")
					_check(_hero_ranks(m) == before_ranks
						and int(m.get_unit(target_id)["fray"]) == int(before_target["fray"]),
						"AC2: a missed Spool Snare causes no phantom displacement or Fray")
					_check(not m.get_unit(target_id)["statuses"].has("mark"),
						"AC2: a missed Spool Snare never Marks the doll")
		if hit_seed > 0 and miss_seed > 0:
			break
	_check(hit_seed > 0 and miss_seed > 0,
		"nonvacuous seeded Spool Snare hit and miss witnesses")
	if hit_seed > 0:
		_test_spool_blocked(hit_seed)


func _test_spool_blocked(hit_seed: int) -> void:
	var variants := [
		["tangled target", "tangled units cannot move"],
		["cut thread", "thread cut blocks movement"],
		["Wren held", "Wren is holding this doll back"],
		["tangled neighbour", "a tangled ally cannot be swapped"],
	]
	for variant in variants:
		var b := _spool_ready(hit_seed)
		if b == null:
			_check(false, "failed to rebuild the Spool Snare blocked witness")
			continue
		var target_id := _hero_at_rank(b, 4)
		var front_id := _hero_at_rank(b, 3)
		match str(variant[0]):
			"tangled target":
				b._units[target_id]["statuses"]["tangled"] = 1
			"cut thread":
				b._thread_cuts[target_id] = int(b.get_unit(target_id)["rank"])
			"Wren held":
				b._held[target_id] = b.round_number()
			"tangled neighbour":
				b._units[front_id]["statuses"]["tangled"] = 1
		var before_rng := b.rng_state()
		var before_ranks := _hero_ranks(b)
		var before_fray := int(b.get_unit(target_id)["fray"])
		var receipt := b.use_foe_ability("spool_snare", 4)
		var results: Array = receipt.get("results", [])
		_check(bool(receipt.get("ok", false)) and results.size() == 1
			and bool(results[0].get("hit", false))
			and int(results[0].get("roll", 0)) <= int(results[0].get("hit_chance", 0)),
			"AC2: " + str(variant[0]) + " witness still lands a true authored hit")
		if results.size() != 1:
			continue
		_check(results[0].get("shift") == {"ok": false, "reason": str(variant[1])},
			"AC2: " + str(variant[0]) + " refuses the pull: " + str(variant[1]))
		_check(int(results[0].get("damage", -1)) == 0,
			"AC2: " + str(variant[0]) + " blocked pull still deals no direct damage")
		_check(_hero_ranks(b) == before_ranks,
			"AC2: " + str(variant[0]) + " moves neither the reeled doll nor its neighbour")
		_check(int(b.get_unit(target_id)["fray"]) == before_fray + 6
			and results[0].get("fray_event", {}).get("change", 0) == 6,
			"AC2: " + str(variant[0]) + " still applies its authored Fray 6")
		_check(results[0].get("statuses") == [{"status": "mark", "duration": 3}]
			and int(b.get_unit(target_id)["statuses"].get("mark", 0)) >= 1,
			"AC2: " + str(variant[0]) + " still Marks the reeled doll on a hit")
		_check(before_rng != b.rng_state(),
			"AC2: " + str(variant[0]) + " spends exactly the real hit roll")


# ---------------------------------------------------------------- AC3 marked reel and hunting lash

func _spool_pull_combo(seed_value: int) -> Dictionary:
	var battle := _spool_ready(seed_value)
	if battle == null:
		return {}
	var pull := battle.use_foe_ability("spool_snare", 4)
	var results: Array = pull.get("results", [])
	if not bool(pull.get("ok", false)) or results.size() != 1 \
			or not bool(results[0].get("hit", false)):
		return {}
	var target_id := str(results[0].get("target", ""))
	var reeled := battle.get_unit(target_id)
	if reeled.is_empty() or int(reeled.get("rank", 0)) != 3 \
			or int(reeled["statuses"].get("mark", 0)) <= 0:
		return {}
	if not _to(battle, SNAKE, 3):
		return {}
	return {
		"battle": battle,
		"seed": seed_value,
		"target_id": target_id,
		"pull": pull.duplicate(true),
		"choice": StitchedFoeIntent.choose(battle, battle.get_unit(SNAKE)),
		"state": battle.state_snapshot(),
		"rng": battle.rng_state(),
	}


func _spool_combo_trace(seed_value: int) -> Dictionary:
	var combo := _spool_pull_combo(seed_value)
	if combo.is_empty():
		return {}
	var battle: StitchedRules = combo["battle"]
	var choice: Dictionary = combo["choice"]
	if bool(choice.get("pass", true)):
		return {}
	var strike := battle.use_foe_ability(str(choice["ability_id"]), int(choice["target_rank"]))
	return {
		"seed": seed_value,
		"before_state": combo["state"],
		"before_rng": combo["rng"],
		"pull": combo["pull"],
		"choice": choice,
		"strike": strike,
		"after_state": battle.state_snapshot(),
		"after_rng": battle.rng_state(),
	}


func _test_spool_mark_combo() -> void:
	var witness: Dictionary = {}
	var miss_witness: Dictionary = {}
	for seed_value in range(1, 257):
		var combo := _spool_pull_combo(seed_value)
		if combo.is_empty():
			continue
		var choice: Dictionary = combo["choice"]
		if str(choice.get("ability_id", "")) != "snare_lash" \
				or int(choice.get("target_rank", 0)) != 3:
			continue
		var battle: StitchedRules = combo["battle"]
		var target_id := str(combo["target_id"])
		var before := battle.get_unit(target_id)
		if int(before["statuses"].get("mark", 0)) <= 0:
			continue
		var strike := battle.use_foe_ability("snare_lash", 3)
		var results: Array = strike.get("results", [])
		if not bool(strike.get("ok", false)) or results.size() != 1:
			continue
		if bool(results[0].get("hit", false)):
			if witness.is_empty():
				witness = combo
				witness["before"] = before
				witness["strike"] = strike.duplicate(true)
		elif miss_witness.is_empty():
			miss_witness = combo
			miss_witness["before"] = before
			miss_witness["strike"] = strike.duplicate(true)
		if not witness.is_empty() and not miss_witness.is_empty():
			break
	_check(not witness.is_empty(),
		"AC3: non-vacuous seeded reel-to-Mark-to-Lash hit witness")
	_check(not miss_witness.is_empty(),
		"AC3: non-vacuous seeded reel-to-Mark-to-Lash miss witness")
	if not miss_witness.is_empty():
		var miss_battle: StitchedRules = miss_witness["battle"]
		var miss_target := str(miss_witness["target_id"])
		var miss_before: Dictionary = miss_witness["before"]
		var miss_result: Dictionary = miss_witness["strike"]["results"][0]
		_check(miss_result.get("hit") == false
			and int(miss_result.get("damage", -1)) == 0
			and miss_result.get("statuses", []).is_empty()
			and int(miss_battle.get_unit(miss_target)["hp"]) == int(miss_before["hp"])
			and int(miss_battle.get_unit(miss_target)["statuses"].get("tangled", 0)) == 0,
			"AC3: a missed hunting Lash deals no damage and applies no Tangled")
		_check(int(miss_witness["choice"].get("target_rank", 0)) == 3,
			"AC3: the missed Lash was still aimed at the hunted rank 3")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var choice: Dictionary = witness["choice"]
	var target_id := str(witness["target_id"])
	var before: Dictionary = witness["before"]
	var strike: Dictionary = witness["strike"]
	var result: Dictionary = strike["results"][0]
	_check(str(choice.get("ability_id", "")) == "snare_lash"
		and int(choice.get("target_rank", 0)) == 3
		and choice.get("affected_ranks") == [3]
		and str(choice.get("target_side", "")) == "hero"
		and int(choice.get("base_mark_damage", 0)) == 3,
		"AC3: the marked rank-3 doll outranks unmarked ranks 1 and 2 for Snare Lash")
	var closer_one := _hero_at_rank(battle, 1)
	var closer_two := _hero_at_rank(battle, 2)
	_check(not closer_one.is_empty() and not closer_two.is_empty()
		and int(battle.get_unit(closer_one)["statuses"].get("mark", 0)) == 0
		and int(battle.get_unit(closer_two)["statuses"].get("mark", 0)) == 0,
		"AC3: nearer legal ranks 1 and 2 really exist and carry no Mark")
	_check(result.get("target") == target_id
		and int(result.get("target_rank", 0)) == 3,
		"AC3: the committed Lash strikes the hunted rank-3 doll, never a phantom rank")
	var bases: Array = [StitchedRules.crit_damage(5)] if bool(result.get("crit", false)) else [4, 5]
	var marked_expected: Array = []
	for base in bases:
		marked_expected.append(StitchedRules.damage_after_modifiers(
			base, {}, before["statuses"], true, 3, int(before["prot"])))
		_check(StitchedRules.damage_after_modifiers(
			base, {}, before["statuses"], true, 3, int(before["prot"]))
			== StitchedRules.damage_after_modifiers(
				int(base) + 3, {}, before["statuses"], false, 0, int(before["prot"])),
			"AC3: Mark adds exactly 3 to base direct damage before Weak/Exposed/Tangled/PROT")
	_check(marked_expected.has(int(result.get("damage", -1)))
		and int(result.get("damage", 0)) > 0,
		"AC3: the landed Lash really uses the authored +3 versus Mark")
	_check(result.get("statuses") == [{"status": "tangled", "duration": 1}]
		and int(battle.get_unit(target_id)["statuses"].get("tangled", 0))
			== (0 if battle.current_actor_id() == target_id else 1),
		"AC3: the landed hunting Lash still applies Tangled 1")
	_check(StitchedRules.damage_after_modifiers(5, {"weak": 1}, {"exposed": 1}, true, 3, 40)
		== 6 and StitchedRules.damage_after_modifiers(
			5, {"weak": 1}, {"exposed": 1}, false, 0, 40) == 3,
		"AC3: +3 precedes combined Weak/Exposed and PROT in the shared formula")
	var control := _spool_pull_combo(int(witness["seed"]))
	_check(not control.is_empty(),
		"AC3: the same seed replays the reel for the unmarked control")
	if not control.is_empty():
		var control_battle: StitchedRules = control["battle"]
		var control_target := str(control["target_id"])
		control_battle._units[control_target]["statuses"].erase("mark")
		var fallback := StitchedFoeIntent.choose(control_battle, control_battle.get_unit(SNAKE))
		_check(str(fallback.get("ability_id", "")) == "snare_lash"
			and int(fallback.get("target_rank", 0)) == 1
			and fallback.get("affected_ranks") == [1],
			"AC3: without the Mark the same Lash turn falls back to nearest legal rank 1")
		var control_before := control_battle.get_unit(control_target)
		var control_strike := control_battle.use_foe_ability("snare_lash", 3)
		var control_results: Array = control_strike.get("results", [])
		_check(control_results.size() == 1 and bool(control_results[0].get("hit", false)),
			"AC3: the paired unmarked control lands the same seeded hit")
		if control_results.size() == 1:
			var control_result: Dictionary = control_results[0]
			var unmarked_expected: Array = []
			for base in bases:
				unmarked_expected.append(StitchedRules.damage_after_modifiers(
					base, {}, control_before["statuses"], false, 0,
					int(control_before["prot"])))
			_check(int(control_result.get("roll", 0)) == int(result.get("roll", 0))
				and bool(control_result.get("crit", false)) == bool(result.get("crit", false)),
				"AC3: the unmarked control replays the identical seeded hit and crit rolls")
			_check(unmarked_expected.has(int(control_result.get("damage", -1)))
				and int(control_result.get("damage", 0)) < int(result.get("damage", 0)),
				"AC3: the unmarked control takes the lower, bonus-free damage")
	var first := _spool_combo_trace(int(witness["seed"]))
	var second := _spool_combo_trace(int(witness["seed"]))
	_check(not first.is_empty() and first == second,
		"AC4: identical seed and legal choices replay intent, pull, Lash, statuses, snapshot and RNG")


func _test_spool_refusals() -> void:
	var b := _spool_ready(11)
	if b == null:
		_check(false, "precondition: Spool Snarekeeper reaches its round-two turn")
		return
	var state := b.state_snapshot()
	var rng := b.rng_state()
	var wrong := b.use_foe_ability("spool_snare", 1)
	_check(wrong.get("ok") == false
		and str(wrong.get("error", "")) == "no legal target in rank 1",
		"AC2: rank-1 Spool Snare is refused by the real target mask")
	_check(b.state_snapshot() == state and b.rng_state() == rng,
		"AC2: refused Spool Snare spends no turn or RNG and mutates nothing")
	var missing_id := _hero_at_rank(b, 4)
	b._units[missing_id]["lost"] = true
	state = b.state_snapshot()
	rng = b.rng_state()
	var missing := b.use_foe_ability("spool_snare", 4)
	_check(missing.get("ok") == false
		and str(missing.get("error", "")) == "no legal target in rank 4",
		"AC4: a lost rank-4 doll leaves no legal Spool Snare target")
	_check(b.state_snapshot() == state and b.rng_state() == rng,
		"AC4: the lost-target refusal spends no turn or RNG and mutates nothing")
	b._units[missing_id]["lost"] = false
	b._units[SNAKE]["rank"] = 2
	state = b.state_snapshot()
	rng = b.rng_state()
	var out_of_launch := b.use_foe_ability("spool_snare", 4)
	_check(out_of_launch.get("ok") == false
		and str(out_of_launch.get("error", "")) == "ability cannot launch from rank 2",
		"AC2: rank-2 Spool Snare is refused before any roll by its launch mask")
	_check(b.state_snapshot() == state and b.rng_state() == rng,
		"AC2: out-of-launch Spool Snare consumes no turn or RNG and mutates nothing")
	var hero_turn := _battle(11, SNAKE)
	if hero_turn != null:
		for step in range(80):
			if hero_turn.current_side() == "hero":
				break
			hero_turn.pass_turn()
		_check(hero_turn.current_side() == "hero",
			"precondition: a real hero turn is reached")
		state = hero_turn.state_snapshot()
		rng = hero_turn.rng_state()
		var wrong_side := hero_turn.use_foe_ability("spool_snare", 4)
		_check(wrong_side.get("ok") == false
			and str(wrong_side.get("error", "")) == "it is not a foe turn",
			"AC4: a Snarekeeper action on a hero turn is refused")
		_check(hero_turn.state_snapshot() == state and hero_turn.rng_state() == rng,
			"AC4: the wrong-side refusal spends no turn or RNG and mutates nothing")
	var other_actor := _battle(11, SNAKE)
	if other_actor != null:
		for step in range(80):
			if other_actor.current_actor_id() == RAGLING:
				break
			other_actor.pass_turn()
		_check(other_actor.current_actor_id() == RAGLING,
			"precondition: the Ragling's own turn is reached")
		state = other_actor.state_snapshot()
		rng = other_actor.rng_state()
		var wrong_actor := other_actor.use_foe_ability("spool_snare", 4)
		_check(wrong_actor.get("ok") == false
			and str(wrong_actor.get("error", "")) == "the foe has no ability spool_snare",
			"AC4: another foe cannot borrow the Snarekeeper's Spool Snare")
		_check(other_actor.state_snapshot() == state and other_actor.rng_state() == rng,
			"AC4: the wrong-actor refusal spends no turn or RNG and mutates nothing")


func _spool_replay(seed_value: int) -> Dictionary:
	var battle := _spool_ready(seed_value)
	if battle == null:
		return {}
	var before_state := battle.state_snapshot()
	var before_rng := battle.rng_state()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(SNAKE))
	if choice.is_empty() or bool(choice.get("pass", true)):
		return {}
	var receipt := battle.use_foe_ability(str(choice["ability_id"]), int(choice["target_rank"]))
	return {
		"choice": choice,
		"receipt": receipt,
		"before_state": before_state,
		"before_rng": before_rng,
		"after_state": battle.state_snapshot(),
		"after_rng": battle.rng_state(),
	}


func _test_spool_replay() -> void:
	var first := _spool_replay(11)
	var second := _spool_replay(11)
	_check(first.size() > 0 and first == second,
		"AC4: identical seed replays the same Snarekeeper intent, target and receipt")
	_check(str(first.get("choice", {}).get("ability_id", "")) == "spool_snare"
		and int(first.get("choice", {}).get("target_rank", 0)) == 4
		and str(first.get("receipt", {}).get("ability", "")) == "spool_snare",
		"AC4: replayed Snarekeeper round two commits the advertised rank-4 Spool Snare")


# ---------------------------------------------------------------- AC2 exposing slam

func _test_slam() -> void:
	var hits := {1: 0, 2: 0}
	for target_rank in [1, 2]:
		for seed_value in range(1, 49):
			var b := _battle(seed_value)
			if b == null or not _to(b, ZIPPER):
				continue
			var target_id: String = HERO_IDS[target_rank - 1]
			var before := b.get_unit(target_id)
			var receipt := b.use_foe_ability("hauler_slam", target_rank)
			_check(bool(receipt.get("ok", false)) and receipt.get("ability") == "hauler_slam"
				and receipt.get("results", []).size() == 1,
				"seed %d commits one real Hauler Slam result" % seed_value)
			if receipt.get("results", []).size() != 1:
				continue
			var result: Dictionary = receipt["results"][0]
			_check(result.get("target") == target_id and int(result.get("target_rank", 0)) == target_rank,
				"seed %d Slam hits the lawful rank-%d hero" % [seed_value, target_rank])
			if not bool(result.get("hit", false)):
				_check(int(result.get("damage", -1)) == 0 and result.get("statuses", []).is_empty(),
					"missed rank-%d Slam deals no damage and applies no Exposed" % target_rank)
				continue
			hits[target_rank] += 1
			var bases: Array = [StitchedRules.crit_damage(7)] if bool(result.get("crit", false)) \
				else [5, 6, 7]
			var damages: Array = []
			for base in bases:
				damages.append(StitchedRules.apply_protection(base, int(before["prot"])))
			_check(damages.has(int(result.get("damage", -1))) and int(result.get("damage", 0)) > 0,
				"landed rank-%d Slam deals its seeded 5-7/crit damage through PROT" % target_rank)
			_check(int(result.get("target_hp", -1)) == int(before["hp"]) - int(result["damage"]),
				"landed rank-%d Slam removes exactly that post-PROT HP" % target_rank)
			_check(result.get("statuses") == [{"status": "exposed", "duration": 2}],
				"landed rank-%d Slam applies exactly Exposed 2" % target_rank)
			var after := b.get_unit(target_id)
			var expected_exposed := 1 if b.current_actor_id() == target_id else 2
			_check(int(after["statuses"].get("exposed", 0)) == expected_exposed,
				"actual rank-%d hero carries Exposed 2 after any immediate own-turn tick" % target_rank)
			break
	_check(hits[1] > 0 and hits[2] > 0,
		"nonvacuous confirmed Slam witnesses at both lawful front ranks")


# ---------------------------------------------------------------- AC4 refusals and misses

func _test_refusals_miss_and_blocked_pull() -> void:
	var b := _battle(37)
	if b == null or not _to(b, ZIPPER):
		return
	var state := b.state_snapshot()
	var rng := b.rng_state()
	var wrong := b.use_foe_ability("chain_drag", 1)
	_check(wrong.get("ok") == false and str(wrong.get("error", "")) == "no legal target in rank 1",
		"AC4: rank-1 Chain Drag is refused by the real target mask")
	_check(b.state_snapshot() == state and b.rng_state() == rng,
		"AC4: refused wrong-target rank spends no turn or RNG and mutates nothing")
	b._units[ZIPPER]["rank"] = 3
	state = b.state_snapshot()
	rng = b.rng_state()
	var out_of_launch := b.use_foe_ability("hauler_slam", 1)
	_check(out_of_launch.get("ok") == false
		and str(out_of_launch.get("error", "")) == "ability cannot launch from rank 3",
		"AC4: rank-3 Slam is refused before any roll by its launch mask")
	_check(b.state_snapshot() == state and b.rng_state() == rng,
		"AC4: out-of-launch Slam consumes no turn or RNG and mutates nothing")

	var miss_found := false
	var blocked_found := false
	for seed_value in range(1, 65):
		if not miss_found:
			var m := _battle(seed_value)
			if m != null and _to(m, ZIPPER):
				var target_id: String = HERO_IDS[1]
				var before_rng := m.rng_state()
				var before_ranks := _hero_ranks(m)
				var before_fray := int(m.get_unit(target_id)["fray"])
				var receipt := m.use_foe_ability("chain_drag", 2)
				var results: Array = receipt.get("results", [])
				if bool(receipt.get("ok", false)) and results.size() == 1 \
						and not bool(results[0].get("hit", true)):
					miss_found = true
					_check(before_rng != m.rng_state(),
						"AC4: a genuine miss still spends its one real hit roll")
					_check(int(results[0].get("damage", -1)) == 0 and not results[0].has("shift")
						and not results[0].has("fray_event") and results[0].get("statuses", []).is_empty(),
						"AC4: missed Chain Drag produces no damage, shift, Fray or status")
					_check(_hero_ranks(m) == before_ranks
						and int(m.get_unit(target_id)["fray"]) == before_fray,
						"AC4: missed Chain Drag causes no phantom displacement or Fray")
		if not blocked_found:
			var t := _battle(seed_value)
			if t != null and _to(t, ZIPPER):
				var target_id: String = HERO_IDS[1]
				t._units[target_id]["statuses"]["tangled"] = 1
				var target_rank := int(t.get_unit(target_id)["rank"])
				var front_rank := int(t.get_unit(HERO_IDS[0])["rank"])
				var fray_before := int(t.get_unit(target_id)["fray"])
				var receipt := t.use_foe_ability("chain_drag", 2)
				var results: Array = receipt.get("results", [])
				if bool(receipt.get("ok", false)) and results.size() == 1 \
						and bool(results[0].get("hit", false)):
					blocked_found = true
					_check(results[0].get("hit") == true and results[0].has("roll")
						and int(results[0]["roll"]) <= int(results[0]["hit_chance"]),
						"AC4: blocked-pull witness is a true hit, never a counterfeit miss")
					_check(results[0].get("shift") == {"ok": false, "reason": "tangled units cannot move"},
						"AC4: a landed but blocked pull reports the explicit failed shift")
					_check(int(t.get_unit(target_id)["rank"]) == target_rank
						and int(t.get_unit(HERO_IDS[0])["rank"]) == front_rank,
						"AC4: blocked pull moves neither the tangled target nor its front ally")
					_check(int(t.get_unit(target_id)["fray"]) == fray_before + 4
						and results[0].get("fray_event", {}).get("change", 0) == 4,
						"AC4: a landed blocked pull still applies its authored Fray 4")
		if miss_found and blocked_found:
			break
	_check(miss_found and blocked_found, "nonvacuous seeded miss and blocked-pull witnesses")


# ---------------------------------------------------------------- AC3 intent rotation and replay

func _test_intent_and_replay() -> void:
	var first := _trace(19)
	var second := _trace(19)
	_check(first.size() > 15 and first == second,
		"AC3: identical seed and actions replay receipts, RNG and full snapshots")
	var seen: Dictionary = {}
	for entry in first:
		if str(entry.get("actor", "")) == ZIPPER:
			seen[int(entry["round"])] = str(entry["receipt"].get("ability", ""))
	_check(seen.get(1) == "hauler_slam" and seen.get(2) == "chain_drag"
		and seen.get(3) == "hauler_slam",
		"AC3: real round rotation advertises Slam, Chain Drag, Slam")


func _trace(seed_value: int) -> Array:
	var b := _battle(seed_value)
	var trace: Array = []
	if b == null:
		return trace
	for step in range(48):
		if b.is_over() or b.round_number() > 3:
			break
		var state := b.state_snapshot()
		var rng := b.rng_state()
		var round_value := b.round_number()
		var actor := b.current_actor_id()
		var choice := StitchedFoeIntent.choose(b, b.get_unit(ZIPPER))
		_check(b.state_snapshot() == state and b.rng_state() == rng,
			"intent projection never mutates state or consumes RNG")
		var receipt: Dictionary
		if actor == ZIPPER:
			var expected_id := "hauler_slam" if round_value % 2 == 1 else "chain_drag"
			var slam := expected_id == "hauler_slam"
			_check(not choice.is_empty() and not bool(choice.get("pass", true))
				and choice.get("foe_id") == ZIPPER and choice.get("foe_name") == "Zipper Hauler"
				and choice.get("ability_id") == expected_id
				and choice.get("target_side") == "hero"
				and choice.get("ability_kind") == ("melee" if slam else "debuff")
				and not bool(choice.get("multi", true))
				and int(choice.get("target_rank", 0)) == (1 if slam else 4)
				and choice.get("affected_ranks") == ([1] if slam else [4])
				and int(choice.get("base_acc", -1)) == (84 if slam else 88)
				and choice.get("base_damage") == ([5, 7] if slam else [0, 0])
				and int(choice.get("base_crit", -1)) == 0
				and choice.get("base_effects") == ({"exposed": 2} if slam else {"pull": 1, "fray": 4}),
				"AC3: round %d intent advertises the authored %s" % [round_value, expected_id])
			receipt = b.use_foe_ability(str(choice["ability_id"]), int(choice["target_rank"]))
			_check(bool(receipt.get("ok", false)) and receipt.get("actor") == ZIPPER
				and receipt.get("ability") == expected_id and receipt.get("results", []).size() == 1,
				"AC3: committed round %d receipt executes the advertised %s" % [round_value, expected_id])
		else:
			receipt = b.pass_turn()
		_check(bool(receipt.get("ok", false)), "AC3: replay sequence uses only successful legal actions")
		trace.append({
			"round": round_value,
			"actor": actor,
			"receipt": receipt,
			"state": b.state_snapshot(),
			"rng": b.rng_state(),
		})
	return trace


# ---------------------------------------------------------------- live mounted path

func _test_live_driver() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(_config(23)),
		"live battle screen begins with canonical Zipper Hauler and the real S2 party")
	if screen.battle == null:
		screen.free()
		return
	root.add_child(screen)
	await process_frame
	var seen: Dictionary = {}
	for step in range(24):
		for receipt in screen.receipts:
			if receipt.get("actor") == ZIPPER and receipt.get("action") == "ability":
				seen[str(receipt.get("ability", ""))] = true
		if seen.has("hauler_slam") and seen.has("chain_drag"):
			break
		if screen.battle.is_over():
			break
		_check(screen.battle.current_side() == "hero"
			and bool(screen.submit_pass().get("ok", false)),
			"AC3: real player Pass drives the mounted automatic foe driver")
	_check(seen.has("hauler_slam") and seen.has("chain_drag"),
		"live mounted driver commits both canonical Zipper Stitched moves")
	screen.free()


# ---------------------------------------------------------------- live mounted Snarekeeper

func _test_live_spool_driver() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(_config(11, SNAKE)),
		"live battle screen begins with canonical Spool Snarekeeper and the real S2 party")
	if screen.battle == null:
		screen.free()
		return
	root.add_child(screen)
	await process_frame
	var seen: Dictionary = {}
	var displayed_seen := false
	var matched := false
	for step in range(40):
		if screen.battle.is_over():
			break
		if screen.battle.current_side() != "hero":
			await process_frame
			continue
		# Every currently displayed foe plate is the pure chooser's projection.
		var before_intents: Dictionary = {}
		for foe in screen.battle.get_foes():
			before_intents[str(foe["id"])] = screen._foe_intents.get(int(foe["rank"]), {})
		var snake_rank := int(screen.battle.get_unit(SNAKE).get("rank", 0))
		if snake_rank > 0 and screen._foe_tickets[snake_rank].visible:
			displayed_seen = true
			_check(screen._foe_intents.get(snake_rank, {})
				== StitchedFoeIntent.choose(screen.battle, screen.battle.get_unit(SNAKE)),
				"AC4: live Snarekeeper plate displays the authoritative chooser projection")
		var before := screen.receipts.size()
		_check(bool(screen.submit_pass().get("ok", false)),
			"AC4: real player Pass drives the mounted automatic Snarekeeper driver")
		for i in range(before, screen.receipts.size()):
			var item: Dictionary = screen.receipts[i]
			if str(item.get("actor", "")) != SNAKE or str(item.get("action", "")) != "ability":
				continue
			var ability := str(item.get("ability", ""))
			seen[ability] = true
			var projected: Dictionary = before_intents.get(SNAKE, {})
			if ability == "spool_snare" and str(projected.get("ability_id", "")) == "spool_snare":
				var results: Array = item.get("results", [])
				_check(results.size() == 1
					and int(results[0].get("target_rank", 0)) == int(projected.get("target_rank", 0))
					and int(projected.get("target_rank", 0)) == 4,
					"AC4: the displayed rank-4 Spool Snare is the committed target rank")
				matched = true
		if seen.has("snare_lash") and seen.has("spool_snare"):
			break
	_check(displayed_seen, "non-vacuous: the mounted Snarekeeper really shows a plate")
	_check(matched, "AC4: the live driver commits its displayed Spool Snare to rank 4")
	_check(seen.has("snare_lash") and seen.has("spool_snare"),
		"live mounted driver commits both canonical Snarekeeper Stitched moves")
	screen.free()
