extends SceneTree
## Canonical first-phase Patchwork Behemoth Maul seam tear through the real enemy catalog and
## seeded StitchedRules turns.
##
## Behemoth Maul keeps its authored single melee, launch/target ranks, ACC, damage and pose, and
## now carries {"tear":1}: a landed hit on a surviving doll tears exactly one untorn non-torso
## part and the torn ability stays locked, while a natural miss tears nothing. Every combat
## witness is a public turn (pass_turn, use_foe_ability, use_part) or the public look-driven
## tear_part on the boss's own turn; no internal battle field is mutated to simulate a hit. A
## low-HP doll is used separately to preserve the existing Hanging-by-a-Thread tear through a
## non-tearing Ragling hit, never through Maul.

const BOSS := "patchwork_behemoth"
const BOSS_PATH := "res://data/enemies/boss.json"
const PHASE_TWO_PATH := "res://data/enemies/m05_behemoth_phase_two.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const TROPHY := "patchwork_behemoth_heart_torso"

const MAUL := {
	"id": "behemoth_maul", "name": "Behemoth Maul", "kind": "melee", "launch": [1, 3],
	"target": [1, 2], "target_side": "enemy", "multi": false, "acc": 85,
	"dmg": [8, 12], "crit": 0, "effects": {"tear": 1}, "self_move": 0, "move": "attack2",
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
const COLOSSUS_TREADLE := {
	"id": "colossus_treadle", "name": "Treadle Stomp", "kind": "melee",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 84, "dmg": [6, 9], "crit": 0, "effects": {"stun": 1},
	"self_move": 0, "move": "attack2",
}
const COLOSSUS_BOBBIN := {
	"id": "colossus_bobbin", "name": "Bobbin Shot", "kind": "ranged",
	"launch": [1, 4], "target": [3, 4], "target_side": "enemy", "multi": false,
	"acc": 80, "dmg": [4, 6], "crit": 0, "effects": {"pull": 1},
	"self_move": 0, "move": "attack3",
}
const COLOSSUS_BARRAGE := {
	"id": "colossus_barrage", "name": "Needle Barrage", "kind": "ranged",
	"launch": [1, 4], "target": [1, 2, 3], "target_side": "enemy", "multi": true,
	"acc": 80, "dmg": [2, 3], "crit": 0, "effects": {"bleed": 1},
	"self_move": 0, "move": "attack4",
}
const COLOSSUS_GUARD := {
	"id": "colossus_guard", "name": "Iron Tread", "kind": "buff",
	"launch": [1, 3], "target": [1], "target_side": "self", "multi": false,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"thorns": 4},
	"self_move": 0, "move": "guard",
}
const MOTH_DUST := {
	"id": "queen_dust", "name": "Queen Dust", "kind": "ranged",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 85, "dmg": [3, 5], "crit": 0, "effects": {"weak": 1, "blind": 1},
	"self_move": 0, "move": "attack2",
}
const MOTH_DIVE := {
	"id": "queen_dive", "name": "Pin Crown Dive", "kind": "melee",
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [6, 8], "crit": 0, "effects": {"tangled": 2, "snip": 1},
	"self_move": 0, "move": "attack3",
}
const MOTH_DEVOUR := {
	"id": "queen_devour", "name": "Devour", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [7, 9], "crit": 0, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack4",
}
const MOTH_VEIL := {
	"id": "moth_veil", "name": "Moth Veil", "kind": "buff",
	"launch": [1, 3], "target": [1, 2, 3, 4], "target_side": "ally", "multi": true,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"dodge": 8, "duration": 1},
	"self_move": 0, "move": "skill",
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
const LIMBS := ["head", "arms", "legs"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the canonical enemy catalog loads: " + str(catalog.get("error", "")))
	_test_source(catalog)
	if bool(catalog.get("ok", false)):
		var witnesses := {"tear": 0, "miss": 0, "refused_tear": 0}
		for seed_value in range(1, 33):
			for all_torn in [false, true]:
				var first := _maul_script(catalog, seed_value, all_torn, witnesses)
				var replay := _maul_script(catalog, seed_value, all_torn, {})
				_check(not first.is_empty() and first == replay,
					"AC4: same-seed Maul receipts, dolls, state and RNG replay identically")
		for key in witnesses:
			_check(int(witnesses[key]) > 0, "AC2/AC3: non-vacuous seeded witness: " + str(key))
		_test_hanging_preservation(catalog)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_behemoth_maul_tear_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _record(records: Array, enemy_id: String) -> Dictionary:
	var matches: Array = records.filter(
		func(record: Dictionary) -> bool: return record.get("id") == enemy_id)
	_check(matches.size() == 1, "AC1: exactly one " + enemy_id + " record")
	return matches[0] if matches.size() == 1 else {}


# ---------------------------------------------------------------- AC1 source and catalog

func _test_source(catalog: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSS_PATH))
	_check(records is Array, "AC1: the real boss catalog parses")
	if not records is Array:
		return
	var boss := _record(records, BOSS)
	if boss.is_empty():
		return
	_check(boss.get("name") == "Patchwork Behemoth" and int(boss.get("max_hp", 0)) == 84
		and boss.get("art_path") == "res://assets/paper/enemies/patchwork_behemoth.png"
		and boss.get("intent") == _json(LEGACY_INTENT),
		"AC1: name, legacy HP, sprite and every legacy intent action stay exact")
	var expected_profile := {
		"max_hp": 84, "speed": 5, "dodge": 4, "acc": 0, "prot": 10,
		"is_boss": true, "turns_per_round": 2, "trophy": TROPHY,
		"abilities": [MAUL, STUFFING_HURL, ROPE_LASH, STITCH_WARD],
	}
	_check(boss.get("stitched") == _json(expected_profile),
		"AC1: the Behemoth kit keeps every named field and adds exactly Maul tear")
	var maul_source: Dictionary = boss["stitched"]["abilities"][0]
	var maul_expected: Dictionary = _json(MAUL)
	for key in ["id", "name", "kind", "launch", "target", "target_side", "multi", "acc",
			"dmg", "crit", "self_move", "move"]:
		_check(maul_source.get(key) == maul_expected[key],
			"AC1: Behemoth Maul keeps its authored " + str(key))
	_check(maul_source.get("effects", {}).size() == 1
		and int(maul_source.get("effects", {}).get("tear", 0)) == 1,
		"AC1: Behemoth Maul's only authored effect change is Tear 1")
	var foe := StitchedEnemyCatalog.foe_for(catalog, BOSS)
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, BOSS) == TROPHY,
		"AC1: the canonical Behemoth foe and its trophy load")
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected_profile[key], "AC1: loaded stat stays exact: " + key)
	var normalized: Array = []
	for ability in [MAUL, STUFFING_HURL, ROPE_LASH, STITCH_WARD]:
		var validated := StitchedParts.validate_ability(ability)
		_check(bool(validated.get("ok", false)),
			"AC1: the independent expected ability validates")
		if bool(validated.get("ok", false)):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized,
		"AC1: the loader exposes the exact normalized first-phase kit in order")
	var loaded_maul: Dictionary = {}
	for ability in foe.get("abilities", []):
		if str(ability.get("id", "")) == "behemoth_maul":
			loaded_maul = ability
	_check(loaded_maul == normalized[0] and loaded_maul.get("effects") == {"tear": 1},
		"AC1: the loaded canonical Maul carries Tear 1 through validation")
	# The other two bosses keep their authored kits; this edit never reached them.
	var colossus := _record(records, "sewing_machine_colossus")
	var colossus_profile := {
		"max_hp": 96, "speed": 4, "dodge": 3, "acc": 0, "prot": 14,
		"is_boss": true, "turns_per_round": 2,
		"trophy": "sewing_machine_colossus_needle_arm",
		"abilities": [COLOSSUS_TREADLE, COLOSSUS_BOBBIN, COLOSSUS_BARRAGE, COLOSSUS_GUARD],
	}
	_check(colossus.get("stitched") == _json(colossus_profile),
		"AC1: Sewing-Machine Colossus keeps its exact kit and trophy")
	var moth := _record(records, "moth_queen")
	var moth_profile := {
		"max_hp": 90, "speed": 6, "dodge": 10, "acc": 0, "prot": 4,
		"is_boss": true, "turns_per_round": 2, "trophy": "moth_queen_wing_crown",
		"abilities": [MOTH_DUST, MOTH_DIVE, MOTH_DEVOUR, MOTH_VEIL],
	}
	_check(moth.get("stitched") == _json(moth_profile),
		"AC1: Moth Queen keeps her exact kit and trophy")
	var phase: Variant = JSON.parse_string(FileAccess.get_file_as_string(PHASE_TWO_PATH))
	_check(phase is Dictionary, "AC1: the behemoth phase-two record still parses")
	if phase is Dictionary:
		_check(phase.get("boss_id") == BOSS and int(phase.get("phase", 0)) == 2
			and int(phase.get("threshold_hp", 0)) == 21,
			"AC1: phase two keeps its boss id, phase and 21 HP threshold")
		_check(phase.get("stitched_phase_two", {}).get("abilities") == _json(PHASE_TWO_ABILITIES),
			"AC1: Gut-Rope Slam, Rage Howl, Stuffing Storm and Crushing Lash are unchanged")
		_check(int(catalog.get("phase_two", {}).get(BOSS, {}).get("threshold_hp", 0)) == 21,
			"AC1: the loader still publishes the 21 HP phase-two threshold")


