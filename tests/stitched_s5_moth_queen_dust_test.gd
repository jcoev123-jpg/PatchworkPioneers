extends SceneTree
## Canonical Queen Dust (multi-target Weak + Blind) through the same loader and rules used by live Stitched battles.

const BOSSES := "res://data/enemies/boss.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const DUST := {
	"id": "queen_dust", "name": "Queen Dust", "kind": "ranged",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 85, "dmg": [3, 5], "crit": 0, "effects": {"weak": 1, "blind": 1},
	"self_move": 0, "move": "attack2",
}
const DIVE := {
	"id": "queen_dive", "name": "Pin Crown Dive", "kind": "melee",
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [6, 8], "crit": 0, "effects": {},
	"self_move": 0, "move": "attack3",
}
const DEVOUR := {
	"id": "queen_devour", "name": "Devour", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [7, 9], "crit": 0, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack4",
}
const VEIL := {
	"id": "moth_veil", "name": "Moth Veil", "kind": "buff",
	"launch": [1, 3], "target": [1, 2, 3, 4], "target_side": "ally", "multi": true,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"dodge": 8, "duration": 1},
	"self_move": 0, "move": "skill",
}
const LEGACY := {
	"target": "front", "actions": [
		{"type": "attack", "amount": 5, "weight": 4},
		{"type": "summon", "amount": 0, "weight": 2},
		{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 9, "move": "attack3", "weight": 1},
		{"type": "attack", "amount": 10, "move": "attack4", "weight": 1},
	],
}
const FOES := ["moth_queen", "ragling", "ragling_guard"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(catalog.get("ok", false), "AC1: real enemy/part catalog validates")
	_test_source(catalog)
	if catalog.get("ok", false):
		var witnesses := {"hit": 0, "miss": 0, "blind_miss": 0, "rank4_hit": 0}
		for seed_value in range(1, 25):
			var first := _dust_script(catalog, seed_value, witnesses)
			var replay := _dust_script(catalog, seed_value, {})
			_check(not first.is_empty() and first == replay,
				"AC4: complete receipts, turn order, statuses, state and final RNG replay identically")
		for key in witnesses:
			_check(witnesses[key] > 0, "non-vacuous seeded witness: " + key)
		_test_invalid_launch(catalog)
		_test_intent(catalog)
	if failures.is_empty():
		print("stitched_s5_moth_queen_dust_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_moth_queen_dust_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_source(catalog: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSSES))
	_check(records is Array, "AC1: boss source is an array")
	if not records is Array:
		return
	var ids: Array = []
	for record in records:
		ids.append(record.get("id"))
	_check(ids == ["patchwork_behemoth", "sewing_machine_colossus", "moth_queen"], "AC4: the three boss ids stay")
	var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == "moth_queen")
	_check(matches.size() == 1, "AC1: exactly one Moth Queen record")
	if matches.size() != 1:
		return
	var queen: Dictionary = matches[0]
	_check(queen.get("name") == "Moth Queen" and queen.get("max_hp") == 90
		and queen.get("art_path") == "res://assets/paper/enemies/moth_queen.png"
		and queen.get("intent") == JSON.parse_string(JSON.stringify(LEGACY)),
		"AC1: name, legacy HP, art and all five legacy actions stay exact")
	var expected := {"max_hp": 90, "speed": 6, "dodge": 10, "acc": 0, "prot": 4, "is_boss": true,
		"turns_per_round": 2, "trophy": "moth_queen_wing_crown", "abilities": [DUST, DIVE, DEVOUR, VEIL]}
	_check(queen.get("stitched") == JSON.parse_string(JSON.stringify(expected)),
		"AC1: exact profile; Queen Dust is multi with Weak+Blind, other three moves unchanged")
	_check(ResourceLoader.exists("res://assets/paper/enemies/moth_queen.png")
		and ResourceLoader.exists("res://assets/paper/stitched/icons/status_blind.png"),
		"AC4: existing Queen sprite and Blind icon carry the move (no new art)")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "moth_queen")
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, "moth_queen") == "moth_queen_wing_crown",
		"AC1: canonical legal boss foe and trophy are available")
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected[key], "AC1: loaded stat " + key)
	var normalized: Array = []
	for ability in [DUST, DIVE, DEVOUR, VEIL]:
		var validated := StitchedParts.validate_ability(ability)
		_check(validated.get("ok", false), "AC1: independent expected ability validates")
		if validated.get("ok", false):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized, "AC1: loader exposes the exact normalized legal kit")
	for boss_id in ["patchwork_behemoth", "sewing_machine_colossus"]:
		_check(not StitchedEnemyCatalog.foe_for(catalog, boss_id).is_empty(), "AC4: other boss still loads: " + boss_id)


func _battle(catalog: Dictionary, seed_value: int, ids: Array = FOES) -> StitchedRules:
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
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size(),
		"four dolls against two or three starting foes")
	var queen_turns := 0
	for entry in battle.turn_order():
		if str(entry) == "moth_queen":
			queen_turns += 1
	_check(queen_turns == 2, "AC4: Moth Queen keeps two boss turns in the rolled order")
	for hero in battle.get_heroes():
		_check(hero["hp"] == hero["max_hp"] and hero["statuses"].is_empty(), "real healthy hero without statuses")
	return battle


