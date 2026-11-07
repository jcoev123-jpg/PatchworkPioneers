extends SceneTree
## S5 Crochet Hook Harrier "Hook Drag" rear-rank reel.
##
## Canonical run_enemies.json record -> real StitchedEnemyCatalog -> seeded four-doll
## StitchedRules fight. The shared live intent chooser advertises the deepest legal doll and
## the public StitchedRules.use_foe_ability commits the authored hit, damage and one-rank pull.
## No resolver is reimplemented here and no RNG is stubbed: witnesses are found across a
## small bounded set of real seeds.

const HARRIER := "crochet_hook_harrier"
const HOOK_DRAG := "hook_drag"
const TROPHY := "crochet_hook_harrier_hook"
const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const POSES := "res://data/art/move_poses.json"

const DRAG := {
	"id": "hook_drag", "name": "Hook Drag", "kind": "melee",
	"launch": [1, 3], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [3, 5], "crit": 0, "effects": {"pull": 1},
	"self_move": 0, "move": "attack2",
}
const HARRY := {
	"id": "harry", "name": "Harry", "kind": "move",
	"launch": [1, 3], "target": [1, 3], "target_side": "self", "multi": false,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"dodge": 4, "duration": 1},
	"self_move": 1, "move": "skill",
}
const LEGACY := {"target": "front", "actions": [
	{"type": "shove", "amount": 0, "direction": -1, "weight": 2},
	{"type": "attack", "amount": 7, "weight": 3},
	{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
	{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1},
	{"type": "attack", "amount": 9, "move": "attack3", "weight": 1},
]}

var catalog: Dictionary
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, note: String) -> void:
	checks += 1
	if not condition:
		failures.append(note)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"canonical S5 catalog loads: " + str(catalog.get("error", "")))
	if bool(catalog.get("ok", false)):
		_test_authored()
		var witnesses := _test_intent_and_cast()
		_test_blocked_shifts(int(witnesses.get("hit_seed", -1)))
		_test_refusals()
		_test_replay(int(witnesses.get("hit_seed", -1)), int(witnesses.get("miss_seed", -1)))
		await _test_live_driver()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_crochet_hook_harrier_drag_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- AC1 authored record

func _record(path: String, enemy_id: String) -> Dictionary:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(records is Array, "real source parses as an array: " + path)
	if not records is Array:
		return {}
	var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == enemy_id)
	_check(matches.size() == 1, "exactly one authored record for " + enemy_id)
	return matches[0] if matches.size() == 1 else {}


