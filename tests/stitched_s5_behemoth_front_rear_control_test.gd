extends SceneTree
## Canonical Patchwork Behemoth front/rear control through the real enemy catalog, the seeded
## StitchedRules battle, StitchedFoeIntent and the public turn actions.
##
## Rope Lash sweeps the two front doll ranks with Tangled 2; Stuffing Hurl blinds the two rear
## doll ranks. Every witness comes from authentic seeded turns (pass_turn, use_foe_ability,
## move, use_part), never from a fabricated effect call or an unseeded roll.

const BOSS := "patchwork_behemoth"
const BOSS_PATH := "res://data/enemies/boss.json"
const PHASE_TWO_PATH := "res://data/enemies/m05_behemoth_phase_two.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const TROPHY := "patchwork_behemoth_heart_torso"

const MAUL := {
	"id": "behemoth_maul", "name": "Behemoth Maul", "kind": "melee", "launch": [1, 3],
	"target": [1, 2], "target_side": "enemy", "multi": false, "acc": 85,
	"dmg": [8, 12], "crit": 0, "effects": {}, "self_move": 0, "move": "attack2",
}
const STUFFING_HURL := {
	"id": "stuffing_hurl", "name": "Stuffing Hurl", "kind": "ranged", "launch": [1, 4],
	"target": [3, 4], "target_side": "enemy", "multi": true, "acc": 80,
	"dmg": [5, 8], "crit": 0, "effects": {"blind": 1}, "self_move": 0, "move": "attack3",
}
const ROPE_LASH := {
	"id": "rope_lash", "name": "Rope Lash", "kind": "melee", "launch": [1, 3],
	"target": [1, 2], "target_side": "enemy", "multi": true, "acc": 85,
	"dmg": [6, 9], "crit": 0, "effects": {"tangled": 2}, "self_move": 0, "move": "attack4",
}
const STITCH_WARD := {
	"id": "stitch_ward", "name": "Stitch Ward", "kind": "buff", "launch": [1, 3],
	"target": [1], "target_side": "self", "multi": false, "acc": 100,
	"dmg": [0, 0], "crit": 0, "effects": {"thorns": 3}, "self_move": 0, "move": "guard",
}
const LEGACY_INTENT := {
	"target": "front",
	"actions": [
		{"type": "attack", "amount": 34, "weight": 4},
		{"type": "block", "amount": 3, "weight": 2},
		{"type": "debuff", "amount": 1, "status": "weak", "weight": 1},
		{"type": "attack", "amount": 30, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 22, "hits": 2, "move": "attack3", "weight": 1},
		{"type": "attack", "amount": 38, "move": "attack4", "weight": 1},
	],
}
const PHASE_TWO_ABILITIES := [
	{"id": "behemoth_phase2_gut_rope", "name": "Gut-Rope Slam", "kind": "melee",
		"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
		"acc": 82, "dmg": [14, 20], "crit": 0, "effects": {"fray": 4},
		"self_move": 0, "move": "attack2"},
	{"id": "behemoth_phase2_rage_howl", "name": "Rage Howl", "kind": "debuff",
		"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": false,
		"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"weak": 2},
		"self_move": 0, "move": "skill"},
	{"id": "behemoth_phase2_stuffing_storm", "name": "Stuffing Storm", "kind": "ranged",
		"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
		"acc": 78, "dmg": [4, 6], "crit": 0, "effects": {}, "self_move": 0, "move": "attack3"},
	{"id": "behemoth_phase2_crushing_lash", "name": "Crushing Lash", "kind": "melee",
		"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
		"acc": 82, "dmg": [10, 16], "crit": 0, "effects": {"tangled": 1},
		"self_move": 0, "move": "attack4"},
]
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

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the canonical enemy catalog loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		_finish()
		return
	_test_source(catalog)
	var witnesses := {
		"rope_hit_rank1": 0, "rope_hit_rank2": 0, "rope_miss": 0,
		"rope_tangled_refusal": 0, "rope_tangled_expired": 0,
		"stuffing_hit": 0, "stuffing_miss": 0,
		"blind_forced_miss": 0, "attack_after_blind": 0,
	}
	for seed_value in range(1, 25):
		var rope := _rope_trace(catalog, seed_value, witnesses)
		_check(not rope.is_empty() and rope == _rope_trace(catalog, seed_value, {}),
			"AC5: equal-seed Rope Lash scripts replay receipts, units, order and RNG")
		var hurl := _stuffing_trace(catalog, seed_value, witnesses)
		_check(not hurl.is_empty() and hurl == _stuffing_trace(catalog, seed_value, {}),
			"AC5: equal-seed Stuffing Hurl scripts replay receipts, units, order and RNG")
	for key in witnesses:
		_check(int(witnesses[key]) > 0, "AC2/AC3: non-vacuous seeded witness: " + str(key))
	_test_intents(catalog)
	_test_caps(catalog)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_behemoth_front_rear_control_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _witness(witnesses: Dictionary, key: String) -> void:
	if not witnesses.is_empty():
		witnesses[key] = int(witnesses.get(key, 0)) + 1


