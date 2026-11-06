extends SceneTree
## Canonical Zipper Hauler JSON -> real StitchedEnemyCatalog -> seeded StitchedRules and
## StitchedFoeIntent. The shipped rules core is the only combat engine used here.

const ZIPPER := "zipper_hauler"
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
		_test_drag(2)
		_test_drag(4)
		_test_slam()
		_test_refusals_miss_and_blocked_pull()
		_test_intent_and_replay()
		await _test_live_driver()
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


# ---------------------------------------------------------------- live battle helpers

func _config(seed_value: int) -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"].duplicate(true))
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(catalog, ZIPPER),
		StitchedEnemyCatalog.foe_for(catalog, RAGLING),
	]
	return config


func _battle(seed_value: int) -> StitchedRules:
	var built := StitchedRules.create(_config(seed_value))
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
				and int(choice.get("target_rank", 0)) == (1 if slam else 2)
				and choice.get("affected_ranks") == [1 if slam else 2]
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