func _test_authored() -> void:
	var record := _record(RUN, HARRIER)
	if record.is_empty():
		return
	_check(record.get("name") == "Crochet Hook Harrier" and int(record.get("max_hp", 0)) == 26
		and record.get("art_path") == "res://assets/paper/enemies/crochet_hook_harrier.png"
		and record.get("intent") == JSON.parse_string(JSON.stringify(LEGACY)),
		"AC1: legacy identity, art path, HP and all five weighted card actions stay exact")
	var authored: Array = record.get("stitched", {}).get("abilities", [])
	_check(authored == JSON.parse_string(JSON.stringify([DRAG, HARRY])),
		"AC1: only Hook Drag's target list widened; Harry and the authored ability order are unchanged")
	var expected := {"max_hp": 26, "speed": 6, "dodge": 8, "acc": 0, "prot": 2,
		"is_boss": false, "turns_per_round": 1, "trophy": TROPHY, "abilities": [DRAG, HARRY]}
	_check(record.get("stitched") == JSON.parse_string(JSON.stringify(expected)),
		"AC1: exact authored profile (HP, SPEED, DODGE, ACC, PROT, trophy and kit)")
	var foe := StitchedEnemyCatalog.foe_for(catalog, HARRIER)
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, HARRIER) == TROPHY,
		"AC1: the canonical foe and its unique trophy load")
	if foe.is_empty():
		return
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected[key], "AC1: loaded stat stays exact: " + key)
	var normalized: Array = []
	for ability in [DRAG, HARRY]:
		var validated := StitchedParts.validate_ability(ability)
		_check(bool(validated.get("ok", false)),
			"AC1: " + str(ability["id"]) + " validates independently through the real parts rules")
		if bool(validated.get("ok", false)):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized,
		"AC1: the loader exposes the exact normalized two-ability Harrier kit in order")
	var abilities: Array = foe.get("abilities", [])
	if abilities.size() != 2:
		_check(false, "AC1: the Harrier still authors exactly two Stitched abilities")
		return
	var drag: Dictionary = abilities[0]
	_check(str(drag["id"]) == HOOK_DRAG and str(drag["name"]) == "Hook Drag"
		and str(drag["kind"]) == "melee" and drag.get("launch") == [1, 3]
		and drag.get("target") == [1, 2, 3, 4] and str(drag["target_side"]) == "enemy"
		and not bool(drag.get("multi", true)) and int(drag.get("acc", 0)) == 87
		and drag.get("dmg") == [3, 5] and int(drag.get("crit", -1)) == 0
		and drag.get("effects") == {"pull": 1} and int(drag.get("self_move", -1)) == 0
		and str(drag.get("move", "")) == "attack2",
		"AC1: Hook Drag is the authored melee hook (launch 1/3 -> ranks 1-4, 3-5, ACC 87, pull 1, attack2)")
	_check(int(drag.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(drag.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4]),
		"AC1: the derived launch (1, 3) and target (1-4) masks are exactly the authored ranks")
	for rank in range(1, 5):
		_check(StitchedParts.ranks_allowed(int(drag["target_mask"]), rank),
			"AC1: every occupied doll rank %d is now a legal Hook Drag target" % rank)
	_check(not StitchedParts.ranks_allowed(int(drag["launch_mask"]), 2)
		and not StitchedParts.ranks_allowed(int(drag["launch_mask"]), 4),
		"AC1: the hook still launches only from foe ranks 1 and 3")
	_check(str(abilities[1]["id"]) == "harry" and abilities[1].get("effects") == {"dodge": 4, "duration": 1}
		and int(abilities[1].get("self_move", 0)) == 1 and str(abilities[1].get("move", "")) == "skill",
		"AC1: Harry keeps self dodge 4 for one turn, its skill pose and the self_move step")
	var poses: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	var harrier_poses: Dictionary = poses.get("enemies", {}).get(HARRIER, {}) if poses is Dictionary else {}
	_check(harrier_poses.has("attack2") and str(harrier_poses["attack2"].get("name", "")) == "Talon Dive"
		and str(harrier_poses["attack2"].get("art", "")).begins_with("res://assets/paper/"),
		"AC1: Hook Drag keeps the existing authored attack2 paper-puppet pose")
	var part: Dictionary = catalog.get("parts_by_id", {}).get(TROPHY, {})
	_check(not part.is_empty() and str(part.get("owner", "")) == "any"
		and str(part.get("name", "")) == "Crochet Hook",
		"AC1: the unique trophy part stays the unchanged any-owner Crochet Hook")


# ---------------------------------------------------------------- live battle helpers

func _config(seed_value: int) -> Dictionary:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	if not preview is Dictionary:
		_check(false, "real hero/part preview document exists")
		return {}
	var config: Dictionary = preview
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"].duplicate(true))
	# Two other distinct legal foes place the Harrier in its legal rank-3 launch lane.
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(catalog, "scissor_crab"),
		StitchedEnemyCatalog.foe_for(catalog, "moth_scribe"),
		StitchedEnemyCatalog.foe_for(catalog, HARRIER),
	]
	return config


func _battle(seed_value: int) -> StitchedRules:
	var config := _config(seed_value)
	if config.is_empty():
		return null
	var foes: Array = config["foes"]
	_check(foes.size() == 3 and not foes[0].is_empty() and not foes[1].is_empty()
		and not foes[2].is_empty() and str(foes[2].get("id", "")) == HARRIER,
		"seed %d: three distinct canonical normal foes load, the Harrier last" % seed_value)
	var built := StitchedRules.create(config)
	_check(bool(built.get("ok", false)),
		"seed %d builds a real four-doll 4v3 battle: %s" % [seed_value, str(built.get("error", ""))])
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and int(battle.get_unit(HARRIER)["rank"]) == 3,
		"seed %d: four dolls face three foes and the Harrier acts from legal rank 3" % seed_value)
	_check(battle.turn_order().size() == 7 and int(battle.turn_order().count(HARRIER)) == 1,
		"seed %d: the rolled SPEED+1d8 order gives each of the seven actors exactly one turn" % seed_value)
	for hero in battle.get_heroes():
		_check(int(hero["hp"]) == int(hero["max_hp"]) and int(hero["fray"]) == 0
			and hero["statuses"].is_empty() and not bool(hero["lost"]),
			"seed %d: every doll begins healthy and untangled" % seed_value)
	return battle


