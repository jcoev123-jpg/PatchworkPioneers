extends SceneTree
## Canonical Unpick Verdict through the same loader and rules used by live Stitched battles.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const SNIP := {
	"id": "bailiff_snip", "name": "Bailiff Snip", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [4, 6], "crit": 0, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack2",
}
const SEIZE := {
	"id": "seize_thread", "name": "Seize Thread", "kind": "debuff",
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [0, 0], "crit": 0, "effects": {"snip": 1},
	"self_move": 0, "move": "skill",
}
const UNPICK := {
	"id": "bailiff_unpick", "name": "Unpick Verdict", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [2, 3], "crit": 0, "effects": {"tear": 1},
	"self_move": 0, "move": "attack3",
}
const LIMBS := ["head", "arms", "legs"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(catalog.get("ok", false), "AC1: real enemy/part catalog validates")
	_test_source(catalog)
	if catalog.get("ok", false):
		var witnesses := {"tear": 0, "miss": 0, "refused_tear": 0, "rank1": 0, "rank2": 0}
		for seed_value in range(1, 33):
			for all_torn in [false, true]:
				var first := _unpick_script(catalog, seed_value, all_torn, witnesses)
				var replay := _unpick_script(catalog, seed_value, all_torn, {})
				_check(not first.is_empty() and first == replay,
					"AC4: complete receipts, parts, state and final RNG replay identically")
		for key in witnesses:
			_check(witnesses[key] > 0, "non-vacuous seeded witness: " + key)
		_test_invalid_launch(catalog)
		_test_intent(catalog)
	if failures.is_empty():
		print("stitched_s5_scissor_bailiff_unpick_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_scissor_bailiff_unpick_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_source(catalog: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITES))
	_check(records is Array, "AC1: elite source is an array")
	if not records is Array:
		return
	var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == "scissor_bailiff")
	_check(matches.size() == 1, "AC1: exactly one Scissor Bailiff record")
	if matches.size() != 1:
		return
	var bailiff: Dictionary = matches[0]
	var legacy := {
		"target": "front", "actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
			{"type": "attack", "amount": 9, "weight": 2},
			{"type": "attack", "amount": 8, "hits": 2, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
		],
	}
	_check(bailiff.get("name") == "Scissor Bailiff" and bailiff.get("max_hp") == 36
		and bailiff.get("bleed_on_attack") == true and bailiff.get("chew_block_on_attack") == true
		and bailiff.get("art_path") == "res://assets/paper/enemies/scissor_bailiff.png"
		and bailiff.get("intent") == JSON.parse_string(JSON.stringify(legacy)),
		"AC1: name, legacy HP, flags, art and all five legacy actions stay exact")
	var expected := {"max_hp": 36, "speed": 4, "dodge": 5, "acc": 0, "prot": 8, "is_boss": false,
		"turns_per_round": 1, "trophy": "scissor_bailiff_shears", "abilities": [SNIP, SEIZE, UNPICK]}
	_check(bailiff.get("stitched") == JSON.parse_string(JSON.stringify(expected)),
		"AC1: exact profile, unchanged Snip and Seize Thread, appended Unpick Verdict")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "scissor_bailiff")
	_check(not foe.is_empty() and catalog["enemies"]["scissor_bailiff"]["tier"] == "elite"
		and StitchedEnemyCatalog.trophy_for(catalog, "scissor_bailiff") == "scissor_bailiff_shears",
		"AC1: canonical legal elite foe and trophy are available")
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected[key], "AC1: loaded stat " + key)
	var normalized: Array = []
	for ability in [SNIP, SEIZE, UNPICK]:
		var validated := StitchedParts.validate_ability(ability)
		_check(validated.get("ok", false), "AC1: independent expected ability validates")
		if validated.get("ok", false):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized, "AC1: loader exposes the exact normalized legal kit")