# ---------------------------------------------------------------- seeded battle helpers

func _battle(catalog: Dictionary, seed_value: int, ids: Array = [BOSS, "ragling"],
		hero_hp: Dictionary = {}) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	_check(preview is Dictionary, "AC2: the shipped four-doll preview exists")
	if not preview is Dictionary:
		return null
	var heroes: Array = preview["heroes"].duplicate(true)
	for hero in heroes:
		if hero_hp.has(str(hero["id"])):
			hero["hp"] = int(hero_hp[str(hero["id"])])
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"].duplicate(true))
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
		_check(not foe.is_empty(), "AC1: the canonical foe exists: " + str(enemy_id))
		foes.append(foe)
	var created := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": heroes, "parts": parts, "foes": foes,
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
	return battle


## Passes authentic turns until the Behemoth owns the turn. A Maul probe on every other turn
## proves wrong-side/wrong-foe refusals spend no state, turn or RNG.
func _reach_boss(b: StitchedRules, receipts: Array) -> bool:
	for step in range(400):
		if b.is_over():
			break
		if b.current_actor_id() == BOSS:
			return true
		var snapshot := b.state_snapshot()
		var rng := b.rng_state()
		var rejected := b.use_foe_ability("behemoth_maul", 1)
		var expected := "it is not a foe turn" if b.current_side() == "hero" \
			else "the foe has no ability behemoth_maul"
		_check(not bool(rejected.get("ok", true)) and rejected.get("error") == expected
			and snapshot == b.state_snapshot() and rng == b.rng_state(),
			"AC3: a wrong-turn Maul is refused without state/turn/RNG change")
		receipts.append(rejected)
		var passed := b.pass_turn()
		_check(bool(passed.get("ok", false)), "AC2: a legal pass advances the authentic turn")
		if not bool(passed.get("ok", false)):
			return false
		receipts.append(passed)
	_check(false, "AC2: reaches the real Behemoth turn")
	return false