func _reach_harrier(battle: StitchedRules, receipts: Array) -> bool:
	for step in range(24):
		if battle.is_over():
			return false
		if battle.current_actor_id() == HARRIER:
			return true
		var receipt := battle.pass_turn()
		_check(bool(receipt.get("ok", false)), "advance other real turns by legal pass")
		receipts.append(receipt)
	_check(false, "must reach the Harrier's real turn")
	return false


## get_heroes()/get_foes() expose the live unit dictionaries; every pre-action witness has to be
## a detached copy or a later hit would rewrite the very "before" snapshot it is compared with.
func _heroes_snapshot(battle: StitchedRules) -> Array:
	var heroes: Array = []
	for hero in battle.get_heroes():
		heroes.append(hero.duplicate(true))
	return heroes


func _ranks(battle: StitchedRules) -> Dictionary:
	var ranks: Dictionary = {}
	for hero in battle.get_heroes():
		ranks[str(hero["id"])] = int(hero["rank"])
	return ranks


func _foe_ranks(battle: StitchedRules) -> Dictionary:
	var ranks: Dictionary = {}
	for foe in battle.get_foes():
		ranks[str(foe["id"])] = int(foe["rank"])
	return ranks


func _sorted_ranks(battle: StitchedRules) -> Array:
	var ranks: Array = []
	for hero in battle.get_heroes():
		ranks.append(int(hero["rank"]))
	ranks.sort()
	return ranks


func _damage_candidates(actor: Dictionary, target: Dictionary, battle: StitchedRules,
		crit: bool) -> Array:
	var bases: Array = [StitchedRules.crit_damage(5)] if crit else [3, 4, 5]
	var candidates: Array = []
	for base in bases:
		var scaled := StitchedS1BEffects.enemy_damage(base + int(actor.get("dmg_bonus", 0)),
			battle.candle())
		candidates.append(StitchedRules.damage_after_modifiers(scaled, actor["statuses"],
			target["statuses"], false, 0, int(target.get("prot", 0))))
	return candidates


# ---------------------------------------------------------------- AC2/AC3 intent and cast

