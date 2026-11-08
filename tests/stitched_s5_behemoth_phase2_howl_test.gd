extends SceneTree
## Canonical second-phase Patchwork Behemoth Rage Howl through the real enemy catalog, a seeded
## four-doll StitchedRules battle, StitchedFoeIntent and the public foe action receipts.
##
## Rage Howl is a battle-wide roar: one authored multi-target debuff that hit-checks every living
## reachable doll rank independently, applies Weak 2 only on a confirmed hit and never deals
## direct HP damage. Every witness comes from authentic seeded turns (pass_turn,
## use_foe_ability), never from a fabricated status call or an unseeded roll.

const BOSS := "patchwork_behemoth"
const BOSS_PATH := "res://data/enemies/boss.json"
const PHASE_TWO_PATH := "res://data/enemies/m05_behemoth_phase_two.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"

const HOWL := {
	"id": "behemoth_phase2_rage_howl", "name": "Rage Howl", "kind": "debuff",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"weak": 2},
	"self_move": 0, "move": "skill",
}
const GUT_ROPE := {
	"id": "behemoth_phase2_gut_rope", "name": "Gut-Rope Slam", "kind": "melee",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 82, "dmg": [14, 20], "crit": 0, "effects": {"fray": 4},
	"self_move": 0, "move": "attack2",
}
const STUFFING_STORM := {
	"id": "behemoth_phase2_stuffing_storm", "name": "Stuffing Storm", "kind": "ranged",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 78, "dmg": [4, 6], "crit": 0, "effects": {}, "self_move": 0, "move": "attack3",
}
const CRUSHING_LASH := {
	"id": "behemoth_phase2_crushing_lash", "name": "Crushing Lash", "kind": "melee",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 82, "dmg": [10, 16], "crit": 0, "effects": {"tangled": 1},
	"self_move": 0, "move": "attack4",
}
const PHASE_TWO_LEGACY := {
	"target": "lowest_living_hp",
	"actions": [
		{"type": "attack", "amount": 40, "weight": 4},
		{"type": "block", "amount": 3, "weight": 2},
		{"type": "debuff", "amount": 1, "status": "weak", "weight": 1},
		{"type": "attack", "amount": 36, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 28, "hits": 2, "move": "attack3", "weight": 1},
		{"type": "attack", "amount": 44, "move": "attack4", "weight": 1},
	],
}
const PHASE_ONE_IDS := ["behemoth_maul", "stuffing_hurl", "rope_lash", "stitch_ward"]
const HOWL_ID := "behemoth_phase2_rage_howl"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the canonical enemy catalog loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		_finish()
		return
	_test_authored(catalog)
	var witnesses := {"hit": 0, "miss": 0, "mixed": 0}
	for seed_value in range(1, 33):
		var first := _howl_script(catalog, seed_value, [], witnesses)
		var replay := _howl_script(catalog, seed_value, [], {})
		_check(not first.is_empty() and first == replay,
			"AC4: equal-seed Rage Howl scripts replay receipts, statuses, state and RNG")
	for key in witnesses:
		_check(int(witnesses[key]) > 0, "AC2: non-vacuous seeded witness: " + str(key))
	_test_lost_doll(catalog)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_behemoth_phase2_howl_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


## JSON numbers arrive as floats, so compare a Weak amount by value rather than by dictionary
## literal type.
func _weak_of(effects: Variant) -> int:
	if not effects is Dictionary:
		return 0
	return int((effects as Dictionary).get("weak", 0))


func _witness(witnesses: Dictionary, key: String) -> void:
	if not witnesses.is_empty():
		witnesses[key] = int(witnesses.get(key, 0)) + 1


# ---------------------------------------------------------------- AC1 authored contract

