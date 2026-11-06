extends SceneTree
## Canonical Horn Charge through the same loader and rules used by live Stitched battles.

const TOUGH := "res://data/enemies/v3_tough_normals.json"
const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const CHARGE := {
	"id": "horn_charge", "name": "Horn Charge", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [4, 6], "crit": 0, "effects": {"push": 1, "fray": 5},
	"self_move": 0, "move": "attack2",
}
const HURL := {
	"id": "yarn_hurl", "name": "Yarn Hurl", "kind": "ranged",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [2, 3], "crit": 0, "effects": {"tangled": 1},
	"self_move": 0, "move": "attack3",
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(catalog.get("ok", false), "AC1: real enemy/part catalog validates")
	_test_sources(catalog)
	if catalog.get("ok", false):
		var witnesses := {"hit": 0, "miss": 0, "blocked": 0, "crit": 0, "ordinary_hit": 0}
		for seed_value in range(1, 33):
			for blocked in [false, true]:
				var first := _charge_script(catalog, seed_value, blocked, witnesses)
				var replay := _charge_script(catalog, seed_value, blocked, {})
				_check(not first.is_empty() and first == replay,
					"AC4: complete receipts, ranks, state and final RNG replay identically")
		for key in witnesses:
			_check(witnesses[key] > 0, "non-vacuous seeded witness: " + key)
		_test_invalid_launch(catalog)
	if failures.is_empty():
		print("stitched_s5_spindle_ram_charge_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_spindle_ram_charge_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _record(path: String, enemy_id: String) -> Dictionary:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(records is Array, "AC1: source is an array: " + path)
	if not records is Array:
		return {}
	var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == enemy_id)
	_check(matches.size() == 1, "AC1: exactly one source record for " + enemy_id)
	return matches[0] if matches.size() == 1 else {}


func _test_sources(catalog: Dictionary) -> void:
	var ram := _record(TOUGH, "spindle_ram")
	_check(not ram.is_empty() and ram == _record(RUN, "spindle_ram"), "AC1: complete duplicate ram records match")
	var wraith := _record(TOUGH, "razor_ribbon_wraith")
	_check(not wraith.is_empty() and wraith == _record(RUN, "razor_ribbon_wraith"), "AC1: duplicate wraith remains identical")
	var legacy := {
		"target": "front", "actions": [
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "block", "amount": 7, "weight": 2},
			{"type": "attack", "amount": 8, "weight": 3},
			{"type": "attack", "amount": 7, "hits": 2, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 9, "move": "attack3", "weight": 1},
		],
	}
	_check(ram.get("name") == "Spindle Ram" and ram.get("max_hp") == 30
		and ram.get("charge") == true and ram.get("intent") == JSON.parse_string(JSON.stringify(legacy))
		and ram.get("art_path") == "res://assets/paper/enemies/spindle_ram.png",
		"AC1: name, legacy HP, charge, art and all five legacy actions stay exact")
	var expected := {"max_hp": 30, "speed": 4, "dodge": 3, "acc": 0, "prot": 6,
		"is_boss": false, "turns_per_round": 1, "trophy": "spindle_ram_horn", "abilities": [CHARGE, HURL]}
	_check(ram.get("stitched") == JSON.parse_string(JSON.stringify(expected)),
		"AC1: exact authored profile, Horn Charge and unchanged Yarn Hurl")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "spindle_ram")
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, "spindle_ram") == "spindle_ram_horn",
		"AC1: canonical legal foe and trophy are available")
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected[key], "AC1: loaded stat " + key)
	var normalized: Array = []
	for ability in [CHARGE, HURL]:
		var validated := StitchedParts.validate_ability(ability)
		_check(validated.get("ok", false), "AC1: independent expected ability validates")
		if validated.get("ok", false):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized, "AC1: loader exposes the exact normalized legal kit")


func _battle(catalog: Dictionary, seed_value: int, rear_ram: bool = false) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(preview is Dictionary, "real hero/part preview document exists")
	if not preview is Dictionary:
		return null
	var ids := ["spindle_ram", "scissor_crab"]
	if rear_ram:
		ids = ["scissor_crab", "moth_scribe", "spindle_ram"]
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, enemy_id)
		_check(not foe.is_empty() and catalog["enemies"][enemy_id]["tier"] == "normal",
			"real distinct legal normal foe: " + enemy_id)
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
		and battle.candle() == 100 and battle.thread_cuts().is_empty(), "healthy party/normal foe/candle preconditions")
	for hero in battle.get_heroes():
		_check(hero["hp"] == hero["max_hp"] and hero["hp"] > 9 and hero["fray"] == 0
			and hero["statuses"].is_empty(), "real healthy untangled hero with no starting fray")
	return battle


func _reach_ram(battle: StitchedRules, receipts: Array) -> bool:
	for step in range(12):
		if battle.current_actor_id() == "spindle_ram":
			return true
		var receipt := battle.pass_turn()
		_check(receipt.get("ok", false), "advance other real turns by legal pass")
		receipts.append(receipt)
	_check(false, "must reach the ram's real turn")
	return false