func _test_intent_and_cast() -> Dictionary:
	var hit_seed := -1
	var miss_seed := -1
	var intent_seen := false
	for seed_value in range(1, 97):
		var battle := _battle(seed_value)
		if battle == null:
			continue
		var receipts: Array = []
		if not _reach_harrier(battle, receipts):
			continue
		var before_heroes := _heroes_snapshot(battle)
		var before_ranks := _ranks(battle)
		var before_foe_ranks := _foe_ranks(battle)
		var back_id := str(before_heroes[3]["id"])
		var partner_id := str(before_heroes[2]["id"])
		var before_back: Dictionary = before_heroes[3]
		var actor := battle.get_unit(HARRIER)
		var drag: Dictionary = {}
		for authored in actor.get("abilities", []):
			if str(authored["id"]) == HOOK_DRAG:
				drag = authored
		if not intent_seen:
			intent_seen = true
			_check(battle.round_number() == 1 and battle.current_side() == "foe"
				and battle.current_actor_id() == HARRIER,
				"AC2: the real round-one Harrier owns its live turn with Hook Drag next in its cycle")
			_check(int(actor["rank"]) == 3 and int(before_back["rank"]) == 4
				and int(before_heroes[2]["rank"]) == 3,
				"AC2: harrier rank 3, rear doll rank 4 and an adjacent rank-3 swap partner")
			var rank_one: Array = battle._legal_targets(actor, drag, 1)
			var rank_two: Array = battle._legal_targets(actor, drag, 2)
			var rank_three: Array = battle._legal_targets(actor, drag, 3)
			var rank_four: Array = battle._legal_targets(actor, drag, 4)
			_check(rank_one.size() == 1 and rank_two.size() == 1 and rank_three.size() == 1
				and rank_four.size() == 1,
				"AC2: the widened mask reaches all four occupied doll ranks")
			_check(str(rank_four[0]["id"]) == back_id and str(rank_three[0]["id"]) == partner_id
				and str(rank_one[0]["id"]) == str(before_heroes[0]["id"]),
				"AC2: rank 4 really holds the rear doll and ranks 1-3 hold the others")
			var state := battle.state_snapshot()
			var rng := battle.rng_state()
			var intent := StitchedFoeIntent.choose(battle, actor)
			_check(state == battle.state_snapshot() and rng == battle.rng_state()
				and battle.current_actor_id() == HARRIER,
				"AC2: projecting the live intent mutates nothing, spends no RNG and keeps the turn")
			_check(not intent.get("pass", true) and not intent.get("stun", false)
				and str(intent.get("foe_id", "")) == HARRIER
				and str(intent.get("ability_id", "")) == HOOK_DRAG
				and str(intent.get("ability_name", "")) == "Hook Drag"
				and str(intent.get("ability_kind", "")) == "melee"
				and str(intent.get("target_side", "")) == "hero"
				and int(intent.get("target_rank", 0)) == 4
				and intent.get("affected_ranks") == [4]
				and not bool(intent.get("multi", true))
				and int(intent.get("base_acc", -1)) == 87
				and intent.get("base_damage") == [3, 5]
				and int(intent.get("base_crit", -1)) == 0
				and intent.get("base_effects") == {"pull": 1},
				"AC2: the chooser forecasts Hook Drag at rank 4 (not rank 1) with authored numbers")
			if intent.get("base_effects", {}).has("pull"):
				intent["base_effects"]["pull"] = 3
				_check(StitchedFoeIntent.choose(battle, battle.get_unit(HARRIER)).get("base_effects")
					== {"pull": 1},
					"AC2: the projected effects are detached from the canonical ability catalog")
		var receipt := battle.use_foe_ability(HOOK_DRAG, 4)
		receipts.append(receipt)
		var results: Array = receipt.get("results", [])
		if not bool(receipt.get("ok", false)) or results.size() != 1:
			_check(false, "AC2: the forecasted rank-4 Hook Drag commits exactly one real target result")
			continue
		var result: Dictionary = results[0]
		var chance := StitchedRules.hit_chance(
			87 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"]),
			StitchedRules.effective_dodge(before_back), int(actor["miss_streak"]))
		_check(str(receipt.get("actor", "")) == HARRIER
			and str(receipt.get("ability", "")) == HOOK_DRAG
			and str(receipt.get("target", "")) == back_id,
			"AC2: the committed turn is the Harrier's single-target Hook Drag on the rear doll")
		_check(str(result.get("target", "")) == back_id and int(result.get("target_rank", 0)) == 4,
			"AC2: the result names the occupied rank-4 doll the hook reached")
		_check(int(result.get("hit_chance", -1)) == chance
			and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
			"AC2: the hit is a genuine authored-ACC seeded roll, never a forced outcome")
		if bool(result.get("hit", false)):
			if hit_seed < 0:
				hit_seed = seed_value
				var candidates := _damage_candidates(actor, before_back, battle,
					bool(result.get("crit", false)))
				_check(candidates.has(int(result.get("damage", -1)))
					and int(result.get("damage", 0)) > 0
					and int(result.get("target_hp", -1))
						== int(before_back["hp"]) - int(result["damage"]),
					"AC3: a landed hook rolls authored 3-5/crit damage through normal PROT")
				_check(result.get("statuses", []) == [] and not result.has("fray_event"),
					"AC3: Hook Drag applies movement, not an invented status or fray")
				_check(result.get("shift") == {"ok": true, "from": 4, "to": 3,
					"swapped": partner_id},
					"AC3: the landed hook reels the rank-4 doll exactly one rank forward with its neighbour")
				var expected_back: Dictionary = before_back.duplicate(true)
				expected_back["rank"] = 3
				expected_back["hp"] = int(before_back["hp"]) - int(result["damage"])
				var expected_partner: Dictionary = before_heroes[2].duplicate(true)
				expected_partner["rank"] = 4
				_check(battle.get_unit(back_id) == expected_back,
					"AC3: the reeled rear doll keeps identity and arrives at rank 3 with that HP loss")
				_check(battle.get_unit(partner_id) == expected_partner,
					"AC3: the former rank-3 doll swaps to rank 4 with every other field kept")
				_check(_sorted_ranks(battle) == [1, 2, 3, 4]
					and _ranks(battle) == {str(before_heroes[0]["id"]): 1,
						str(before_heroes[1]["id"]): 2, back_id: 3, partner_id: 4},
					"AC3: both hooked dolls trade exactly ranks 4 and 3, all four ranks stay occupied")
				for index in range(2):
					var old: Dictionary = before_heroes[index]
					var hero := battle.get_unit(str(old["id"]))
					_check(int(hero["rank"]) == int(before_ranks[str(old["id"])])
						and int(hero["hp"]) == int(old["hp"]),
						"AC3: untouched front doll %d keeps its rank and HP" % (index + 1))
				_check(_foe_ranks(battle) == before_foe_ranks,
					"AC3: no foe rank moves during the reel")
		else:
			if miss_seed < 0:
				miss_seed = seed_value
				_check(int(result.get("damage", -1)) == 0 and not result.has("shift")
					and result.get("statuses", []) == [] and not result.has("fray_event")
					and int(result.get("target_hp", -1)) == int(before_back["hp"]),
					"AC4: a natural seeded miss deals no damage, pull, status or fray")
				_check(_ranks(battle) == before_ranks and _sorted_ranks(battle) == [1, 2, 3, 4]
					and battle.get_unit(back_id) == before_back
					and battle.get_unit(partner_id) == before_heroes[2],
					"AC4: a missed hook leaves every doll exactly where and as it was")
				_check(_foe_ranks(battle) == before_foe_ranks, "AC4: a missed hook moves no foe")
		if hit_seed > 0 and miss_seed > 0:
			break
	_check(hit_seed > 0 and miss_seed > 0,
		"nonvacuous bounded real-seed Harrier hit and miss witnesses")
	return {"hit_seed": hit_seed, "miss_seed": miss_seed}