func _test_authored(catalog: Dictionary) -> void:
	var phase: Variant = JSON.parse_string(FileAccess.get_file_as_string(PHASE_TWO_PATH))
	_check(phase is Dictionary, "AC1: the shipped phase-two record still parses")
	if not phase is Dictionary:
		return
	_check(phase.get("boss_id") == BOSS and int(phase.get("phase", 0)) == 2
		and int(phase.get("threshold_hp", 0)) == 21,
		"AC1: phase two keeps its boss id, phase 2 and the exact 21 HP threshold")
	_check(phase.get("intent") == _json(PHASE_TWO_LEGACY),
		"AC1: the phase-two legacy intent actions are unchanged")
	var abilities: Array = phase.get("stitched_phase_two", {}).get("abilities", [])
	_check(abilities.size() == 4, "AC1: the phase-two kit keeps exactly its four authored moves")
	if abilities.size() == 4:
		_check(abilities[0] == _json(GUT_ROPE), "AC1: Gut-Rope Slam is unchanged")
		_check(abilities[1] == _json(HOWL),
			"AC1: Rage Howl is exactly the authored record with multi true")
		_check(abilities[2] == _json(STUFFING_STORM), "AC1: Stuffing Storm is unchanged")
		_check(abilities[3] == _json(CRUSHING_LASH), "AC1: Crushing Lash is unchanged")
		var expected: Dictionary = _json(HOWL)
		var howl: Dictionary = abilities[1]
		for key in ["id", "name", "kind", "launch", "target", "target_side", "acc", "dmg",
				"crit", "self_move", "move"]:
			_check(howl.get(key) == expected[key],
				"AC1: Rage Howl keeps its authored " + str(key))
		var effects: Dictionary = howl.get("effects", {})
		_check(howl.get("multi") == true and effects.size() == 1
			and int(effects.get("weak", 0)) == 2,
			"AC1: only the old multi false becomes true, with Weak 2 intact")
	var loaded := StitchedEnemyCatalog.foe_for(catalog, BOSS, StitchedEnemyCatalog.PHASE_TWO)
	_check(not loaded.is_empty(), "AC1: the loader publishes the phase-two Behemoth")
	var kit: Array = loaded.get("abilities", [])
	_check(kit.size() == 4, "AC1: the loaded phase-two kit keeps its four moves")
	if kit.size() == 4:
		var normalized: Array = []
		for source in [GUT_ROPE, HOWL, STUFFING_STORM, CRUSHING_LASH]:
			var validated := StitchedParts.validate_ability(source)
			_check(bool(validated.get("ok", false)),
				"AC1: the independent expected phase-two ability validates")
			if bool(validated.get("ok", false)):
				normalized.append(validated["ability"])
		_check(kit == normalized,
			"AC1: the loader exposes the exact phase-two kit including multi Rage Howl")
		var kit_effects: Dictionary = kit[1].get("effects", {})
		_check(kit[1].get("id") == HOWL_ID and kit[1].get("multi") == true
			and kit[1].get("target") == [1, 2, 3, 4] and kit_effects.size() == 1
			and int(kit_effects.get("weak", 0)) == 2
			and int(kit[1].get("acc", 0)) == 90 and kit[1].get("dmg") == [0, 0]
			and int(kit[1].get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4])
			and int(kit[1].get("launch_mask", 0)) == StitchedParts.rank_mask([1, 4]),
			"AC1: the loaded Rage Howl reaches all four ranks from its shipped launch ranks")
	_check(int(catalog.get("phase_two", {}).get(BOSS, {}).get("threshold_hp", 0)) == 21,
		"AC1: the loader still publishes the 21 HP phase-two threshold")
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSS_PATH))
	_check(records is Array, "AC1: the real boss catalog parses")
	if not records is Array:
		return
	var matches: Array = (records as Array).filter(
		func(record: Dictionary) -> bool: return record.get("id") == BOSS)
	_check(matches.size() == 1, "AC1: exactly one Patchwork Behemoth record")
	if matches.size() != 1:
		return
	var boss: Dictionary = matches[0]
	_check(boss.get("name") == "Patchwork Behemoth" and int(boss.get("max_hp", 0)) == 84
		and boss.get("art_path") == "res://assets/paper/enemies/patchwork_behemoth.png",
		"AC1: the untouched name, legacy HP and sprite path stay exact")
	var phase_one_ids: Array = []
	for ability in boss.get("stitched", {}).get("abilities", []):
		phase_one_ids.append(str(ability.get("id", "")))
	_check(phase_one_ids == PHASE_ONE_IDS,
		"AC1: the first-phase Behemoth kit stays untouched")
	_check(bool(loaded.get("is_boss", false)) and int(loaded.get("turns_per_round", 0)) == 2,
		"AC1: the phase-two Behemoth keeps its boss identity and two turns")