func _reach(battle: StitchedRules, actor_id: String, receipts: Array) -> bool:
	for step in range(16):
		if battle.is_over():
			break
		if battle.current_actor_id() == actor_id:
			return true
		var actor := battle.get_unit(battle.current_actor_id())
		if actor_id == "moth_queen":
			# A turn that is not the Queen's cannot spend Queen Dust or touch state/RNG.
			var snapshot := battle.state_snapshot()
			var rng := battle.rng_state()
			var wrong := battle.use_foe_ability("queen_dust", 1)
			var error := "it is not a foe turn" if actor["side"] == "hero" else "the foe has no ability queen_dust"
			_check(not wrong.get("ok", true) and wrong.get("error") == error
				and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
				"AC3: wrong-side/wrong-foe Queen Dust rejected without state/RNG/turn spend")
			receipts.append(wrong)
		var receipt := battle.pass_turn()
		_check(receipt.get("ok", false), "advance other real turns by legal pass")
		receipts.append(receipt)
	_check(false, "must reach the real turn of " + actor_id)
	return false


func _dust_script(catalog: Dictionary, seed_value: int, witnesses: Dictionary) -> Dictionary:
	var battle := _battle(catalog, seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _reach(battle, "moth_queen", receipts):
		return {}
	var actor := battle.get_unit("moth_queen")
	_check(actor["rank"] == 1, "AC2: Queen launches from foe rank 1")
	for rank in [0, 5]:
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var rejected := battle.use_foe_ability("queen_dust", rank)
		_check(not rejected.get("ok", true) and rejected.get("error") == "no legal target in rank %d" % rank
			and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
			"AC3: illegal target rank rejected without state/RNG/turn spend")
		receipts.append(rejected)
	var before := battle.get_heroes().duplicate(true)
	# Any legal rank picks the whole party: the chosen rank only names where the dust is aimed.
	var receipt := battle.use_foe_ability("queen_dust", 1 + seed_value % 4)
	receipts.append(receipt)
	_check(receipt.get("ok", false) and receipt.get("actor") == "moth_queen"
		and receipt.get("ability") == "queen_dust" and receipt.get("results", []).size() == 4,
		"AC2: one Queen Dust resolves once for each of the four occupied hero ranks")
	if not receipt.get("ok", false) or receipt.get("results", []).size() != 4:
		return {}
	var ranks: Array = []
	var acc := 85 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"])
	var blinded_id := ""
	var clear_id := ""
	for result in receipt["results"]:
		ranks.append(result["target_rank"])
		var old: Dictionary = {}
		for hero in before:
			if hero["id"] == result["target"]:
				old = hero
		var now := battle.get_unit(str(result["target"]))
		_check(not old.is_empty() and old["rank"] == result["target_rank"], "AC2: receipt names the doll in that rank")
		_check(result["hit_chance"] == StitchedRules.hit_chance(acc, StitchedRules.effective_dodge(old), _streak_before(receipt, result))
			and result["hit"] == (result["roll"] <= result["hit_chance"]), "AC2: authored ACC 85 roll per target")
		if result["hit"]:
			var bases: Array = [StitchedRules.crit_damage(5)] if result["crit"] else [3, 4, 5]
			var damages: Array = []
			for base in bases:
				var dealt := StitchedS1BEffects.enemy_damage(base + int(actor.get("dmg_bonus", 0)), battle.candle())
				damages.append(StitchedRules.damage_after_modifiers(dealt, actor["statuses"], old["statuses"],
					false, 0, old["prot"]))
			_check(damages.has(result["damage"]) and now["hp"] == old["hp"] - result["damage"],
				"AC2: authored 3-5 damage after PROT/crit/candle")
			var applied: Array = []
			for status in result["statuses"]:
				applied.append([status["status"], status["duration"]])
			applied.sort()
			_check(applied == [["blind", 1], ["weak", 1]] and now["statuses"].get("weak") == 1
				and now["statuses"].get("blind") == 1, "AC2: a landed hit delivers Weak 1 and Blind 1")
			blinded_id = str(result["target"])
			if not witnesses.is_empty():
				witnesses["hit"] += 1
				if result["target_rank"] == 4:
					witnesses["rank4_hit"] += 1
		else:
			_check(result["damage"] == 0 and result["statuses"].is_empty() and now["hp"] == old["hp"]
				and not now["statuses"].has("weak") and not now["statuses"].has("blind"),
				"AC2: a missed doll receives no damage, Weak or Blind")
			clear_id = str(result["target"])
			if not witnesses.is_empty():
				witnesses["miss"] += 1
	ranks.sort()
	_check(ranks == [1, 2, 3, 4], "AC2: every occupied hero rank, including back rank 4, is targeted")
	if not blinded_id.is_empty():
		_check_blind_spent(battle, blinded_id, receipts, witnesses)
	if not clear_id.is_empty():
		_check(not battle.get_unit(clear_id)["statuses"].has("blind"), "AC3: an unhit doll never acquires Blind")
	return {"receipts": receipts, "order": battle.turn_order(), "heroes": battle.get_heroes().duplicate(true),
		"state": battle.state_snapshot(), "rng": battle.rng_state()}


## The Queen's miss streak as each target is rolled: her first action starts at 0, an earlier miss in the
## same dust cloud raises it by one and a hit resets it.
func _streak_before(receipt: Dictionary, result: Dictionary) -> int:
	var streak := 0
	for earlier in receipt["results"]:
		if earlier == result:
			break
		streak = 0 if earlier["hit"] else streak + 1
	return streak


## Advance to the Blinded doll's own turn and spend one legal offensive part: Blind forces the miss and is used up.
func _check_blind_spent(battle: StitchedRules, hero_id: String, receipts: Array, witnesses: Dictionary) -> void:
	for step in range(16):
		if battle.current_actor_id() == hero_id or battle.is_over():
			break
		receipts.append(battle.pass_turn())
	if battle.current_actor_id() != hero_id:
		_check(false, "AC3: the Blinded doll reaches its own turn")
		return
	var hero := battle.get_unit(hero_id)
	_check(hero["statuses"].get("blind") == 1, "AC3: Blind lasts until the doll's next attack")
	var attack := _offensive_part(battle, hero)
	if attack.is_empty():
		return
	var receipt := battle.use_part(attack["part"], attack["rank"])
	receipts.append(receipt)
	_check(receipt.get("ok", false) and receipt.get("action") != "refused" and receipt.get("results", []).size() >= 1,
		"AC3: the Blinded doll's legal part attack resolves")
	if not receipt.get("ok", false) or receipt.get("action") == "refused":
		return
	var first: Dictionary = receipt["results"][0]
	_check(first.get("blinded", false) and not first["hit"] and first["damage"] == 0 and not first.has("roll"),
		"AC3: Blind forces the next offensive attack to miss without a hit roll")
	_check(not battle.get_unit(hero_id)["statuses"].has("blind"), "AC3: the forced miss consumes Blind")
	if not witnesses.is_empty():
		witnesses["blind_miss"] += 1


func _offensive_part(battle: StitchedRules, hero: Dictionary) -> Dictionary:
	for slot in ["arms", "head", "legs", "torso"]:
		var equipped: Dictionary = hero["parts"][slot]
		if equipped["torn"]:
			continue
		var ability := StitchedParts.ability_at_tier(battle._parts[equipped["id"]], int(equipped["tier"]))
		if ability.is_empty() or ability["target_side"] != "enemy" or int(ability["dmg"][1]) <= 0 \
				or not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(hero["rank"])) \
				or not battle._self_move_gate(hero, ability).is_empty():
			continue
		for rank in range(1, 5):
			if not battle._legal_targets(hero, ability, rank).is_empty():
				return {"part": str(equipped["id"]), "rank": rank}
	return {}