# ---------------------------------------------------------------- AC4 blocked reels

func _test_blocked_shifts(hit_seed: int) -> void:
	if hit_seed <= 0:
		_check(false, "AC4: a genuine landed hook seed is required for the blocked-reel witnesses")
		return
	var variants := [
		["cut", "thread cut blocks movement"],
		["tangled", "tangled units cannot move"],
	]
	var witnessed := 0
	for variant in variants:
		var battle := _battle(hit_seed)
		if battle == null:
			_check(false, "AC4: the blocked-reel fixture could not rebuild the landed seed")
			return
		var receipts: Array = []
		if not _reach_harrier(battle, receipts):
			_check(false, "AC4: the blocked-reel fixture could not reach the Harrier turn")
			return
		var before_heroes := _heroes_snapshot(battle)
		var before_ranks := _ranks(battle)
		var before_foe_ranks := _foe_ranks(battle)
		var back_id := str(before_heroes[3]["id"])
		var partner_id := str(before_heroes[2]["id"])
		if str(variant[0]) == "cut":
			battle._thread_cuts[back_id] = int(before_heroes[3]["rank"])
		else:
			battle._units[back_id]["statuses"]["tangled"] = 2
		# Re-read after the fixture so its statuses feed the expected damage exactly.
		var fixture_target := battle.get_unit(back_id)
		var fixture_actor := battle.get_unit(HARRIER)
		var receipt := battle.use_foe_ability(HOOK_DRAG, 4)
		var results: Array = receipt.get("results", [])
		var label := str(variant[0])
		if not bool(receipt.get("ok", false)) or results.size() != 1:
			_check(false, "AC4: %s witness still resolves exactly one Hook Drag result" % label)
			continue
		var result: Dictionary = results[0]
		_check(bool(result.get("hit", false))
			and int(result.get("roll", 0)) <= int(result.get("hit_chance", 0)),
			"AC4: %s witness still lands the same seeded authored hook hit" % label)
		if not bool(result.get("hit", false)):
			continue
		witnessed += 1
		_check(result.get("shift") == {"ok": false, "reason": str(variant[1])},
			"AC4: %s refuses the reel through the ordinary movement gate: %s"
				% [label, str(variant[1])])
		var candidates := _damage_candidates(fixture_actor, fixture_target, battle,
			bool(result.get("crit", false)))
		_check(int(result.get("damage", 0)) > 0
			and candidates.has(int(result.get("damage", -1)))
			and int(result.get("target_hp", -1))
				== int(fixture_target["hp"]) - int(result["damage"]),
			"AC4: %s still deals its normal direct damage" % label)
		_check(_ranks(battle) == before_ranks and _sorted_ranks(battle) == [1, 2, 3, 4],
			"AC4: %s never teleports either doll; all four ranks stay intact" % label)
		_check(int(battle.get_unit(back_id)["rank"]) == 4
			and int(battle.get_unit(partner_id)["rank"]) == 3,
			"AC4: %s leaves the rear doll at rank 4 and its neighbour at rank 3" % label)
		_check(_foe_ranks(battle) == before_foe_ranks,
			"AC4: %s moves no foe rank" % label)
	_check(witnessed == variants.size(),
		"AC4: nonvacuous thread-cut and Tangled rear-doll reel refusals")