func _battle(catalog: Dictionary, seed_value: int, ids: Array = ["scissor_bailiff", "scissor_crab"]) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(preview is Dictionary, "real hero/part preview document exists")
	if not preview is Dictionary:
		return null
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, enemy_id)
		_check(not foe.is_empty(), "real legal foe: " + enemy_id)
		foes.append(foe)
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"])
	var created := StitchedRules.create({"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview["heroes"].duplicate(true), "parts": parts, "foes": foes})
	_check(created.get("ok", false), "real catalog battle creates: " + str(created.get("error")))
	if not created.get("ok", false):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size()
		and battle.candle() == 100 and battle.satchel().is_empty(), "healthy party/foes/candle preconditions")
	for hero in battle.get_heroes():
		var untorn := true
		for slot in hero["parts"]:
			untorn = untorn and not hero["parts"][slot]["torn"]
		_check(hero["hp"] == hero["max_hp"] and hero["hp"] > 9 and untorn and hero["statuses"].is_empty(),
			"real healthy, fully stitched hero")
	return battle


func _reach(battle: StitchedRules, actor_id: String, receipts: Array) -> bool:
	for step in range(16):
		if battle.current_actor_id() == actor_id:
			return true
		var actor := battle.get_unit(battle.current_actor_id())
		# A turn that is not the Bailiff's cannot spend Unpick Verdict or touch state/RNG.
		if actor_id == "scissor_bailiff":
			var snapshot := battle.state_snapshot()
			var rng := battle.rng_state()
			var wrong := battle.use_foe_ability("bailiff_unpick", 1)
			var error := "it is not a foe turn" if actor["side"] == "hero" else "the foe has no ability bailiff_unpick"
			_check(not wrong.get("ok", true) and wrong.get("error") == error
				and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
				"AC3: wrong-side/wrong-foe Unpick rejected without state/RNG/turn spend")
			receipts.append(wrong)
		var receipt := battle.pass_turn()
		_check(receipt.get("ok", false), "advance other real turns by legal pass")
		receipts.append(receipt)
	_check(false, "must reach the real turn of " + actor_id)
	return false


func _torn_slots(hero: Dictionary) -> Array:
	var torn: Array = []
	for slot in hero["parts"]:
		if hero["parts"][slot]["torn"]:
			torn.append(slot)
	torn.sort()
	return torn


func _unpick_script(catalog: Dictionary, seed_value: int, all_torn: bool, witnesses: Dictionary) -> Dictionary:
	var battle := _battle(catalog, seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _reach(battle, "scissor_bailiff", receipts):
		return {}
	var target_rank := 1 + seed_value % 2
	var target_id := ""
	for hero in battle.get_heroes():
		if hero["rank"] == target_rank:
			target_id = str(hero["id"])
	_check(not target_id.is_empty(), "AC2: a real doll stands in target rank")
	if all_torn:
		# Authentic public elite tears (no turn spent) leave only the torso stitched.
		for step in range(3):
			var torn := battle.tear_part(target_id)
			_check(torn.get("ok", false) and torn.get("hero") == target_id, "AC3: public tear setup succeeds")
			receipts.append(torn)
		_check(_torn_slots(battle.get_unit(target_id)) == ["arms", "head", "legs"]
			and battle.current_actor_id() == "scissor_bailiff", "AC3: head/arms/legs torn on the Bailiff's own turn")
	for rank in [3, 4]:
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var rejected := battle.use_foe_ability("bailiff_unpick", rank)
		_check(not rejected.get("ok", true) and rejected.get("error") == "no legal target in rank %d" % rank
			and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
			"AC3: back-rank target rejected without state/RNG/turn spend")
		receipts.append(rejected)
	var before := battle.get_heroes().duplicate(true)
	var target_before: Dictionary = battle.get_unit(target_id)
	var actor := battle.get_unit("scissor_bailiff")
	_check(actor["rank"] == 1 and target_before["prot"] > 0, "AC2: front Bailiff against an armoured doll")
	var receipt := battle.use_foe_ability("bailiff_unpick", target_rank)
	receipts.append(receipt)
	_check(receipt.get("ok", false) and receipt.get("actor") == "scissor_bailiff"
		and receipt.get("ability") == "bailiff_unpick" and receipt.get("results", []).size() == 1,
		"AC2: canonical Unpick Verdict commits one real target receipt after rejections")
	if not receipt.get("ok", false) or receipt.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = receipt["results"][0]
	var acc := 88 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"])
	_check(hit["target"] == target_id and hit["target_rank"] == target_rank
		and hit["hit_chance"] == StitchedRules.hit_chance(acc, StitchedRules.effective_dodge(target_before), actor["miss_streak"])
		and hit["hit"] == (hit["roll"] <= hit["hit_chance"]), "AC2/3: actual authored ACC hit roll and chosen target")
	var after := battle.get_unit(target_id)
	if hit["hit"]:
		var bases: Array = [StitchedRules.crit_damage(3)] if hit["crit"] else [2, 3]
		var damages: Array = []
		for base in bases:
			var dealt := StitchedS1BEffects.enemy_damage(base + int(actor.get("dmg_bonus", 0)), battle.candle())
			damages.append(StitchedRules.damage_after_modifiers(dealt, actor["statuses"], target_before["statuses"],
				false, 0, target_before["prot"]))
		_check(damages.has(hit["damage"]) and after["hp"] == target_before["hp"] - hit["damage"]
			and hit["target_hp"] == after["hp"] and after["hp"] > 0, "AC2: authored 2-3 damage after PROT/crit/candle")
		_check(hit.has("enemy_crit_fray") == hit["crit"], "AC2: only a critical Unpick adds elite critical fray")
		var tear: Dictionary = hit.get("tear", {})
		if all_torn:
			_check(tear == {"ok": false, "action": "tear", "actor": target_id, "error": "no untorn non-torso part"},
				"AC3: fully unpicked doll returns the contained tear refusal")
			_check(_torn_slots(after) == ["arms", "head", "legs"] and not after["parts"]["torso"]["torn"],
				"AC3: refusal never tears the torso")
			if not witnesses.is_empty():
				witnesses["refused_tear"] += 1
		else:
			var torn := _torn_slots(after)
			_check(tear.get("ok", false) and torn.size() == 1 and torn[0] == tear.get("slot") and LIMBS.has(tear.get("slot"))
				and tear == {"ok": true, "action": "tear", "hero": target_id, "slot": tear.get("slot"),
					"part": str(target_before["parts"][tear.get("slot")]["id"])},
				"AC2: exactly one non-torso part torn with a matching receipt")
			if torn.size() == 1:
				_check_torn_part_refused(battle, target_id, str(after["parts"][torn[0]]["id"]), receipts)
			if not witnesses.is_empty():
				witnesses["tear"] += 1
				witnesses["rank%d" % target_rank] += 1
	else:
		_check(hit["damage"] == 0 and not hit["crit"] and hit["statuses"].is_empty() and not hit.has("tear")
			and hit["target_hp"] == target_before["hp"] and after["parts"] == target_before["parts"],
			"AC3: natural seeded miss has no damage and no tear")
		if not witnesses.is_empty():
			witnesses["miss"] += 1
	var lost_now := battle.get_unit(target_id)
	_check(not lost_now["lost"] and not hit["lost"] and not hit["hanging"] and battle.satchel().is_empty(),
		"AC3: a tear alone never makes satchel or LOST state")
	for old in before:
		if old["id"] != target_id:
			var hero := battle.get_unit(old["id"])
			_check(hero["hp"] == old["hp"] and hero["parts"] == old["parts"] and hero["rank"] == old["rank"],
				"AC2/3: uninvolved doll unchanged")
	return {"receipts": receipts, "heroes": battle.get_heroes().duplicate(true),
		"state": battle.state_snapshot(), "rng": battle.rng_state()}


func _check_torn_part_refused(battle: StitchedRules, hero_id: String, part_id: String, receipts: Array) -> void:
	for step in range(16):
		if battle.current_actor_id() == hero_id or battle.is_over():
			break
		receipts.append(battle.pass_turn())
	_check(battle.current_actor_id() == hero_id, "AC2: the torn doll reaches its own turn")
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var refused := battle.use_part(part_id, 1)
	_check(not refused.get("ok", true) and refused.get("error") == "part is torn"
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: the torn part's ability is refused without state/RNG/turn spend")
	receipts.append(refused)


func _test_invalid_launch(catalog: Dictionary) -> void:
	var battle := _battle(catalog, 71, ["scissor_crab", "moth_scribe", "scissor_bailiff"])
	if battle == null:
		return
	var receipts: Array = []
	if not _reach(battle, "scissor_bailiff", receipts):
		return
	_check(battle.get_unit("scissor_bailiff")["rank"] == 3, "AC3: authentic Bailiff in foe rank 3")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var rejected := battle.use_foe_ability("bailiff_unpick", 1)
	_check(not rejected.get("ok", true) and rejected.get("error") == "ability cannot launch from rank 3"
		and before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: invalid launch preserves complete state and RNG")
	var valid := battle.use_foe_ability("seize_thread", 1)
	_check(valid.get("ok", false) and valid.get("ability") == "seize_thread"
		and valid.get("results", []).size() == 1, "AC3: original turn still permits Seize Thread from rank 3")


func _intent_script(catalog: Dictionary, seed_value: int) -> Dictionary:
	var battle := _battle(catalog, seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	var intents: Array = []
	for expected_round in [1, 2, 3]:
		if not _reach(battle, "scissor_bailiff", receipts):
			return {}
		_check(battle.round_number() == expected_round, "AC4: the Bailiff's turn in round %d" % expected_round)
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit("scissor_bailiff"))
		_check(snapshot == battle.state_snapshot() and rng == battle.rng_state(), "AC4: projection never mutates state or RNG")
		intents.append(intent)
		if expected_round < 3:
			receipts.append(battle.pass_turn())
	var verdict: Dictionary = intents[2]
	_check(intents[0].get("ability_id") == "bailiff_snip" and intents[1].get("ability_id") == "seize_thread",
		"AC4: earlier rounds keep the original action rotation")
	_check(verdict.get("ability_id") == "bailiff_unpick" and verdict.get("ability_name") == "Unpick Verdict"
		and verdict.get("ability_kind") == "melee" and not verdict.get("pass", true)
		and verdict.get("target_rank") == 1 and verdict.get("target_side") == "hero"
		and verdict.get("base_acc") == 88 and verdict.get("base_damage") == [2, 3]
		and verdict.get("base_effects") == {"tear": 1}, "AC4: round 3 predicts the authored Unpick Verdict")
	verdict["base_effects"]["tear"] = 9
	var again := StitchedFoeIntent.choose(battle, battle.get_unit("scissor_bailiff"))
	_check(again.get("base_effects") == {"tear": 1}, "AC4: editing a projection cannot edit the live ability")
	return {"receipts": receipts, "intents": intents, "state": battle.state_snapshot(), "rng": battle.rng_state()}


func _test_intent(catalog: Dictionary) -> void:
	for seed_value in [3, 17]:
		var first := _intent_script(catalog, seed_value)
		var replay := _intent_script(catalog, seed_value)
		_check(not first.is_empty() and first == replay, "AC4: intent projections replay identically")