# ---------------------------------------------------------------- AC1 source and catalog

func _test_source(catalog: Dictionary) -> void:
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
	_check(boss.get("intent") == _json(LEGACY_INTENT),
		"AC1: the legacy boss intent actions are unchanged")
	var expected_profile := {
		"max_hp": 84, "speed": 5, "dodge": 4, "acc": 0, "prot": 10,
		"is_boss": true, "turns_per_round": 2, "trophy": TROPHY,
		"abilities": [MAUL, STUFFING_HURL, ROPE_LASH, STITCH_WARD],
	}
	_check(boss.get("stitched") == _json(expected_profile),
		"AC1: exact profile; only Rope Lash and Stuffing Hurl change multi/target/effects")
	var foe := StitchedEnemyCatalog.foe_for(catalog, BOSS)
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, BOSS) == TROPHY,
		"AC1: the canonical foe and its trophy load")
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected_profile[key], "AC1: loaded stat stays exact: " + key)
	var normalized: Array = []
	for ability in [MAUL, STUFFING_HURL, ROPE_LASH, STITCH_WARD]:
		var validated := StitchedParts.validate_ability(ability)
		_check(bool(validated.get("ok", false)), "AC1: the independent expected ability validates")
		if bool(validated.get("ok", false)):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized,
		"AC1: the loader exposes the exact normalized behemoth kit in order")
	var abilities: Array = foe.get("abilities", [])
	if abilities.size() == 4:
		var rope: Dictionary = abilities[2]
		var hurl: Dictionary = abilities[1]
		_check(rope.get("id") == "rope_lash" and rope.get("kind") == "melee"
			and rope.get("launch") == [1, 3] and rope.get("target") == [1, 2]
			and rope.get("multi") == true and int(rope.get("acc", 0)) == 85
			and rope.get("dmg") == [6, 9] and int(rope.get("crit", -1)) == 0
			and rope.get("effects") == {"tangled": 2} and rope.get("move") == "attack4",
			"AC1: Rope Lash keeps every named field and gains multi + Tangled 2")
		_check(hurl.get("id") == "stuffing_hurl" and hurl.get("kind") == "ranged"
			and hurl.get("launch") == [1, 4] and hurl.get("target") == [3, 4]
			and hurl.get("multi") == true and int(hurl.get("acc", 0)) == 80
			and hurl.get("dmg") == [5, 8] and int(hurl.get("crit", -1)) == 0
			and hurl.get("effects") == {"blind": 1} and hurl.get("move") == "attack3",
			"AC1: Stuffing Hurl keeps every named field and gains [3, 4], multi + Blind 1")
		_check(int(rope.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(hurl.get("target_mask", 0)) == StitchedParts.rank_mask([3, 4])
			and int(rope.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
			and int(hurl.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 4]),
			"AC1: the normalized launch and target rank masks are the authored ones")
		_check(abilities[0].get("id") == "behemoth_maul"
			and abilities[3].get("id") == "stitch_ward",
			"AC1: Behemoth Maul and Stitch Ward keep their positions in the kit")
	# The other two bosses keep their identity and kits; their own regressions assert the
	# exact profiles, so this only proves this edit never reached them.
	var colossus := StitchedEnemyCatalog.foe_for(catalog, "sewing_machine_colossus")
	var colossus_ids: Array = []
	for ability in colossus.get("abilities", []):
		colossus_ids.append(str(ability["id"]))
	_check(int(colossus.get("max_hp", 0)) == 96 and int(colossus.get("speed", 0)) == 4
		and int(colossus.get("prot", 0)) == 14
		and StitchedEnemyCatalog.trophy_for(catalog, "sewing_machine_colossus") == "sewing_machine_colossus_needle_arm"
		and colossus_ids == ["colossus_treadle", "colossus_bobbin", "colossus_barrage", "colossus_guard"],
		"AC1: Sewing-Machine Colossus stays unchanged")
	var moth := StitchedEnemyCatalog.foe_for(catalog, "moth_queen")
	var moth_ids: Array = []
	for ability in moth.get("abilities", []):
		moth_ids.append(str(ability["id"]))
	_check(int(moth.get("max_hp", 0)) == 90 and int(moth.get("speed", 0)) == 6
		and int(moth.get("dodge", 0)) == 10
		and StitchedEnemyCatalog.trophy_for(catalog, "moth_queen") == "moth_queen_wing_crown"
		and moth_ids == ["queen_dust", "queen_dive", "queen_devour", "moth_veil"],
		"AC1: Moth Queen stays unchanged")
	# The separately authored second phase keeps its record and moves.
	var phase: Variant = JSON.parse_string(FileAccess.get_file_as_string(PHASE_TWO_PATH))
	_check(phase is Dictionary, "AC1: the behemoth phase-two record still parses")
	if phase is Dictionary:
		_check(phase.get("boss_id") == BOSS and int(phase.get("phase", 0)) == 2
			and int(phase.get("threshold_hp", 0)) == 21,
			"AC1: phase two keeps its boss id, phase and 21 HP threshold")
		_check(phase.get("stitched_phase_two", {}).get("abilities") == _json(PHASE_TWO_ABILITIES),
			"AC1: Gut-Rope Slam, Rage Howl, Stuffing Storm and Crushing Lash are unchanged")
		_check(phase.get("intent") == _json(PHASE_TWO_LEGACY),
			"AC1: the phase-two legacy intent is unchanged")
		_check(int(catalog.get("phase_two", {}).get(BOSS, {}).get("threshold_hp", 0)) == 21,
			"AC1: the loader still publishes the 21 HP phase-two threshold")
	_check(ResourceLoader.exists("res://assets/paper/enemies/patchwork_behemoth.png")
		and ResourceLoader.exists("res://assets/paper/stitched/icons/status_blind.png")
		and ResourceLoader.exists("res://assets/paper/stitched/icons/status_tangled.png"),
		"AC1: the existing Behemoth sprite and Blind/Tangled icons carry both moves")


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
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
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
		"AC2/AC5: four dolls face two or three canonical foes")
	_check(battle.turn_order().count(BOSS) == 2,
		"AC5: the Behemoth still takes exactly two turns per round")
	return battle