# ---------------------------------------------------------------- AC4 refusals and replay

func _test_refusals() -> void:
	var battle: StitchedRules = null
	for seed_value in range(1, 97):
		battle = _battle(seed_value)
		if battle == null:
			continue
		var receipts: Array = []
		if _reach_harrier(battle, receipts):
			break
		battle = null
	if battle == null:
		_check(false, "AC4: a real Harrier turn is required for the illegal-target refusals")
		return
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	for rank in [0, 5]:
		var rejected := battle.use_foe_ability(HOOK_DRAG, rank)
		_check(not bool(rejected.get("ok", true))
			and str(rejected.get("error", "")) == "no legal target in rank %d" % rank
			and before == battle.state_snapshot() and rng == battle.rng_state()
			and battle.current_actor_id() == HARRIER,
			"AC4: out-of-mask rank %d is refused with no turn, state or RNG spend" % rank)
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: every refused cast leaves the Harrier's real turn untouched")
	var actor := battle.get_unit(HARRIER)
	var drag: Dictionary = {}
	for authored in actor.get("abilities", []):
		if str(authored["id"]) == HOOK_DRAG:
			drag = authored
	_check(battle._legal_targets(actor, drag, 1).size() == 1
		and battle._legal_targets(actor, drag, 4).size() == 1,
		"AC4: the same untouched turn still offers the authored ranks 1-4")
	var accepted := battle.use_foe_ability(HOOK_DRAG, 4)
	_check(bool(accepted.get("ok", false)) and accepted.get("results", []).size() == 1
		and int(accepted["results"][0].get("target_rank", 0)) == 4,
		"AC4: the untouched turn still commits the canonical rank-4 hook")


## One deterministic action trace: legal passes up to the Harrier, an optional real fixture,
## then the canonical rank-4 hook (the "invalid" mode first refuses two out-of-mask ranks).
func _script(seed_value: int, mode: String) -> Dictionary:
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _reach_harrier(battle, receipts):
		return {}
	if mode == "invalid":
		receipts.append(battle.use_foe_ability(HOOK_DRAG, 0))
		receipts.append(battle.use_foe_ability(HOOK_DRAG, 5))
	var back_id := str(battle.get_heroes()[3]["id"])
	if mode == "cut":
		battle._thread_cuts[back_id] = 4
	elif mode == "tangled":
		battle._units[back_id]["statuses"]["tangled"] = 2
	receipts.append(battle.use_foe_ability(HOOK_DRAG, 4))
	return {
		"seed": seed_value, "mode": mode, "receipts": receipts,
		"heroes": _heroes_snapshot(battle), "order": battle.turn_order(),
		"state": battle.state_snapshot(), "rng": battle.rng_state(),
	}