func _charge_script(catalog: Dictionary, seed_value: int, blocked: bool, witnesses: Dictionary) -> Dictionary:
	var battle := _battle(catalog, seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _reach_ram(battle, receipts):
		return {}
	var front_id := str(battle.get_heroes()[0]["id"])
	if blocked:
		# Establish an authentic persistent cut using the public foe action, then pass to its next turn.
		var cut := battle.snip_thread(front_id)
		_check(cut.get("ok", false) and battle.thread_cuts().has(front_id), "AC3: public Snip establishes real cut")
		receipts.append(cut)
		if not _reach_ram(battle, receipts):
			return {}
	# Rejections cannot spend a turn or draw RNG, even with another valid move available.
	for rank in [2, 3, 4]:
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var rejected := battle.use_foe_ability("horn_charge", rank)
		_check(not rejected.get("ok", true) and rejected.get("error") == "no legal target in rank %d" % rank
			and snapshot == battle.state_snapshot() and rng == battle.rng_state(), "AC3: wrong target rejected without state/RNG/turn spend")
		receipts.append(rejected)
	var before := battle.get_heroes().duplicate(true)
	var actor := battle.get_unit("spindle_ram")
	_check(actor["rank"] == 1 and before[0]["rank"] == 1 and before[1]["rank"] == 2,
		"AC2: real front ram/front doll/adjacent swap partner")
	_check(before[0]["prot"] > 0, "AC2: real equipped front doll exercises nonzero PROT")
	var receipt := battle.use_foe_ability("horn_charge", 1)
	receipts.append(receipt)
	_check(receipt.get("ok", false) and receipt.get("actor") == "spindle_ram"
		and receipt.get("ability") == "horn_charge" and receipt.get("results", []).size() == 1,
		"AC2: canonical Horn Charge commits one real target receipt after rejections")
	if not receipt.get("ok", false) or receipt.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = receipt["results"][0]
	_check(hit["target"] == front_id and hit["target_rank"] == 1
		and hit["hit_chance"] == StitchedRules.hit_chance(86 + actor["acc"], StitchedRules.effective_dodge(before[0]), actor["miss_streak"])
		and hit["hit"] == (hit["roll"] <= hit["hit_chance"]), "AC2/3: actual authored ACC hit roll and front target")
	var after := battle.get_unit(front_id)
	if hit["hit"]:
		var bases: Array = [StitchedRules.crit_damage(6)] if hit["crit"] else [4, 5, 6]
		var damages: Array = []
		for base in bases:
			damages.append(StitchedRules.damage_after_modifiers(base, actor["statuses"], before[0]["statuses"], false, 0, before[0]["prot"]))
		_check(damages.has(hit["damage"]) and after["hp"] == before[0]["hp"] - hit["damage"]
			and hit["target_hp"] == after["hp"], "AC2: authored damage/critical consequences use actual PROT")
		var extra_fray := 10 if hit["crit"] else 0
		_check(hit.get("fray_event") == {"ok": true, "action": "fray", "actor": front_id,
			"before": before[0]["fray"] + extra_fray, "change": 5,
			"after": before[0]["fray"] + extra_fray + 5, "transition": ""}
			and after["fray"] == before[0]["fray"] + extra_fray + 5,
			"AC2: exact +5 authored fray, accounting separately for normal enemy critical fray")
		if blocked:
			_check(hit.get("shift") == {"ok": false, "reason": "thread cut blocks movement"},
				"AC3: hit/fray survive the exact cut-blocked shift refusal")
		else:
			_check(hit.get("shift") == {"ok": true, "from": 1, "to": 2, "swapped": before[1]["id"]},
				"AC2: real one-rank PUSH receipt swaps the adjacent doll")
		if not witnesses.is_empty():
			witnesses["blocked" if blocked else "hit"] += 1
			if hit["crit"]:
				witnesses["crit"] += 1
			elif not blocked:
				witnesses["ordinary_hit"] += 1
	else:
		_check(hit["damage"] == 0 and not hit["crit"] and hit["statuses"].is_empty()
			and not hit.has("shift") and not hit.has("fray_event") and hit["target_hp"] == before[0]["hp"],
			"AC3: natural seeded miss has no damage, fray or shift")
		if not witnesses.is_empty():
			witnesses["miss"] += 1
	for index in range(4):
		var old: Dictionary = before[index]
		var hero := battle.get_unit(old["id"])
		var expected_rank := int(old["rank"])
		if hit["hit"] and not blocked and index < 2:
			expected_rank = 2 if index == 0 else 1
		_check(hero["rank"] == expected_rank, "AC2/3: every doll has exactly the expected rank")
		if index != 0 or not hit["hit"]:
			_check(hero["hp"] == old["hp"] and hero["fray"] == old["fray"], "AC2/3: uninvolved/missed doll HP and fray unchanged")
	_check(battle.get_unit("spindle_ram")["rank"] == 1, "AC2: charge does not move the ram")
	return {"receipts": receipts, "heroes": battle.get_heroes().duplicate(true),
		"state": battle.state_snapshot(), "rng": battle.rng_state()}


func _test_invalid_launch(catalog: Dictionary) -> void:
	var battle := _battle(catalog, 71, true)
	if battle == null:
		return
	var receipts: Array = []
	if not _reach_ram(battle, receipts):
		return
	_check(battle.get_unit("spindle_ram")["rank"] == 3, "AC3: authentic ram in foe rank 3")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var rejected := battle.use_foe_ability("horn_charge", 1)
	_check(not rejected.get("ok", true) and rejected.get("error") == "ability cannot launch from rank 3"
		and before == battle.state_snapshot() and rng == battle.rng_state(), "AC3: invalid launch preserves complete state and RNG")
	var valid := battle.use_foe_ability("yarn_hurl", 1)
	_check(valid.get("ok", false) and valid.get("ability") == "yarn_hurl"
		and valid.get("results", []).size() == 1, "AC3: original turn still permits canonical Yarn Hurl from rank 3")
