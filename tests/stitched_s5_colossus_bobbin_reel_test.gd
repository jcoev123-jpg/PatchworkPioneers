extends SceneTree
## S5 Sewing-Machine Colossus "Bobbin Shot" rear-rank reel.
##
## Canonical boss JSON -> real StitchedEnemyCatalog -> seeded four-doll StitchedRules fight.
## The shared foe driver (StitchedFoeIntent.choose) advertises the deepest legal rank and the
## public StitchedRules.use_foe_ability commits the authored hit, damage, one-rank pull and
## 6 FRAY to the stuck doll. No resolver is reimplemented here and no RNG is stubbed:
## witnesses are found across bounded real seeds.

const BOSS := "sewing_machine_colossus"
const BOBBIN := "colossus_bobbin"
## The authored hook also frays the doll it catches. At the battle's bright candle band the
## core applies the authored 6 without any candle multiplier.
const HOOK_FRAY := 6
const TROPHY := "sewing_machine_colossus_needle_arm"
const PREVIEW := "res://data/stitched/s2_preview.json"
const BOSS_PATH := "res://data/enemies/boss.json"
const RAGLING := "ragling"

const TREADLE := {
	"id": "colossus_treadle", "name": "Treadle Stomp", "kind": "melee", "launch": [1, 3],
	"target": [1, 2], "target_side": "enemy", "multi": false, "acc": 84,
	"dmg": [6, 9], "crit": 0, "effects": {"stun": 1}, "self_move": 0, "move": "attack2",
}
const BOBBIN_ABILITY := {
	"id": "colossus_bobbin", "name": "Bobbin Shot", "kind": "ranged", "launch": [1, 4],
	"target": [3, 4], "target_side": "enemy", "multi": false, "acc": 80,
	"dmg": [4, 6], "crit": 0, "effects": {"pull": 1, "fray": 6}, "self_move": 0, "move": "attack3",
}
const BARRAGE := {
	"id": "colossus_barrage", "name": "Needle Barrage", "kind": "ranged", "launch": [1, 4],
	"target": [1, 2, 3], "target_side": "enemy", "multi": true, "acc": 80,
	"dmg": [2, 3], "crit": 0, "effects": {"bleed": 1}, "self_move": 0, "move": "attack4",
}
const GUARD := {
	"id": "colossus_guard", "name": "Iron Tread", "kind": "buff", "launch": [1, 3],
	"target": [1], "target_side": "self", "multi": false, "acc": 100,
	"dmg": [0, 0], "crit": 0, "effects": {"thorns": 4}, "self_move": 0, "move": "guard",
}
const LEGACY := {"target": "front", "actions": [
	{"type": "attack", "amount": 6, "hits": 2, "weight": 4},
	{"type": "block", "amount": 5, "weight": 2},
	{"type": "debuff", "amount": 1, "status": "weak", "weight": 1},
	{"type": "attack", "amount": 9, "move": "attack2", "weight": 1},
	{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
	{"type": "attack", "amount": 10, "move": "attack4", "weight": 1},
]}

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary


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
		var witnesses := _test_landed_and_miss()
		_test_blocked_pull(int(witnesses.get("hit_seed", -1)))
		_test_turn_refusal()
		_test_refusals()
		_test_replay()
		await _test_live_driver()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_colossus_bobbin_reel_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- AC1 authored record

func _test_authored() -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSS_PATH))
	_check(records is Array, "real boss JSON parses")
	if not records is Array:
		return
	var boss: Dictionary = {}
	for record in records:
		if record is Dictionary and str(record.get("id", "")) == BOSS:
			boss = record
	_check(not boss.is_empty(), "exactly one named Sewing-Machine Colossus")
	if boss.is_empty():
		return
	_check(boss.get("name") == "Sewing-Machine Colossus" and int(boss.get("max_hp", 0)) == 96
		and boss.get("art_path") == "res://assets/paper/enemies/sewing_machine_colossus.png"
		and boss.get("intent") == JSON.parse_string(JSON.stringify(LEGACY)),
		"AC1: legacy identity, art path, HP and card intent stay byte-identical")
	var expected := {"max_hp": 96, "speed": 4, "dodge": 3, "acc": 0, "prot": 14,
		"is_boss": true, "turns_per_round": 2, "trophy": TROPHY,
		"abilities": [TREADLE, BOBBIN_ABILITY, BARRAGE, GUARD]}
	_check(boss.get("stitched") == JSON.parse_string(JSON.stringify(expected)),
		"AC1: exact kit and order; only Bobbin's target ranks and pull effect changed")
	var foe := StitchedEnemyCatalog.foe_for(catalog, BOSS)
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, BOSS) == TROPHY,
		"AC1: the canonical foe and unchanged trophy load")
	if foe.is_empty():
		return
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected[key], "AC1: loaded stat stays exact: " + key)
	var normalized: Array = []
	for ability in [TREADLE, BOBBIN_ABILITY, BARRAGE, GUARD]:
		var validated := StitchedParts.validate_ability(ability)
		_check(bool(validated.get("ok", false)),
			"AC1: " + str(ability["id"]) + " validates through the real parts rules")
		if bool(validated.get("ok", false)):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized,
		"AC1: the loader exposes the exact normalized Colossus kit in order")
	var abilities: Array = foe.get("abilities", [])
	if abilities.size() != 4:
		_check(false, "AC1: the Colossus still authors exactly four abilities")
		return
	var bobbin: Dictionary = abilities[1]
	_check(bobbin.get("id") == BOBBIN and bobbin.get("name") == "Bobbin Shot"
		and bobbin.get("kind") == "ranged" and bobbin.get("launch") == [1, 4]
		and bobbin.get("target") == [3, 4] and bobbin.get("target_side") == "enemy"
		and not bool(bobbin.get("multi", true)) and int(bobbin.get("acc", 0)) == 80
		and bobbin.get("dmg") == [4, 6] and int(bobbin.get("crit", -1)) == 0
		and bobbin.get("effects") == {"pull": 1, "fray": 6}
		and int(bobbin.get("self_move", -1)) == 0
		and bobbin.get("move") == "attack3",
		"AC1: Bobbin Shot is the authored rear-rank hook (ranged 1/4 -> 3/4, 4-6, ACC 80, pull 1 + fray 6, attack3)")
	_check(int(bobbin.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 4])
		and int(bobbin.get("target_mask", 0)) == StitchedParts.rank_mask([3, 4])
		and not StitchedParts.ranks_allowed(int(bobbin.get("target_mask", 0)), 1)
		and not StitchedParts.ranks_allowed(int(bobbin.get("target_mask", 0)), 2),
		"AC1: normalized launch/target masks are the authored ranks, so heads are out of range")
	var other_ids: Array = [str(abilities[0]["id"]), str(abilities[2]["id"]), str(abilities[3]["id"])]
	_check(other_ids == ["colossus_treadle", "colossus_barrage", "colossus_guard"]
		and not abilities[0].get("effects", {}).has("pull")
		and not abilities[2].get("effects", {}).has("pull")
		and not abilities[3].get("effects", {}).has("pull"),
		"AC1: every other Colossus ability keeps its authored place and gains no pull")
	_check(abilities[0]["effects"] == {"stun": 1} and abilities[2]["effects"] == {"bleed": 1}
		and abilities[3]["effects"] == {"thorns": 4},
		"AC1: Treadle Stun 1, Barrage Bleed 1 and Iron Tread Thorns 4 are untouched")
	# The hook keeps using the machine's existing authored art and attack3 pose.
	var poses: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/move_poses.json"))
	var boss_poses: Dictionary = poses.get("enemies", {}).get(BOSS, {}) if poses is Dictionary else {}
	_check(boss_poses.has("attack3")
		and boss_poses["attack3"].get("name") == "Bobbin Shot"
		and str(boss_poses["attack3"].get("art", "")).begins_with("res://assets/paper/"),
		"AC1: Bobbin Shot reuses the authored attack3 paper-puppet pose, never a code-drawn visual")