func _test_replay(hit_seed: int, miss_seed: int) -> void:
	if hit_seed <= 0 or miss_seed <= 0:
		_check(false, "AC4: hit and miss seeds are required for the replay witnesses")
		return
	var fixtures := [
		[hit_seed, "hit"], [miss_seed, "miss"], [hit_seed, "cut"],
		[hit_seed, "tangled"], [hit_seed, "invalid"],
	]
	for fixture in fixtures:
		var seed_value := int(fixture[0])
		var mode := str(fixture[1])
		var first := _script(seed_value, mode)
		var replay := _script(seed_value, mode)
		_check(not first.is_empty() and first == replay,
			"AC4: %s seed %d replays receipts, hero state, order, snapshot and final RNG identically"
				% [mode, seed_value])


# ---------------------------------------------------------------- live mounted driver

func _verify_live_cast(screen: StitchedBattleScreen, watched: Dictionary) -> void:
	if bool(watched.get("cast", false)):
		return
	for receipt in screen.receipts:
		if str(receipt.get("actor", "")) != HARRIER \
				or str(receipt.get("action", "")) != "ability" \
				or str(receipt.get("ability", "")) != HOOK_DRAG:
			continue
		var results: Array = receipt.get("results", [])
		if results.size() != 1:
			continue
		watched["cast"] = true
		var result: Dictionary = results[0]
		_check(int(result.get("target_rank", 0)) == 4,
			"AC2: the live automatic driver commits Hook Drag on the farthest legal rank 4")
		if bool(result.get("hit", false)):
			_check(result.get("shift", {}).get("ok", false)
				and int(result.get("shift", {}).get("from", 0)) == 4
				and int(result.get("shift", {}).get("to", 0)) == 3,
				"AC3: the live landed hook reels rank 4 into rank 3 through the shared rules")
			_check(_sorted_ranks(screen.battle) == [1, 2, 3, 4],
				"AC3: live play still leaves four dolls in unique ranks")
		return


func _test_live_driver() -> void:
	var watched := {"cast": false, "displayed": false}
	for seed_value in [3, 5, 11, 19, 23]:
		if bool(watched["cast"]) and bool(watched["displayed"]):
			break
		var screen := StitchedBattleScreen.new()
		_check(screen.begin(_config(seed_value)),
			"live battle screen begins with the canonical Harrier and the real S2 party (seed %d)"
				% seed_value)
		if screen.battle == null:
			screen.free()
			continue
		root.add_child(screen)
		await process_frame
		_verify_live_cast(screen, watched)
		for step in range(40):
			if screen.battle.is_over():
				break
			if screen.battle.current_side() != "hero":
				_check(false, "live screen leaves the next decision with the player")
				break
			var harrier := screen.battle.get_unit(HARRIER)
			var harrier_rank := int(harrier.get("rank", 0))
			if harrier_rank > 0 and screen._foe_tickets[harrier_rank].visible \
					and not bool(watched["displayed"]):
				var projected: Dictionary = screen._foe_intents.get(harrier_rank, {})
				if str(projected.get("ability_id", "")) == HOOK_DRAG:
					watched["displayed"] = true
					_check(projected == StitchedFoeIntent.choose(screen.battle, harrier),
						"AC2: the live rank plate displays the authoritative Hook Drag projection")
					_check(int(projected.get("target_rank", 0)) == 4
						and projected.get("affected_ranks") == [4],
						"AC2: the live plate advertises the far rank 4, not the old front rank")
			_check(bool(screen.submit_pass().get("ok", false)),
				"real player Pass drives the mounted automatic foe driver")
			_verify_live_cast(screen, watched)
			if bool(watched["cast"]) and bool(watched["displayed"]):
				break
		screen.free()
		await process_frame
	_check(bool(watched["displayed"]),
		"nonvacuous: the mounted live screen really shows a rank-4 Hook Drag plate")
	_check(bool(watched["cast"]),
		"AC2: the real live battle driver commits the canonical Hook Drag")