func _advance_to(b: StitchedRules, actor_id: String, receipts: Array) -> bool:
	for step in range(96):
		if b.is_over():
			break
		if b.current_actor_id() == actor_id:
			return true
		var passed := b.pass_turn()
		_check(bool(passed.get("ok", false)), "AC3: authentic initiative advances by legal passes")
		if not bool(passed.get("ok", false)):
			return false
		receipts.append(passed)
	_check(false, "AC3: reaches the real own turn of " + actor_id)
	return false


func _refuse(b: StitchedRules, rank: int, error: String) -> Dictionary:
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var receipt := b.use_foe_ability("behemoth_maul", rank)
	_check(not bool(receipt.get("ok", true)) and receipt.get("error") == error
		and snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC3: Behemoth Maul at rank %d is refused without state/turn/RNG change" % rank)
	return receipt


## Adversarial precondition only: a boss can never occupy foe rank 4 in a legal two/three-foe
## fight, so the impossible launch is probed by relocating the real boss, then restoring it
## exactly. No hit is simulated through this mutation.
func _illegal_launch_probe(b: StitchedRules) -> Dictionary:
	var saved: Dictionary = b._units[BOSS].duplicate(true)
	var restored := b.state_snapshot()
	b._units[BOSS]["rank"] = 4
	var mutated := b.state_snapshot()
	var rng := b.rng_state()
	var rejected := b.use_foe_ability("behemoth_maul", 1)
	_check(not bool(rejected.get("ok", true))
		and rejected.get("error") == "ability cannot launch from rank 4",
		"AC3: an impossible Maul launch rank is refused")
	_check(mutated == b.state_snapshot() and rng == b.rng_state(),
		"AC3: the illegal launch leaves turn, units and RNG unchanged")
	b._units[BOSS] = saved
	_check(restored == b.state_snapshot(),
		"AC3: restoring the real rank leaves the battle untouched")
	return rejected


func _torn_slots(hero: Dictionary) -> Array:
	var torn: Array = []
	for slot in hero["parts"]:
		if bool(hero["parts"][slot]["torn"]):
			torn.append(slot)
	torn.sort()
	return torn


func _rank_one_hero(b: StitchedRules) -> Dictionary:
	for hero in b.get_heroes():
		if int(hero["rank"]) == 1:
			return hero.duplicate(true)
	return {}


# ---------------------------------------------------------------- AC2/AC3 Maul on the boss turn

func _maul_script(catalog: Dictionary, seed_value: int, all_torn: bool,
		witnesses: Dictionary) -> Dictionary:
	var b := _battle(catalog, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	if not _reach_boss(b, receipts):
		return {}
	_check(int(b.get_unit(BOSS)["rank"]) == 1,
		"AC2: the canonical Behemoth holds the legal front foe rank")
	var rank_one := _rank_one_hero(b)
	_check(not rank_one.is_empty() and int(rank_one["hp"]) > 0
		and not bool(rank_one["hanging"]) and not bool(rank_one["lost"]),
		"AC2: a real living doll stands in the Maul target rank")
	if rank_one.is_empty():
		return {}
	var target_id := str(rank_one["id"])
	if all_torn:
		# Public authored tears (no turn spent) leave only the torso stitched, proving a
		# contained refusal rather than a fabricated extra tear.
		for step in range(3):
			var torn := b.tear_part(target_id)
			_check(bool(torn.get("ok", false)) and torn.get("hero") == target_id,
				"AC3: the public seam tear setup succeeds on the Behemoth's turn")
			receipts.append(torn)
		_check(_torn_slots(b.get_unit(target_id)) == ["arms", "head", "legs"],
			"AC3: head, arms and legs are already torn before the Maul")
	else:
		_check(_torn_slots(rank_one).is_empty(),
			"AC2: the primary witness starts with every seam intact")
	var target_before := b.get_unit(target_id)
	var target_rank := 1
	for rank in [0, 3, 4, 5]:
		receipts.append(_refuse(b, rank, "no legal target in rank %d" % rank))
	receipts.append(_illegal_launch_probe(b))
	var actor := b.get_unit(BOSS)
	var turn_before := int(b.state_snapshot()["turn_index"])
	var round_before := b.round_number()
	var others_before: Dictionary = {}
	for hero in b.get_heroes():
		if str(hero["id"]) != target_id:
			others_before[str(hero["id"])] = hero.duplicate(true)
	var receipt := b.use_foe_ability("behemoth_maul", target_rank)
	receipts.append(receipt)
	_check(bool(receipt.get("ok", false)) and receipt.get("actor") == BOSS
		and receipt.get("ability") == "behemoth_maul"
		and receipt.get("results", []).size() == 1,
		"AC2: the canonical Behemoth Maul commits one real target receipt")
	if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 1:
		return {}
	var after_state := b.state_snapshot()
	_check(int(after_state["turn_index"]) == turn_before + 1
		or int(after_state["round"]) == round_before + 1,
		"AC2: the Maul spends exactly one of the Behemoth's two turns")
	var hit: Dictionary = receipt["results"][0]
	var acc := 85 + int(actor["acc"]) + int(b.candle_band()["enemy_acc"])
	_check(hit.get("target") == target_id and int(hit.get("target_rank", 0)) == target_rank
		and int(hit.get("hit_chance", -1)) == StitchedRules.hit_chance(
			acc, StitchedRules.effective_dodge(target_before), int(actor["miss_streak"]))
		and bool(hit.get("hit")) == (int(hit.get("roll", 0)) <= int(hit.get("hit_chance", -1))),
		"AC2/AC3: the authored 85 ACC roll picks the real front doll")
	var after := b.get_unit(target_id)
	if bool(hit.get("hit")):
		_check(hit.has("roll") and int(hit.get("damage", 0)) > 0,
			"AC2: a confirmed Maul hit still deals ordinary damage")
		var bases: Array = [StitchedRules.crit_damage(12)] if bool(hit.get("crit")) \
			else range(8, 13)
		var damages: Array = []
		for base in bases:
			var scaled := StitchedS1BEffects.enemy_damage(
				int(base) + int(actor.get("dmg_bonus", 0)), b.candle())
			damages.append(StitchedRules.damage_after_modifiers(scaled, actor["statuses"],
				target_before["statuses"], false, 0, int(target_before["prot"])))
		_check(damages.has(int(hit.get("damage", -1)))
			and int(hit.get("target_hp", -1)) == int(target_before["hp"]) - int(hit["damage"]),
			"AC2: Maul damage still passes the authored range and PROT")
		_check(int(after["hp"]) > 0 and not bool(after["hanging"]) and not bool(after["lost"])
			and not bool(hit.get("hanging")) and not bool(hit.get("lost")),
			"AC2: the primary tear witness survives above zero HP")
		var tear: Dictionary = hit.get("tear", {})
		if all_torn:
			_check(tear == {"ok": false, "action": "tear", "actor": target_id,
				"error": "no untorn non-torso part"},
				"AC3: a doll with no eligible non-torso part gets the contained refusal")
			_check(_torn_slots(after) == ["arms", "head", "legs"]
				and not bool(after["parts"]["torso"]["torn"]),
				"AC3: the refusal never tears the torso or invents a fourth tear")
			_witness(witnesses, "refused_tear")
		else:
			var torn := _torn_slots(after)
			_check(bool(tear.get("ok", false)) and torn.size() == 1
				and str(torn[0]) == str(tear.get("slot")) and LIMBS.has(str(tear.get("slot")))
				and not bool(after["parts"]["torso"]["torn"]),
				"AC2: a landed Maul tears exactly one non-torso seam, never the torso")
			if torn.size() == 1:
				var slot := str(torn[0])
				_check(tear == {"ok": true, "action": "tear", "hero": target_id,
					"slot": slot, "part": str(target_before["parts"][slot]["id"])},
					"AC2: the tear receipt names the real doll, slot and part")
				_check(bool(after["parts"][slot]["torn"])
					and str(after["parts"][slot]["id"]) == str(target_before["parts"][slot]["id"]),
					"AC2: the torn part stays equipped with the same authored id")
				_check_torn_part_refused(b, target_id, str(after["parts"][slot]["id"]), receipts)
			_witness(witnesses, "tear")
	else:
		_check(int(hit.get("damage", -1)) == 0 and not bool(hit.get("crit"))
			and hit.get("statuses", []) == [] and not hit.has("tear")
			and int(hit.get("target_hp", -1)) == int(target_before["hp"])
			and int(after["hp"]) == int(target_before["hp"])
			and after["parts"] == target_before["parts"],
			"AC3: a natural seeded Maul miss deals no damage and causes no tear")
		_witness(witnesses, "miss")
	_check(hit.has("roll"),
		"AC2/AC3: the Maul turn actually rolled the seeded hit die")
	for old_id in others_before:
		_check(b.get_unit(str(old_id)) == others_before[old_id],
			"AC2: the uninvolved doll " + str(old_id) + " stays unchanged")
	return {"receipts": receipts, "heroes": b.get_heroes().duplicate(true),
		"state": b.state_snapshot(), "rng": b.rng_state()}


func _check_torn_part_refused(b: StitchedRules, hero_id: String, part_id: String,
		receipts: Array) -> void:
	if not _advance_to(b, hero_id, receipts):
		return
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var refused := b.use_part(part_id, 1)
	_check(not bool(refused.get("ok", true)) and refused.get("error") == "part is torn"
		and snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC2: the torn part's ability is locked without state/RNG/turn spend")
	receipts.append(refused)


func _witness(witnesses: Dictionary, key: String) -> void:
	if not witnesses.is_empty():
		witnesses[key] = int(witnesses.get(key, 0)) + 1


# ---------------------------------------------------------------- AC3 existing Hanging semantics

func _test_hanging_preservation(catalog: Dictionary) -> void:
	var witnessed := false
	for seed_value in range(1, 33):
		var b := _battle(catalog, seed_value, [BOSS, "ragling"], {"warden": 1})
		if b == null:
			continue
		var receipts: Array = []
		if not _advance_to(b, "ragling", receipts):
			return
		var before := b.get_unit("warden")
		_check(int(before["hp"]) == 1 and not bool(before["hanging"])
			and not bool(before["lost"]) and _torn_slots(before).is_empty(),
			"AC3: the Hanging witness carries one HP and every seam intact")
		var receipt := b.use_foe_ability("rag_rake", 1)
		receipts.append(receipt)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 1:
			continue
		var hit: Dictionary = receipt["results"][0]
		if not bool(hit.get("hit")):
			continue
		witnessed = true
		var after := b.get_unit("warden")
		var tear: Dictionary = hit.get("tear", {})
		_check(hit.get("target") == "warden" and bool(hit.get("hanging"))
			and int(hit.get("target_hp", -1)) == 0 and int(after["hp"]) == 0
			and bool(after["hanging"]) and not bool(after["lost"]),
			"AC3: a real lethal non-tearing hit still enters Hanging by a Thread")
		var torn := _torn_slots(after)
		_check(torn.size() == 1 and LIMBS.has(str(torn[0]))
			and not bool(after["parts"]["torso"]["torn"])
			and bool(tear.get("ok", false)) and str(tear.get("slot")) == str(torn[0])
			and tear == {"ok": true, "action": "tear", "hero": "warden",
				"slot": str(torn[0]), "part": str(before["parts"][torn[0]]["id"])},
			"AC3: Hanging still tears exactly one seeded non-torso seam, never the torso")
		for other in b.get_heroes():
			if str(other["id"]) != "warden":
				_check(int(other["fray"]) == 8,
					"AC3: Hanging still frays every surviving ally by eight")
		_check(b.satchel().is_empty(), "AC3: first Hanging still stores no satchel parts")
		break
	_check(witnessed, "AC3: non-vacuous real lethal Ragling witness for Hanging preservation")