# ---------------------------------------------------------------- live battle helpers

func _config(seed_value: int) -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"].duplicate(true))
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(catalog, BOSS),
		StitchedEnemyCatalog.foe_for(catalog, RAGLING),
	]
	return config


func _battle(seed_value: int) -> StitchedRules:
	var built := StitchedRules.create(_config(seed_value))
	_check(bool(built.get("ok", false)),
		"seed %d builds a real four-doll boss battle: %s" % [seed_value, str(built.get("error", ""))])
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 2
		and battle.turn_order().count(BOSS) == 2,
		"seed %d: four dolls face the Colossus, which still takes two turns per round" % seed_value)
	return battle


func _reach(battle: StitchedRules, actor: String, minimum_round: int) -> bool:
	for step in range(120):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor and battle.round_number() >= minimum_round:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


## A real battle parked on the Colossus's own round-two turn, whose untouched rotation and
## legal target mask advertise Bobbin Shot at the occupied rank 4. The Colossus's first
## round-two slot (its third overall activation) now overheats into a Pass, so the fixture
## advances to the second slot, and skips seeds where that slot ends the round so the
## round-two timing assertions below stay exact.
func _bobbin_ready(seed_value: int) -> StitchedRules:
	var battle := _battle(seed_value)
	if battle == null:
		return null
	for step in range(120):
		if battle.is_over():
			return null
		if battle.current_actor_id() == BOSS and battle.round_number() >= 2:
			var choice := StitchedFoeIntent.choose(battle, battle.get_unit(BOSS))
			if str(choice.get("ability_id", "")) == BOBBIN and int(choice.get("target_rank", 0)) == 4:
				if int(battle.state_snapshot()["turn_index"]) >= battle.turn_order().size() - 1:
					return null
				return battle
		if not bool(battle.pass_turn().get("ok", false)):
			return null
	return null