## Passes authentic turns until the Behemoth owns the turn in the given round. While a hero or
## another foe has the turn, the probe ability proves wrong-turn refusals spend nothing.
func _reach(b: StitchedRules, target_round: int, probe: String, receipts: Array) -> bool:
	for step in range(400):
		if b.is_over():
			break
		if b.round_number() > target_round:
			break
		if b.round_number() == target_round and b.current_actor_id() == BOSS:
			return true
		if b.current_actor_id() != BOSS:
			var snapshot := b.state_snapshot()
			var rng := b.rng_state()
			var rejected := b.use_foe_ability(probe, 1)
			var expected := "it is not a foe turn" if b.current_side() == "hero" \
				else "the foe has no ability " + probe
			_check(not bool(rejected.get("ok", true)) and rejected.get("error") == expected
				and snapshot == b.state_snapshot() and rng == b.rng_state(),
				"AC4: wrong-turn " + probe + " is refused without state/turn/RNG change")
			receipts.append(rejected)
		var passed := b.pass_turn()
		_check(bool(passed.get("ok", false)), "AC2: a legal pass advances the authentic turn")
		if not bool(passed.get("ok", false)):
			return false
		receipts.append(passed)
	_check(false, "AC2: reaches the real Behemoth turn in round %d" % target_round)
	return false