# ---------------------------------------------------------------- seeded battle helpers

func _battle(catalog: Dictionary, seed_value: int, ids: Array = [BOSS, "ragling"],
		lost_ranks: Array = []) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	_check(preview is Dictionary, "AC2: the shipped four-doll preview exists")
	if not preview is Dictionary:
		return null
	var config: Dictionary = preview
	var parts: Array = config["parts"].duplicate(true)
	parts.append_array(catalog["parts"].duplicate(true))
	var opponents: Array = []
	for enemy_id in ids:
		var phase := StitchedEnemyCatalog.PHASE_TWO if str(enemy_id) == BOSS \
			else StitchedEnemyCatalog.PHASE_ONE
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id), phase)
		_check(not foe.is_empty(), "AC1: the canonical foe exists: " + str(enemy_id))
		opponents.append(foe)
	for rank in lost_ranks:
		# The carried-run schema represents a genuinely absent doll with no ghost equipment.
		config["heroes"][int(rank) - 1].merge({"hp": 0, "lost": true, "parts": {}}, true)
	var created := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": config["heroes"].duplicate(true), "parts": parts, "foes": opponents,
	})
	_check(bool(created.get("ok", false)),
		"AC2: the real seeded battle builds: " + str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size(),
		"AC2: four dolls face two or three canonical foes")
	_check(battle.turn_order().count(BOSS) == 2,
		"AC2: the Behemoth still takes exactly two turns per round")
	var boss := battle.get_unit(BOSS)
	var boss_kit: Array = boss.get("abilities", [])
	_check(boss_kit.size() == 4 and str(boss_kit[1].get("id", "")) == HOWL_ID
		and boss_kit[1].get("multi") == true,
		"AC2: the battle really carries the authored phase-two Rage Howl")
	return battle


## Passes authentic turns until the Behemoth owns a legal Rage Howl turn. A Howl probe on every
## other turn proves wrong-side/wrong-foe refusals spend no state, turn or RNG.
func _reach_howl(b: StitchedRules, receipts: Array) -> bool:
	for step in range(96):
		if b.is_over():
			break
		if b.current_actor_id() == BOSS and b.round_number() >= 2:
			var intent := StitchedFoeIntent.choose(b, b.get_unit(BOSS))
			if str(intent.get("ability_id", "")) == HOWL_ID:
				return true
		if b.current_actor_id() != BOSS:
			var snapshot := b.state_snapshot()
			var rng := b.rng_state()
			var rejected := b.use_foe_ability(HOWL_ID, 1)
			var expected := "it is not a foe turn" if b.current_side() == "hero" \
				else "the foe has no ability " + HOWL_ID
			_check(not bool(rejected.get("ok", true)) and rejected.get("error") == expected
				and snapshot == b.state_snapshot() and rng == b.rng_state(),
				"AC3: a wrong-turn Rage Howl is refused without state/turn/RNG change")
			receipts.append(rejected)
		var passed := b.pass_turn()
		_check(bool(passed.get("ok", false)), "AC2: a legal pass advances the authentic turn")
		if not bool(passed.get("ok", false)):
			return false
		receipts.append(passed)
	_check(false, "AC2: reaches a legal Rage Howl turn in round two")
	return false