func _ranks(battle: StitchedRules) -> Dictionary:
	var ranks: Dictionary = {}
	for hero in battle.get_heroes():
		ranks[str(hero["id"])] = int(hero["rank"])
	return ranks


func _hero_at_rank(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _sorted_ranks(battle: StitchedRules) -> Array:
	var ranks: Array = []
	for hero in battle.get_heroes():
		ranks.append(int(hero["rank"]))
	ranks.sort()
	return ranks


## Every present doll's current hidden FRAY, by identity. FRAY is the mental pressure track
## the hook now feeds; it is never a visible panel.
func _fray_map(battle: StitchedRules) -> Dictionary:
	var frays: Dictionary = {}
	for hero in battle.get_heroes():
		frays[str(hero["id"])] = int(hero["fray"])
	return frays


## True when every doll except `except_id` still carries exactly the FRAY it had in `before`.
func _only_one_frayed(battle: StitchedRules, before: Dictionary, except_id: String) -> bool:
	for hero in battle.get_heroes():
		var hero_id := str(hero["id"])
		if hero_id == except_id:
			continue
		if not before.has(hero_id) or int(hero["fray"]) != int(before[hero_id]):
			return false
	return true


func _refuse(battle: StitchedRules, rank: int, error: String) -> Dictionary:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipt := battle.use_foe_ability(BOBBIN, rank)
	_check(not bool(receipt.get("ok", true)) and str(receipt.get("error", "")) == error
		and before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: refused rank %d keeps HP/ranks/statuses/turn order/RNG: %s" % [rank, error])
	return receipt


func _damage_candidates(actor: Dictionary, target: Dictionary, battle: StitchedRules,
		crit: bool) -> Array:
	var bases: Array = [StitchedRules.crit_damage(6)] if crit else [4, 5, 6]
	var candidates: Array = []
	for base in bases:
		var scaled := StitchedS1BEffects.enemy_damage(base + int(actor.get("dmg_bonus", 0)),
			battle.candle())
		candidates.append(StitchedRules.damage_after_modifiers(scaled, actor["statuses"],
			target["statuses"], false, 0, int(target.get("prot", 0))))
	return candidates


# ---------------------------------------------------------------- AC2/A3 landed, missed

func _test_landed_and_miss() -> Dictionary:
	var hit_seed := -1
	var miss_seed := -1
	var intent_seen := false
	for seed_value in range(1, 97):
		var battle := _bobbin_ready(seed_value)
		if battle == null:
			continue
		var back_id := _hero_at_rank(battle, 4)
		var front_id := _hero_at_rank(battle, 3)
		if back_id.is_empty() or front_id.is_empty():
			continue
		var actor := battle.get_unit(BOSS)
		var before_back := battle.get_unit(back_id)
		var before_front := battle.get_unit(front_id)
		var before_ranks := _ranks(battle)
		var state := battle.state_snapshot()
		var rng := battle.rng_state()
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BOSS))
		var ability: Dictionary = {}
		for authored in actor.get("abilities", []):
			if str(authored["id"]) == BOBBIN:
				ability = authored
		var ranks3: Array = []
		var ranks4: Array = []
		if not ability.is_empty():
			ranks3 = battle._legal_targets(actor, ability, 3)
			ranks4 = battle._legal_targets(actor, ability, 4)
		if not intent_seen:
			intent_seen = true
			_check(battle.round_number() == 2 and battle.current_actor_id() == BOSS
				and battle.current_side() == "foe",
				"AC2: the real round-two Colossus owning the turn advertises its intent")
			_check(not intent.get("pass", true) and not intent.get("stun", false)
				and str(intent.get("foe_id", "")) == BOSS
				and str(intent.get("ability_id", "")) == BOBBIN
				and str(intent.get("ability_name", "")) == "Bobbin Shot"
				and str(intent.get("ability_kind", "")) == "ranged"
				and str(intent.get("target_side", "")) == "hero"
				and int(intent.get("target_rank", 0)) == 4
				and intent.get("affected_ranks") == [4]
				and not bool(intent.get("multi", true))
				and int(intent.get("base_acc", -1)) == 80
				and intent.get("base_damage") == [4, 6]
				and int(intent.get("base_crit", -1)) == 0
				and intent.get("base_effects") == {"pull": 1, "fray": 6},
				"AC2: the chooser projects Bobbin Shot onto the occupied legal rank 4 with authored numbers")
			_check(ranks3.size() == 1 and str(ranks3[0]["id"]) == front_id
				and ranks4.size() == 1 and str(ranks4[0]["id"]) == back_id
				and battle._legal_targets(actor, ability, 1).is_empty()
				and battle._legal_targets(actor, ability, 2).is_empty(),
				"AC2: only occupied ranks 3 and 4 are legal Bobbin targets; heads 1 and 2 are not")
			_check(state == battle.state_snapshot() and rng == battle.rng_state(),
				"AC2: projecting the advertised intent mutates nothing and spends no RNG")
			if not intent.is_empty() and intent.get("base_effects", {}).has("pull"):
				intent["base_effects"]["pull"] = 2
				intent["base_effects"]["fray"] = 99
				var again := StitchedFoeIntent.choose(battle, battle.get_unit(BOSS))
				_check(again.get("base_effects") == {"pull": 1, "fray": 6},
					"AC2: projected effects are detached from the canonical ability catalog")
		if hit_seed < 0:
			var before_fray := _fray_map(battle)
			var receipt := battle.use_foe_ability(BOBBIN, 4)
			var results: Array = receipt.get("results", [])
			if bool(receipt.get("ok", false)) and results.size() == 1:
				var result: Dictionary = results[0]
				var chance := StitchedRules.hit_chance(
					80 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"]),
					StitchedRules.effective_dodge(before_back), int(actor["miss_streak"]))
				_check(str(receipt.get("actor", "")) == BOSS and str(receipt.get("ability", "")) == BOBBIN,
					"AC2: the committed action is the Colossus's own Bobbin Shot")
				_check(str(result.get("target", "")) == back_id and int(result.get("target_rank", 0)) == 4,
					"AC2: the advertised rank-4 doll is the one the hook strikes")
				_check(int(result.get("hit_chance", -1)) == chance
					and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
					"AC2: the hit is a genuine seeded ACC roll, never a forced outcome")
				if bool(result.get("hit", false)):
					hit_seed = seed_value
					var candidates := _damage_candidates(actor, before_back, battle,
						bool(result.get("crit", false)))
					_check(candidates.has(int(result.get("damage", -1)))
						and int(result.get("damage", 0)) > 0
						and int(result.get("target_hp", -1))
							== int(before_back["hp"]) - int(result["damage"]),
						"AC2: a landed hook rolls authored 4-6/crit damage through candle, Weak/Exposed and PROT")
					_check(result.get("statuses", []) == [],
						"AC2: the hook applies its pull as movement, not an invented status")
					_check(result.get("shift") == {"ok": true, "from": 4, "to": 3,
						"swapped": front_id},
						"AC2: a landed hook reports exactly one forward rank step and the swapped doll")
					# The bright candle band the fixture sets carries no FRAY multiplier, so
					# the authored 6 arrives whole on the doll the hook actually caught.
					var started := int(before_fray.get(back_id, -1))
					var expected_fray := started + HOOK_FRAY
					var fray_event: Dictionary = result.get("fray_event", {})
					_check(str(battle.candle_band().get("name", "")) == "bright"
						and started < StitchedRules.FRAY_MAX - HOOK_FRAY
						and bool(fray_event.get("ok", false))
						and str(fray_event.get("actor", "")) == back_id
						and int(fray_event.get("before", -1)) == started
						and int(fray_event.get("change", 0)) == HOOK_FRAY
						and int(fray_event.get("after", -1)) == expected_fray
						and str(fray_event.get("transition", "x")).is_empty()
						and int(battle.get_unit(back_id)["fray"]) == expected_fray,
						"AC2: the landed hook frays the stuck doll by exactly 6 below the cap")
					_check(_only_one_frayed(battle, before_fray, back_id),
						"AC2: every other doll's FRAY stays exactly as it was")
					var expected_back := before_back.duplicate(true)
					expected_back["rank"] = 3
					expected_back["hp"] = int(before_back["hp"]) - int(result["damage"])
					expected_back["fray"] = expected_fray
					var expected_front := before_front.duplicate(true)
					expected_front["rank"] = 4
					_check(battle.get_unit(back_id) == expected_back,
						"AC2: the reeled rank-4 doll keeps identity and arrives at rank 3 with that HP and FRAY")
					_check(battle.get_unit(front_id) == expected_front,
						"AC2: the former rank-3 doll swaps to rank 4 with every other field kept")
					var after_ranks := _ranks(battle)
					_check(after_ranks[back_id] == 3 and after_ranks[front_id] == 4
						and _sorted_ranks(battle) == [1, 2, 3, 4],
						"AC2: all four dolls still occupy unique ranks 1-4 after the reel")
					for hero in battle.get_heroes():
						var hero_id := str(hero["id"])
						if hero_id == back_id or hero_id == front_id:
							continue
						_check(int(hero["rank"]) == int(before_ranks[hero_id]),
							"AC2: the reel moves no third doll")
					_check(battle.round_number() == 2
						and int(battle.state_snapshot()["turn_index"])
							== int(state["turn_index"]) + 1,
						"AC2: the hook spends exactly one of the boss's two round-two turns")
		if miss_seed < 0:
			var missed := _bobbin_ready(seed_value)
			if missed == null:
				continue
			var m_back := _hero_at_rank(missed, 4)
			var before_miss := missed.get_unit(m_back)
			var before_miss_fray := _fray_map(missed)
			var miss_ranks := _ranks(missed)
			var miss_rng := missed.rng_state()
			var miss_receipt := missed.use_foe_ability(BOBBIN, 4)
			var miss_results: Array = miss_receipt.get("results", [])
			if bool(miss_receipt.get("ok", false)) and miss_results.size() == 1 \
					and not bool(miss_results[0].get("hit", true)):
				miss_seed = seed_value
				var miss: Dictionary = miss_results[0]
				_check(miss_rng != missed.rng_state(),
					"AC3: a genuine miss still spends exactly its one real hit roll")
				_check(int(miss.get("damage", -1)) == 0 and not miss.has("shift")
					and miss.get("statuses", []).is_empty()
					and int(miss.get("target_hp", -1)) == int(before_miss["hp"]),
					"AC3: a missed Bobbin Shot deals no damage, pull or status")
				_check(not miss.has("fray_event") and _fray_map(missed) == before_miss_fray,
					"AC3: a missed hook frays no doll and leaves every FRAY exactly as it was")
				_check(_ranks(missed) == miss_ranks
					and missed.get_unit(m_back) == before_miss,
					"AC3: a missed hook shifts no doll and leaves every rank and field unchanged")
		if hit_seed > 0 and miss_seed > 0:
			break
	_check(hit_seed > 0 and miss_seed > 0,
		"nonvacuous bounded real-seed Bobbin hit and miss witnesses")
	return {"hit_seed": hit_seed, "miss_seed": miss_seed}