func _refuse(b: StitchedRules, ability_id: String, rank: int, error: String) -> Dictionary:
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var receipt := b.use_foe_ability(ability_id, rank)
	_check(not bool(receipt.get("ok", true)) and receipt.get("error") == error
		and snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC4: %s at rank %d is refused without state/turn/RNG change" % [ability_id, rank])
	return receipt


## Adversarial precondition only: a boss can never occupy foe rank 4 in a legal three-foe fight,
## so the impossible launch is probed by relocating the real boss, then restoring it exactly.
func _illegal_launch_probe(b: StitchedRules, ability_id: String) -> Dictionary:
	var saved: Dictionary = b._units[BOSS].duplicate(true)
	var restored := b.state_snapshot()
	b._units[BOSS]["rank"] = 4
	var mutated := b.state_snapshot()
	var rng := b.rng_state()
	var rejected := b.use_foe_ability(ability_id, 1)
	_check(not bool(rejected.get("ok", true))
		and rejected.get("error") == "ability cannot launch from rank 4",
		"AC4: an impossible launch rank is refused for " + ability_id)
	_check(mutated == b.state_snapshot() and rng == b.rng_state(),
		"AC4: the illegal launch leaves turn, units and RNG unchanged")
	b._units[BOSS] = saved
	_check(restored == b.state_snapshot(),
		"AC4: restoring the real rank leaves the battle untouched")
	return rejected


func _advance_to(b: StitchedRules, actor_id: String, receipts: Array) -> bool:
	for step in range(96):
		if b.is_over():
			break
		if b.current_actor_id() == actor_id:
			return true
		var passed := b.pass_turn()
		_check(bool(passed.get("ok", false)), "AC2/AC3: authentic initiative advances by legal passes")
		if not bool(passed.get("ok", false)):
			return false
		receipts.append(passed)
	_check(false, "AC2/AC3: reaches the real own turn of " + actor_id)
	return false


func _streak_before(receipt: Dictionary, result: Dictionary) -> int:
	var streak := 0
	for earlier in receipt.get("results", []):
		if earlier == result:
			break
		streak = 0 if bool(earlier["hit"]) else streak + 1
	return streak


func _verify_hit(b: StitchedRules, actor: Dictionary, damage: Array, old: Dictionary,
		result: Dictionary, effect: Dictionary) -> void:
	var bases: Array = [StitchedRules.crit_damage(int(damage[1]))] if bool(result["crit"]) \
		else range(int(damage[0]), int(damage[1]) + 1)
	var damages: Array = []
	for base in bases:
		var scaled := StitchedS1BEffects.enemy_damage(int(base) + int(actor.get("dmg_bonus", 0)), b.candle())
		damages.append(StitchedRules.damage_after_modifiers(scaled, actor["statuses"], old["statuses"],
			false, 0, int(old["prot"])))
	_check(damages.has(int(result["damage"]))
		and int(result["target_hp"]) == int(old["hp"]) - int(result["damage"]),
		"AC%s: a landed hit deals the authored range after crit/PROT/candle" % effect["ac"])
	_check(result["statuses"] == [{"status": effect["status"], "duration": effect["duration"]}],
		"AC%s: a landed hit applies exactly %s %d" % [effect["ac"], str(effect["status"]).capitalize(),
			int(effect["duration"])])


func _verify_miss(old: Dictionary, result: Dictionary, ac: String, label: String) -> void:
	_check(int(result["damage"]) == 0 and result["statuses"].is_empty()
		and int(result["target_hp"]) == int(old["hp"]),
		"AC%s: a missed %s deals no damage and applies no status" % [ac, label])


# ---------------------------------------------------------------- AC2 Rope Lash on ranks 1-2

func _rope_trace(catalog: Dictionary, seed_value: int, witnesses: Dictionary) -> Dictionary:
	var b := _battle(catalog, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	if not _reach(b, 3, "rope_lash", receipts):
		return {}
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var intent := StitchedFoeIntent.choose(b, b.get_unit(BOSS))
	_check(snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC4: reading the live Rope Lash intent changes no state or RNG")
	_check(intent.get("ability_id") == "rope_lash" and intent.get("ability_name") == "Rope Lash"
		and intent.get("multi") == true and intent.get("affected_ranks") == [1, 2]
		and intent.get("base_acc") == 85 and intent.get("base_damage") == [6, 9]
		and intent.get("base_effects") == {"tangled": 2} and intent.get("target_side") == "hero"
		and not bool(intent.get("pass", true)),
		"AC4: round-three intent announces Rope Lash on both front ranks with Tangled 2")
	for rank in [0, 3, 5]:
		receipts.append(_refuse(b, "rope_lash", rank, "no legal target in rank %d" % rank))
	receipts.append(_illegal_launch_probe(b, "rope_lash"))
	var before := b.get_heroes().duplicate(true)
	var actor := b.get_unit(BOSS)
	var turn := int(b.state_snapshot()["turn_index"])
	var round_before := b.round_number()
	var receipt := b.use_foe_ability(str(intent.get("ability_id", "")), 1)
	receipts.append(receipt)
	_check(bool(receipt.get("ok", false)) and receipt.get("actor") == BOSS
		and receipt.get("ability") == "rope_lash" and receipt.get("results", []).size() == 2,
		"AC2: one canonical Rope Lash resolves for both occupied front ranks")
	if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 2:
		return {}
	var after := b.state_snapshot()
	_check(int(after["turn_index"]) == turn + 1 or int(after["round"]) == round_before + 1,
		"AC5: the sweep spends exactly one of the Behemoth's two turns")
	var ranks: Array = []
	var hit_by_rank: Dictionary = {}
	var acc := 85 + int(actor["acc"]) + int(b.candle_band()["enemy_acc"])
	for result in receipt["results"]:
		var rank := int(result["target_rank"])
		ranks.append(rank)
		var old: Dictionary = before[rank - 1]
		_check(result["target"] == old["id"] and int(old["rank"]) == rank,
			"AC2: each receipt names the doll genuinely sewn into that rank")
		var chance := StitchedRules.hit_chance(acc, StitchedRules.effective_dodge(old),
			_streak_before(receipt, result))
		_check(int(result["hit_chance"]) == chance
			and bool(result["hit"]) == (int(result["roll"]) <= chance),
			"AC2: Rope Lash rolls its authored 85 ACC separately per front rank")
		if bool(result["hit"]):
			_verify_hit(b, actor, intent["base_damage"], old, result,
				{"status": "tangled", "duration": 2, "ac": "2"})
			hit_by_rank[rank] = result
			_witness(witnesses, "rope_hit_rank" + str(rank))
		else:
			_verify_miss(old, result, "2", "Rope Lash")
			_witness(witnesses, "rope_miss")
	ranks.sort()
	_check(ranks == [1, 2],
		"AC2: occupied front ranks 1 and 2 each resolve exactly once, never ranks 3 or 4")
	_check(b.get_unit("tinker") == before[2] and b.get_unit("lantern_monk") == before[3],
		"AC2: the rear ranks 3 and 4 are never touched by Rope Lash")
	if hit_by_rank.has(2):
		_rope_countdown(b, str(hit_by_rank[2]["target"]), receipts, witnesses)
	return {
		"receipts": receipts, "intent": intent, "order": b.turn_order(),
		"heroes": b.get_heroes().duplicate(true), "state": b.state_snapshot(), "rng": b.rng_state(),
	}


## Tangled 2 survives the first own-turn tick as Tangled 1, refusing a MOVE without spending the
## turn or RNG, then expires on the doll's following own turn.
func _rope_countdown(b: StitchedRules, hero_id: String, receipts: Array, witnesses: Dictionary) -> void:
	if not _advance_to(b, hero_id, receipts):
		return
	var hero := b.get_unit(hero_id)
	_check(int(hero["rank"]) == 2 and int(hero["statuses"].get("tangled", 0)) == 1,
		"AC2: Tangled 2 survives the first own-turn tick as Tangled 1")
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var refused := b.move(1)
	_check(not bool(refused.get("ok", true))
		and refused.get("error") == "a tangled hero cannot move"
		and snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC2: the Tangled 1 doll's MOVE is refused without spending turn or RNG")
	receipts.append(refused)
	_witness(witnesses, "rope_tangled_refusal")
	var spent := b.pass_turn()
	_check(bool(spent.get("ok", false)), "AC2: the refused MOVE leaves the turn to spend")
	receipts.append(spent)
	if not _advance_to(b, hero_id, receipts):
		return
	var freed := b.get_unit(hero_id)
	_check(not freed["statuses"].has("tangled"),
		"AC2: Tangled expires on the doll's following own turn")
	var moved := b.move(1)
	_check(bool(moved.get("ok", false)) and moved.get("action") == "move"
		and int(moved.get("from", 0)) == 2 and int(moved.get("to", 0)) == 3,
		"AC2: MOVE works again once Tangled has expired")
	receipts.append(moved)
	_witness(witnesses, "rope_tangled_expired")


# ---------------------------------------------------------------- AC3 Stuffing Hurl on ranks 3-4

func _stuffing_trace(catalog: Dictionary, seed_value: int, witnesses: Dictionary) -> Dictionary:
	var b := _battle(catalog, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	if not _reach(b, 2, "stuffing_hurl", receipts):
		return {}
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var intent := StitchedFoeIntent.choose(b, b.get_unit(BOSS))
	_check(snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC4: reading the live Stuffing Hurl intent changes no state or RNG")
	_check(intent.get("ability_id") == "stuffing_hurl" and intent.get("ability_name") == "Stuffing Hurl"
		and intent.get("multi") == true and intent.get("affected_ranks") == [3, 4]
		and intent.get("base_acc") == 80 and intent.get("base_damage") == [5, 8]
		and intent.get("base_effects") == {"blind": 1} and intent.get("target_side") == "hero"
		and not bool(intent.get("pass", true)),
		"AC4: round-two intent announces Stuffing Hurl on both rear ranks with Blind 1")
	for rank in [0, 1, 5]:
		receipts.append(_refuse(b, "stuffing_hurl", rank, "no legal target in rank %d" % rank))
	var before := b.get_heroes().duplicate(true)
	var actor := b.get_unit(BOSS)
	var turn := int(b.state_snapshot()["turn_index"])
	var round_before := b.round_number()
	var receipt := b.use_foe_ability(str(intent.get("ability_id", "")), 3)
	receipts.append(receipt)
	_check(bool(receipt.get("ok", false)) and receipt.get("actor") == BOSS
		and receipt.get("ability") == "stuffing_hurl" and receipt.get("results", []).size() == 2,
		"AC3: one canonical Stuffing Hurl resolves for both occupied rear ranks")
	if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 2:
		return {}
	var after := b.state_snapshot()
	_check(int(after["turn_index"]) == turn + 1 or int(after["round"]) == round_before + 1,
		"AC5: the cloud spends exactly one of the Behemoth's two turns")
	var ranks: Array = []
	var hit_by_rank: Dictionary = {}
	var acc := 80 + int(actor["acc"]) + int(b.candle_band()["enemy_acc"])
	for result in receipt["results"]:
		var rank := int(result["target_rank"])
		ranks.append(rank)
		var old: Dictionary = before[rank - 1]
		_check(result["target"] == old["id"] and int(old["rank"]) == rank,
			"AC3: each receipt names the doll genuinely sewn into that rear rank")
		var chance := StitchedRules.hit_chance(acc, StitchedRules.effective_dodge(old),
			_streak_before(receipt, result))
		_check(int(result["hit_chance"]) == chance
			and bool(result["hit"]) == (int(result["roll"]) <= chance),
			"AC3: Stuffing Hurl rolls its authored 80 ACC separately per rear rank")
		if bool(result["hit"]):
			_verify_hit(b, actor, intent["base_damage"], old, result,
				{"status": "blind", "duration": 1, "ac": "3"})
			hit_by_rank[rank] = result
			_witness(witnesses, "stuffing_hit")
		else:
			_verify_miss(old, result, "3", "Stuffing Hurl")
			_witness(witnesses, "stuffing_miss")
	ranks.sort()
	_check(ranks == [3, 4],
		"AC3: occupied rear ranks 3 and 4 each resolve exactly once, never the front ranks")
	_check(b.get_unit("warden") == before[0] and b.get_unit("seamstress") == before[1],
		"AC3: the front ranks 1 and 2 are never touched by Stuffing Hurl")
	if not hit_by_rank.is_empty():
		var rank := 3 if hit_by_rank.has(3) else 4
		_blind_cycle(b, str(hit_by_rank[rank]["target"]), receipts, witnesses)
	return {
		"receipts": receipts, "intent": intent, "order": b.turn_order(),
		"heroes": b.get_heroes().duplicate(true), "state": b.state_snapshot(), "rng": b.rng_state(),
	}


## A Blinded doll's next legal offensive part attack misses without a hit roll, consumes Blind,
## and its next attack rolls normally again.
func _blind_cycle(b: StitchedRules, hero_id: String, receipts: Array, witnesses: Dictionary) -> void:
	if not _advance_to(b, hero_id, receipts):
		return
	var hero := b.get_unit(hero_id)
	_check(int(hero["statuses"].get("blind", 0)) == 1,
		"AC3: Blind 1 waits on the struck rear doll until its next attack")
	var attack := _offensive_part(b, hero)
	_check(not attack.is_empty(), "AC3: the Blinded doll has a genuine legal offensive part")
	if attack.is_empty():
		return
	var receipt := b.use_part(str(attack["part"]), int(attack["rank"]))
	receipts.append(receipt)
	_check(bool(receipt.get("ok", false)) and receipt.get("action") != "refused"
		and receipt.get("results", []).size() >= 1,
		"AC3: the Blinded doll's legal part attack resolves")
	if not bool(receipt.get("ok", false)) or receipt.get("action") == "refused":
		return
	var first: Dictionary = receipt["results"][0]
	_check(bool(first.get("blinded", false)) and not bool(first["hit"])
		and int(first["damage"]) == 0 and not first.has("roll"),
		"AC3: Blind forces the next offensive ability to miss without a hit roll")
	_check(not b.get_unit(hero_id)["statuses"].has("blind"),
		"AC3: the forced miss consumes Blind")
	_witness(witnesses, "blind_forced_miss")
	if not _advance_to(b, hero_id, receipts):
		return
	var again_hero := b.get_unit(hero_id)
	_check(not again_hero["statuses"].has("blind"),
		"AC3: Blind does not linger past the attack that consumed it")
	var again := _offensive_part(b, again_hero)
	_check(not again.is_empty(), "AC3: the doll still has a legal offensive ability afterwards")
	if again.is_empty():
		return
	var second := b.use_part(str(again["part"]), int(again["rank"]))
	receipts.append(second)
	_check(bool(second.get("ok", false)) and second.get("action") != "refused"
		and second.get("results", []).size() >= 1,
		"AC3: the later attack resolves through the real rules")
	if not bool(second.get("ok", false)) or second.get("action") == "refused":
		return
	var hit: Dictionary = second["results"][0]
	_check(hit.has("roll") and not hit.has("blinded")
		and bool(hit["hit"]) == (int(hit["roll"]) <= int(hit["hit_chance"])),
		"AC3: an attack after Blind was consumed rolls normally")
	_witness(witnesses, "attack_after_blind")


func _offensive_part(b: StitchedRules, hero: Dictionary) -> Dictionary:
	for slot in StitchedParts.SLOTS:
		var equipped: Dictionary = hero["parts"].get(slot, {})
		if equipped.is_empty() or bool(equipped.get("torn", false)):
			continue
		var ability := StitchedParts.ability_at_tier(b._parts[str(equipped["id"])], int(equipped["tier"]))
		if ability.is_empty() or str(ability["target_side"]) != "enemy" or int(ability["dmg"][1]) <= 0:
			continue
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(hero["rank"])):
			continue
		if not b._self_move_gate(hero, ability).is_empty():
			continue
		for rank in range(1, 5):
			if not b._legal_targets(hero, ability, rank).is_empty():
				return {"part": str(equipped["id"]), "rank": rank}
	return {}


# ---------------------------------------------------------------- AC4 absent ranks and caps

func _test_intents(catalog: Dictionary) -> void:
	# Rope Lash omits an absent front doll instead of inventing a phantom target.
	var one_front := _battle(catalog, 11, [BOSS, "ragling"], [1])
	if one_front != null and _reach(one_front, 3, "rope_lash", []):
		var intent := StitchedFoeIntent.choose(one_front, one_front.get_unit(BOSS))
		_check(intent.get("ability_id") == "rope_lash" and intent.get("multi") == true
			and intent.get("affected_ranks") == [2],
			"AC4: Rope Lash omits the absent rank 1 and reports only occupied rank 2")
	var no_front := _battle(catalog, 11, [BOSS, "ragling"], [1, 2])
	if no_front != null and _reach(no_front, 3, "rope_lash", []):
		var before := no_front.state_snapshot()
		var rng := no_front.rng_state()
		var intent := StitchedFoeIntent.choose(no_front, no_front.get_unit(BOSS))
		_check(intent.get("ability_id") == "stitch_ward" and intent.get("target_side") == "foe"
			and intent.get("affected_ranks") == [1] and not bool(intent.get("pass", true)),
			"AC4: with no front doll the live driver projects a different legal intent")
		_check(before == no_front.state_snapshot() and rng == no_front.rng_state(),
			"AC4: the fallback projection is read-only")
	# Stuffing Hurl omits an absent rear rank and never falls back onto the front ranks.
	var one_rear := _battle(catalog, 12, [BOSS, "ragling"], [4])
	if one_rear != null and _reach(one_rear, 2, "stuffing_hurl", []):
		var intent := StitchedFoeIntent.choose(one_rear, one_rear.get_unit(BOSS))
		_check(intent.get("ability_id") == "stuffing_hurl" and intent.get("multi") == true
			and intent.get("affected_ranks") == [3],
			"AC4: Stuffing Hurl omits the absent rank 4 and reports only occupied rank 3")
	var no_rear := _battle(catalog, 12, [BOSS, "ragling"], [3, 4])
	if no_rear != null and _reach(no_rear, 2, "stuffing_hurl", []):
		var intent := StitchedFoeIntent.choose(no_rear, no_rear.get_unit(BOSS))
		_check(intent.get("ability_id") == "rope_lash" and intent.get("affected_ranks") == [1, 2],
			"AC4: with no rear doll the live driver projects a different legal intent")
		_check(no_rear.use_foe_ability("stuffing_hurl", 3).get("ok", true) == false,
			"AC4: Stuffing Hurl cannot fire at an empty rear rank")


func _test_caps(catalog: Dictionary) -> void:
	var three := _battle(catalog, 5, [BOSS, "ragling", "ragling_guard"])
	if three != null:
		_check(three.get_foes().size() == 3,
			"AC5: a normal three-foe Behemoth battle remains legal")
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not preview is Dictionary:
		_check(false, "AC5: the shipped preview exists for the cap probe")
		return
	var config: Dictionary = preview
	var parts: Array = config["parts"].duplicate(true)
	parts.append_array(catalog["parts"].duplicate(true))
	var opponents: Array = []
	for enemy_id in [BOSS, "ragling", "ragling_guard", "moth_scribe"]:
		opponents.append(StitchedEnemyCatalog.foe_for(catalog, str(enemy_id)))
	var created := StitchedRules.create({
		"mode": "stitched", "seed": 9, "candle": 100,
		"heroes": config["heroes"].duplicate(true), "parts": parts, "foes": opponents,
	})
	_check(not bool(created.get("ok", true)) and created.get("battle") == null,
		"AC5: the normal cap still refuses a fourth starting foe")