func _refuse(b: StitchedRules, ability_id: String, rank: int, error: String) -> Dictionary:
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var receipt := b.use_foe_ability(ability_id, rank)
	_check(not bool(receipt.get("ok", true)) and receipt.get("error") == error
		and snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC3: %s at rank %d is refused without state/turn/RNG change" % [ability_id, rank])
	return receipt


## Adversarial precondition only: the real two-foe fixture keeps the Behemoth in its legal front
## rank, and nothing in this script moves a foe. Rank 3 lies outside Rage Howl's shipped launch
## array [1, 4], so the impossible launch is probed by relocating the real boss, then restoring it
## exactly.
func _illegal_launch_probe(b: StitchedRules, ability_id: String) -> Dictionary:
	var saved: Dictionary = b._units[BOSS].duplicate(true)
	var restored := b.state_snapshot()
	b._units[BOSS]["rank"] = 3
	var mutated := b.state_snapshot()
	var rng := b.rng_state()
	var rejected := b.use_foe_ability(ability_id, 1)
	_check(not bool(rejected.get("ok", true))
		and rejected.get("error") == "ability cannot launch from rank 3",
		"AC3: an impossible Rage Howl launch rank is refused")
	_check(mutated == b.state_snapshot() and rng == b.rng_state(),
		"AC3: the illegal launch leaves turn, units and RNG unchanged")
	b._units[BOSS] = saved
	_check(restored == b.state_snapshot(),
		"AC3: restoring the real rank leaves the battle untouched")
	return rejected


# ---------------------------------------------------------------- AC2 the live Howl action

func _howl_script(catalog: Dictionary, seed_value: int, lost_ranks: Array,
		witnesses: Dictionary) -> Dictionary:
	var b := _battle(catalog, seed_value, [BOSS, "ragling"], lost_ranks)
	if b == null:
		return {}
	var receipts: Array = []
	if not _reach_howl(b, receipts):
		return {}
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var intent := StitchedFoeIntent.choose(b, b.get_unit(BOSS))
	_check(snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC2: reading the live Rage Howl intent changes no state or RNG")
	var expected_ranks: Array = [1, 2, 3, 4]
	for rank in lost_ranks:
		expected_ranks.erase(int(rank))
	_check(intent.get("ability_id") == HOWL_ID and intent.get("ability_name") == "Rage Howl"
		and intent.get("ability_kind") == "debuff" and intent.get("multi") == true
		and intent.get("affected_ranks") == expected_ranks
		and intent.get("target_side") == "hero"
		and int(intent.get("base_acc", 0)) == 90 and intent.get("base_damage") == [0, 0]
		and int(intent.get("base_crit", -1)) == 0 and _weak_of(intent.get("base_effects", {})) == 2
		and not bool(intent.get("pass", true)),
		"AC2: the live phase-two intent announces Rage Howl on the whole doll line")
	# The authored target mask is all four ranks, so only an out-of-range rank is illegal.
	for rank in [0, 5]:
		receipts.append(_refuse(b, HOWL_ID, rank, "no legal target in rank %d" % rank))
	receipts.append(_illegal_launch_probe(b, HOWL_ID))
	var before := b.get_heroes().duplicate(true)
	var actor := b.get_unit(BOSS)
	var turn := int(b.state_snapshot()["turn_index"])
	var round_before := b.round_number()
	_check(int(actor.get("miss_streak", 0)) == 0,
		"AC2: the real Howl turn starts with no carried miss streak")
	var receipt := b.use_foe_ability(str(intent.get("ability_id", "")),
		int(intent.get("target_rank", 0)))
	receipts.append(receipt)
	_check(bool(receipt.get("ok", false)) and receipt.get("actor") == BOSS
		and receipt.get("ability") == HOWL_ID,
		"AC2: one public Rage Howl action resolves on the real Behemoth turn")
	if not bool(receipt.get("ok", false)):
		return {}
	var results: Array = receipt.get("results", [])
	_check(results.size() == expected_ranks.size(),
		"AC2: one genuine target result per present doll, no more")
	var after_state := b.state_snapshot()
	_check(int(after_state["turn_index"]) == turn + 1
		or int(after_state["round"]) == round_before + 1,
		"AC2: the Howl spends exactly one of the Behemoth's two turns")
	var foe_acc := int(b.candle_band()["enemy_acc"])
	var chance_base := 90 + int(actor["acc"]) + foe_acc
	var streak := 0
	var ranks: Array = []
	var hits := 0
	var misses := 0
	var current_after := b.current_actor_id()
	for result in results:
		var rank := int(result["target_rank"])
		ranks.append(rank)
		_check(rank >= 1 and rank <= 4 and rank - 1 < before.size(),
			"AC2: each result names a real doll rank")
		if rank < 1 or rank > 4 or rank - 1 >= before.size():
			continue
		var old: Dictionary = before[rank - 1]
		var hero_id := str(old["id"])
		_check(result.get("target") == hero_id and int(old["rank"]) == rank,
			"AC2: each receipt names the doll genuinely sewn into that rank")
		var chance := StitchedRules.hit_chance(chance_base, StitchedRules.effective_dodge(old),
			streak)
		_check(int(result.get("hit_chance", -1)) == chance
			and bool(result.get("hit")) == (int(result.get("roll", 0)) <= chance),
			"AC2: Rage Howl rolls its authored 90 ACC separately per doll rank")
		_check(int(result.get("damage", -1)) == 0
			and int(result.get("target_hp", -1)) == int(old["hp"])
			and not bool(result.get("crit", true)),
			"AC2: a Howl result deals no direct HP damage")
		var live := b.get_unit(hero_id)
		_check(int(live["hp"]) == int(old["hp"]),
			"AC2: the Howl never changes the struck doll's HP")
		if bool(result.get("hit")):
			hits += 1
			_check(result.get("statuses") == [{"status": "weak", "duration": 2}],
				"AC2: a landed Howl applies exactly Weak 2")
			# The next unit's turn entry ticks its own status clocks once, so the just-hit
			# doll shows Weak 1 only when that doll is the newly entered actor.
			var expected_weak := 1 if hero_id == current_after else 2
			_check(int(live["statuses"].get("weak", 0)) == expected_weak,
				"AC2: the live doll carries the Weak 2 from the hit tick")
			_witness(witnesses, "hit")
			streak = 0
		else:
			misses += 1
			_check(result.get("statuses") == []
				and not live["statuses"].has("weak"),
				"AC2: a genuine miss applies no Weak and no status")
			_witness(witnesses, "miss")
			streak += 1
	if hits > 0 and misses > 0:
		_witness(witnesses, "mixed")
	ranks.sort()
	_check(ranks == expected_ranks,
		"AC2: every eligible rank resolves exactly once, never a missing or bonus rank")
	_check(b.get_unit(BOSS).get("miss_streak", 0) == streak,
		"AC2: the Behemoth's miss streak follows the real per-target rolls")
	return {
		"receipts": receipts, "intent": intent, "order": b.turn_order(),
		"heroes": b.get_heroes().duplicate(true), "state": b.state_snapshot(),
		"rng": b.rng_state(),
	}


# ---------------------------------------------------------------- AC3 absent doll eligibility

func _test_lost_doll(catalog: Dictionary) -> void:
	var b := _battle(catalog, 7, [BOSS, "ragling"], [4])
	if b == null:
		return
	var lost := b.get_unit("lantern_monk")
	_check(int(lost.get("hp", -1)) == 0 and bool(lost.get("lost", false))
		and lost.get("parts", {}) == {} and int(lost.get("rank", 0)) == 4,
		"AC3: the fourth doll is genuinely LOST before the Howl")
	var receipts: Array = []
	if not _reach_howl(b, receipts):
		return
	var intent := StitchedFoeIntent.choose(b, b.get_unit(BOSS))
	_check(intent.get("ability_id") == HOWL_ID and intent.get("multi") == true
		and intent.get("affected_ranks") == [1, 2, 3],
		"AC3: the live intent omits the LOST rank and keeps ranks 1-3 eligible")
	receipts.append(_refuse(b, HOWL_ID, 0, "no legal target in rank 0"))
	receipts.append(_illegal_launch_probe(b, HOWL_ID))
	var before := b.get_heroes().duplicate(true)
	var receipt := b.use_foe_ability(str(intent.get("ability_id", "")),
		int(intent.get("target_rank", 0)))
	receipts.append(receipt)
	_check(bool(receipt.get("ok", false)), "AC3: the Howl still resolves for the living line")
	if not bool(receipt.get("ok", false)):
		return
	var results: Array = receipt.get("results", [])
	_check(results.size() == 3, "AC3: no phantom fourth result for the LOST doll")
	var ranks: Array = []
	for result in results:
		ranks.append(int(result["target_rank"]))
		_check(str(result.get("target", "")) != "lantern_monk",
			"AC3: the LOST doll is never named as a Howl target")
	ranks.sort()
	_check(ranks == [1, 2, 3],
		"AC3: the other three legal ranks remain eligible and resolve once each")
	_check(b.get_unit("lantern_monk") == lost,
		"AC3: the LOST doll keeps its absent HP, equipment and statuses")
	for rank in [1, 2, 3]:
		var old: Dictionary = before[rank - 1]
		var live := b.get_unit(str(old["id"]))
		_check(int(live["hp"]) == int(old["hp"]),
			"AC3: the Howl never changes a living doll's HP in the absent-rank fixture")