# ---------------------------------------------------------------- AC3 blocked pulls

## A real battle parked on a doll's own decision, where the Colossus must not be able to act.
func _test_turn_refusal() -> void:
	var battle := _battle(19)
	if battle == null:
		_check(false, "AC3: a real battle is required for the out-of-turn refusal")
		return
	var guard := 0
	while battle.current_side() != "hero" and not battle.is_over() and guard < 20:
		if not bool(battle.pass_turn().get("ok", false)):
			break
		guard += 1
	if battle.current_side() != "hero":
		_check(false, "AC3: bounded real turns reach a doll decision for the out-of-turn refusal")
		return
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var fray := _fray_map(battle)
	var receipt := battle.use_foe_ability(BOBBIN, 4)
	_check(not bool(receipt.get("ok", true))
		and str(receipt.get("error", "")) == "it is not a foe turn"
		and before == battle.state_snapshot() and rng == battle.rng_state()
		and _fray_map(battle) == fray,
		"AC3: an out-of-turn Bobbin Shot deals no damage, pull or FRAY and spends no state/RNG")


func _test_blocked_pull(hit_seed: int) -> void:
	if hit_seed <= 0:
		_check(false, "AC3: a genuine landed hook seed is required for the blocked-pull witnesses")
		return
	var variants := [
		["target", "tangled", "tangled units cannot move"],
		["target", "cut", "thread cut blocks movement"],
		["target", "held", "Wren is holding this doll back"],
		["neighbour", "tangled", "a tangled ally cannot be swapped"],
		["neighbour", "cut", "thread cut blocks movement"],
		["neighbour", "held", "Wren is holding that doll back"],
	]
	var witnessed := 0
	for variant in variants:
		var battle := _bobbin_ready(hit_seed)
		if battle == null:
			_check(false, "AC3: the blocked-pull fixture could not rebuild the landed seed")
			return
		var back_id := _hero_at_rank(battle, 4)
		var front_id := _hero_at_rank(battle, 3)
		var subject := back_id if str(variant[0]) == "target" else front_id
		match str(variant[1]):
			"tangled":
				battle._units[subject]["statuses"]["tangled"] = 1
			"cut":
				battle._thread_cuts[subject] = int(battle.get_unit(subject)["rank"])
			"held":
				battle._held[subject] = battle.round_number()
		var before_back := battle.get_unit(back_id)
		var before_ranks := _ranks(battle)
		var before_fray := _fray_map(battle)
		var receipt := battle.use_foe_ability(BOBBIN, 4)
		var results: Array = receipt.get("results", [])
		var label := "%s %s" % [str(variant[0]), str(variant[1])]
		if results.size() != 1:
			_check(false, "AC3: %s blocked-pull witness still resolves one hook result" % label)
			continue
		var result: Dictionary = results[0]
		_check(bool(receipt.get("ok", false)) and bool(result.get("hit", false))
			and int(result.get("roll", 0)) <= int(result.get("hit_chance", 0)),
			"AC3: %s witness still lands a true authored hook hit" % label)
		if not bool(result.get("hit", false)):
			continue
		witnessed += 1
		_check(result.get("shift") == {"ok": false, "reason": str(variant[2])},
			"AC3: %s blocks the reel through the normal movement gate: %s" % [label, str(variant[2])])
		_check(int(result.get("damage", 0)) > 0
			and int(result.get("target_hp", -1))
				== int(before_back["hp"]) - int(result["damage"]),
			"AC3: %s still deals its normal direct damage" % label)
		# A blocked reel never swallows the hit's own legal FRAY consequence: the same
		# public resolver that refused the movement still frays the doll it struck.
		var fray_event: Dictionary = result.get("fray_event", {})
		_check(bool(fray_event.get("ok", false))
			and str(fray_event.get("actor", "")) == back_id
			and int(fray_event.get("before", -1)) == int(before_fray.get(back_id, -2))
			and int(fray_event.get("change", 0)) == HOOK_FRAY
			and int(fray_event.get("after", -1))
				== int(before_fray.get(back_id, -1)) + HOOK_FRAY
			and int(battle.get_unit(back_id)["fray"]) == int(fray_event.get("after", -2))
			and _only_one_frayed(battle, before_fray, back_id),
			"AC3: %s keeps its blocked movement but still frays only the struck doll by 6" % label)
		_check(_ranks(battle) == before_ranks and _sorted_ranks(battle) == [1, 2, 3, 4],
			"AC3: %s never teleports the struck or swapped doll; all four ranks stay intact" % label)
		_check(int(battle.get_unit(back_id)["rank"]) == 4
			and int(battle.get_unit(front_id)["rank"]) == 3,
			"AC3: %s leaves the rear doll at rank 4 and its neighbour at rank 3" % label)
	_check(witnessed == variants.size(),
		"AC3: nonvacuous Tangled, thread-cut and Held blockers on both ends of the swap")