func _test_invalid_launch(catalog: Dictionary) -> void:
	var battle := _battle(catalog, 71, ["ragling", "moth_queen"])
	if battle == null:
		return
	var receipts: Array = []
	if not _reach(battle, "moth_queen", receipts):
		return
	_check(battle.get_unit("moth_queen")["rank"] == 2, "AC3: authentic Queen in foe rank 2")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var rejected := battle.use_foe_ability("queen_dust", 1)
	_check(not rejected.get("ok", true) and rejected.get("error") == "ability cannot launch from rank 2"
		and before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: invalid launch preserves complete state and RNG")
	var valid := battle.use_foe_ability("queen_devour", 1)
	_check(valid.get("ok", false) and valid.get("ability") == "queen_devour" and valid.get("results", []).size() == 1,
		"AC3: original turn still permits Devour from rank 2")


func _test_intent(catalog: Dictionary) -> void:
	for seed_value in [3, 17]:
		var projections: Array = []
		for attempt in range(2):
			var battle := _battle(catalog, seed_value)
			if battle == null or not _reach(battle, "moth_queen", []):
				return
			var snapshot := battle.state_snapshot()
			var rng := battle.rng_state()
			var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
			_check(snapshot == battle.state_snapshot() and rng == battle.rng_state(), "AC4: projection never mutates state or RNG")
			_check(battle.round_number() == 1 and intent.get("ability_id") == "queen_dust"
				and intent.get("ability_name") == "Queen Dust" and intent.get("multi") == true
				and intent.get("affected_ranks") == [1, 2, 3, 4] and intent.get("target_side") == "hero"
				and intent.get("base_effects") == {"weak": 1, "blind": 1} and intent.get("base_damage") == [3, 5]
				and not intent.get("pass", true), "AC4: round 1 discloses Queen Dust's ranks, multi and Weak/Blind")
			projections.append(intent.duplicate(true))
			intent["base_effects"]["blind"] = 9
			_check(StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen")).get("base_effects")
				== {"weak": 1, "blind": 1}, "AC4: editing a projection cannot edit the live ability")
		_check(projections[0] == projections[1], "AC4: intent projections replay identically")