# ---------------------------------------------------------------- AC4 refusals and rank 3

func _test_refusals() -> void:
	var battle := _bobbin_ready(37)
	if battle == null:
		for seed_value in range(1, 97):
			battle = _bobbin_ready(seed_value)
			if battle != null:
				break
	if battle == null:
		_check(false, "AC4: a real Bobbin turn is required for the target-rank refusals")
		return
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	for rank in [0, 1, 2, 5]:
		_refuse(battle, rank, "no legal target in rank %d" % rank)
	_check(battle.current_actor_id() == BOSS and battle.round_number() == 2
		and before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: out-of-range front ranks never spend the Colossus turn, mutate state or advance RNG")
	# Rank 3 is a lawful rear hook: one backward rank step, witnessed on a real landed seed.
	var landed := false
	for seed_value in range(1, 97):
		var rank3 := _bobbin_ready(seed_value)
		if rank3 == null:
			continue
		var target_id := _hero_at_rank(rank3, 3)
		var front_id := _hero_at_rank(rank3, 2)
		var before_target := rank3.get_unit(target_id)
		var before_front := rank3.get_unit(front_id)
		var before_fray := _fray_map(rank3)
		var receipt := rank3.use_foe_ability(BOBBIN, 3)
		var results: Array = receipt.get("results", [])
		_check(bool(receipt.get("ok", false)) and results.size() == 1
			and str(results[0].get("target", "")) == target_id
			and int(results[0].get("target_rank", 0)) == 3,
			"AC4: rank 3 is a legal Bobbin target through the public rules")
		if results.size() != 1 or not bool(results[0].get("hit", false)):
			continue
		landed = true
		_check(results[0].get("shift") == {"ok": true, "from": 3, "to": 2,
			"swapped": front_id},
			"AC4: the landed rank-3 hook takes exactly one backward rank step")
		var expected_fray := int(before_fray.get(target_id, -1)) + HOOK_FRAY
		var expected := before_target.duplicate(true)
		expected["rank"] = 2
		expected["hp"] = int(before_target["hp"]) - int(results[0].get("damage", 0))
		expected["fray"] = expected_fray
		var expected_front := before_front.duplicate(true)
		expected_front["rank"] = 3
		_check(rank3.get_unit(target_id) == expected and rank3.get_unit(front_id) == expected_front
			and _sorted_ranks(rank3) == [1, 2, 3, 4],
			"AC4: rank 3 and rank 2 swap places, the hook frays only its target by 6, and no doll is duplicated or moved twice")
		break
	_check(landed, "AC4: nonvacuous landed rank-3 Bobbin witness with its forward step")


# ---------------------------------------------------------------- AC4 replay + rotation

func _trace(seed_value: int) -> Dictionary:
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	var states: Array = []
	var intents: Dictionary = {}
	var bobbin_done := false
	for step in range(90):
		if battle.is_over() or battle.round_number() > 4:
			break
		var round_value := battle.round_number()
		var actor := battle.current_actor_id()
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var choice := StitchedFoeIntent.choose(battle, battle.get_unit(BOSS))
		_check(before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: projecting the boss intent never mutates state or consumes RNG")
		var receipt: Dictionary
		if actor == BOSS:
			# The boss's global activation ordinal: two real scheduled slots per round,
			# counted through the live initiative order, never the party round alone.
			var slot := 0
			for position in range(int(before["turn_index"]) + 1):
				if str(battle.turn_order()[position]) == BOSS:
					slot += 1
			var ordinal := 2 * (round_value - 1) + slot
			intents[ordinal] = choice
			if ordinal % 3 == 0:
				_check(choice.get("pass", false),
					"AC4: every third activation advertises the Colossus's overheat pass")
				receipt = battle.pass_turn()
			elif str(choice.get("ability_id", "")) == BOBBIN \
					and int(choice.get("target_rank", 0)) == 4 and not bobbin_done:
				bobbin_done = true
				_check(str(choice.get("ability_id", "")) == BOBBIN
					and int(choice.get("target_rank", 0)) == 4,
					"AC4: the hook turn advertises Bobbin Shot at rank 4 before it is committed")
				receipt = battle.use_foe_ability(BOBBIN, 4)
			else:
				receipt = battle.pass_turn()
		else:
			receipt = battle.pass_turn()
		if not bool(receipt.get("ok", false)):
			_check(false, "AC4: replay uses only successful public actions")
			break
		receipts.append(receipt)
		states.append({"state": battle.state_snapshot(), "order": battle.turn_order(),
			"rng": battle.rng_state(), "fray": _fray_map(battle)})
	return {
		"seed": seed_value, "receipts": receipts, "states": states, "intents": intents,
		"state": battle.state_snapshot(), "order": battle.turn_order(), "rng": battle.rng_state(),
		"fray": _fray_map(battle),
	}


func _test_replay() -> void:
	var first := _trace(19)
	var second := _trace(19)
	_check(first.size() > 0 and first == second,
		"AC4: identical seed and decisions replay full receipts, ranks/HP, turn order and RNG")
	if first.is_empty():
		return
	var intents: Dictionary = first["intents"]
	var treadle: Dictionary = intents.get(1, {})
	var overheat_two: Dictionary = intents.get(3, {})
	var bobbin: Dictionary = intents.get(4, {})
	var barrage: Dictionary = intents.get(5, {})
	var overheat_three: Dictionary = intents.get(6, {})
	var guard: Dictionary = intents.get(7, {})
	_check(treadle.get("ability_id") == "colossus_treadle"
		and treadle.get("base_effects") == {"stun": 1},
		"AC4: activation one still advertises Treadle Stomp with Stun 1")
	_check(bobbin.get("ability_id") == BOBBIN
		and int(bobbin.get("target_rank", 0)) == 4,
		"AC4: activation four still advertises Bobbin Shot at rank 4")
	_check(barrage.get("ability_id") == "colossus_barrage"
		and barrage.get("base_effects") == {"bleed": 1}
		and int(barrage.get("target_rank", 0)) == 1,
		"AC4: activation five still advertises Needle Barrage with Bleed 1")
	_check(guard.get("ability_id") == "colossus_guard"
		and guard.get("base_effects") == {"thorns": 4},
		"AC4: activation seven still advertises Iron Tread with Thorns 4")
	_check(overheat_two.get("pass", false) and not overheat_two.get("stun", true)
		and str(overheat_two.get("ability_id", "x")).is_empty(),
		"AC4: activation three overheats into a bare Pass")
	_check(overheat_three.get("pass", false) and not overheat_three.get("stun", true)
		and str(overheat_three.get("ability_id", "x")).is_empty(),
		"AC4: activation six overheats into a bare Pass")
	var committed := 0
	var hook_frayed := 0
	for receipt in first["receipts"]:
		if str(receipt.get("actor", "")) == BOSS and str(receipt.get("action", "")) == "ability":
			committed += 1
			_check(str(receipt.get("ability", "")) == BOBBIN
				and receipt.get("results", []).size() == 1,
				"AC4: the only committed boss action is one single-target Bobbin Shot")
			for result in receipt.get("results", []):
				var event: Dictionary = result.get("fray_event", {})
				if not bool(result.get("hit", false)) or event.is_empty():
					continue
				hook_frayed += 1
				_check(str(event.get("actor", "")) == str(result.get("target", ""))
					and int(event.get("change", 0)) == HOOK_FRAY
					and int(event.get("after", -1)) == int(event.get("before", -2)) + HOOK_FRAY,
					"AC4: a replayed landed hook records the same +6 FRAY receipt")
	_check(committed == 1, "AC4: replay commits exactly one Bobbin Shot, never an extra invented hit")
	_check(int(first["order"].count(BOSS)) == 2,
		"AC4: replayed round keeps the boss's authored two-turn cadence")
	_check(first["fray"] == second["fray"] and first["fray"].size() == 4,
		"AC4: the whole identical-seed replay carries the same per-doll FRAY")
	_check(hook_frayed == 1,
		"AC4: the single committed round-two hook is the replay's one real FRAY source")
	if hook_frayed > 0:
		var frays: Array = first["fray"].values()
		frays.sort()
		_check(int(frays.back()) >= HOOK_FRAY,
			"AC4: the replayed hook leaves real FRAY on the doll it caught")


# ---------------------------------------------------------------- live mounted driver

func _test_live_driver() -> void:
	var screen: StitchedBattleScreen = null
	var witnessed := false
	var displayed := false
	for seed_value in [19, 23, 11, 5, 37]:
		if witnessed:
			break
		screen = StitchedBattleScreen.new()
		_check(screen.begin(_config(seed_value)),
			"live battle screen begins with the canonical Colossus and the real S2 party")
		if screen.battle == null:
			screen.free()
			screen = null
			continue
		root.add_child(screen)
		await process_frame
		for step in range(40):
			if screen.battle.is_over():
				break
			if screen.battle.current_side() != "hero":
				_check(false, "live screen leaves the next decision with the player")
				break
			var boss_rank := int(screen.battle.get_unit(BOSS).get("rank", 0))
			var projected: Dictionary = {}
			if boss_rank > 0 and screen._foe_tickets[boss_rank].visible:
				projected = screen._foe_intents.get(boss_rank, {})
				if str(projected.get("ability_id", "")) == BOBBIN:
					displayed = true
					_check(projected == StitchedFoeIntent.choose(
						screen.battle, screen.battle.get_unit(BOSS)),
						"AC2: the live rank plate displays the authoritative Bobbin projection")
			var before := screen.receipts.size()
			_check(bool(screen.submit_pass().get("ok", false)),
				"real player Pass drives the mounted automatic Colossus driver")
			for index in range(before, screen.receipts.size()):
				var receipt: Dictionary = screen.receipts[index]
				if str(receipt.get("actor", "")) != BOSS \
						or str(receipt.get("action", "")) != "ability":
					continue
				if str(receipt.get("ability", "")) != BOBBIN:
					continue
				var results: Array = receipt.get("results", [])
				if results.size() != 1:
					continue
				var result: Dictionary = results[0]
				_check(int(result.get("target_rank", 0)) == 4,
					"AC2: the live hook commits the farthest legal rank 4")
				if str(projected.get("ability_id", "")) == BOBBIN:
					_check(int(projected.get("target_rank", 0)) == int(result.get("target_rank", 0)),
						"AC2: the committed hook uses the rank its live plate displayed")
				if bool(result.get("hit", false)):
					_check(result.get("shift", {}).get("ok", false)
						and int(result.get("shift", {}).get("from", 0)) == 4
						and int(result.get("shift", {}).get("to", 0)) == 3,
						"AC2: the live landed hook reels rank 4 into rank 3 through the shared rules")
					var live_event: Dictionary = result.get("fray_event", {})
					var caught := str(result.get("target", ""))
					_check(bool(live_event.get("ok", false))
						and int(live_event.get("change", 0)) == HOOK_FRAY
						and int(screen.battle.get_unit(caught).get("fray", -1))
							== int(live_event.get("after", -2)),
						"AC2: the same live commit frays the caught doll by 6 in real play")
					_check(_sorted_ranks(screen.battle) == [1, 2, 3, 4],
						"AC2: live play still leaves four dolls in unique ranks")
				witnessed = true
		screen.free()
		await process_frame
		screen = null
	_check(displayed, "nonvacuous: the mounted live screen really shows a Bobbin Shot plate")
	_check(witnessed, "AC2: the real live battle driver commits the canonical Bobbin Shot")
