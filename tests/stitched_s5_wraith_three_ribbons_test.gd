extends SceneTree
## Real catalog -> equipped preview party -> public seeded combat and intent contracts.

const WRAITH := "razor_ribbon_wraith"
const CUT := {
	"id": "ribbon_cut", "name": "Ribbon Cut", "kind": "melee",
	"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "enemy", "multi": true,
	"acc": 88, "dmg": [2, 3], "crit": 0, "effects": {"bleed": 1},
	"self_move": 0, "move": "attack2",
}
const WAIL := {
	"id": "wraith_wail", "name": "Wraith Wail", "kind": "debuff",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": false,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"fray": 8},
	"self_move": 0, "move": "skill",
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(catalog.get("ok", false), "AC1: canonical catalog loads")
	_test_sources(catalog)
	if catalog.get("ok", false):
		var witnesses := {"hit": 0, "miss": 0, "tick_prot": 0, "wail_hit": 0}
		for seed_value in range(1, 13):
			for rank in [1, 2, 3]:
				var first := _sweep(catalog, seed_value, rank, witnesses)
				if seed_value <= 3:
					_check(not first.is_empty() and first == _sweep(catalog, seed_value, rank, {}),
						"AC4: same seeds/choices replay order, receipts, state and RNG")
			_test_wail(catalog, seed_value, witnesses)
		for witness in witnesses:
			_check(witnesses[witness] > 0, "non-vacuous seeded witness: " + witness)
		_test_rear_launch(catalog)
		_test_dead_wraith(catalog)
		_test_no_targets(catalog)
	for failure in failures:
		printerr(failure)
	print("stitched_s5_wraith_three_ribbons_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _record(path: String) -> Dictionary:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(records is Array, "AC1: canonical source is an array")
	if not records is Array:
		return {}
	var matches: Array = records.filter(func(r: Dictionary) -> bool: return r.get("id") == WRAITH)
	_check(matches.size() == 1, "AC1: exactly one Wraith per source")
	return matches[0] if matches.size() == 1 else {}


func _test_sources(catalog: Dictionary) -> void:
	var raw := _record("res://data/enemies/run_enemies.json")
	_check(not raw.is_empty() and raw == _record("res://data/enemies/v3_tough_normals.json"),
		"AC1: complete raw duplicate records match")
	var expected := {
		"id": WRAITH, "name": "Razor Ribbon Wraith", "max_hp": 27, "revive_once": true,
		"art_path": "res://assets/paper/enemies/razor_ribbon_wraith.png",
		"intent": {"target": "lowest_living_hp", "actions": [
			{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
			{"type": "debuff", "status": "exposed", "amount": 1, "weight": 1},
			{"type": "attack", "amount": 9, "weight": 3},
			{"type": "attack", "amount": 8, "hits": 2, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack3", "weight": 1},
		]},
		"stitched": {"max_hp": 27, "speed": 7, "dodge": 9, "acc": 0, "prot": 0,
			"is_boss": false, "turns_per_round": 1, "trophy": WRAITH + "_ribbon",
			"abilities": [CUT, WAIL]},
	}
	_check(raw == JSON.parse_string(JSON.stringify(expected)),
		"AC1: exact Wraith record preserves legacy fields, stats, Wail and pose")
	var foe := StitchedEnemyCatalog.foe_for(catalog, WRAITH)
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, WRAITH) == WRAITH + "_ribbon",
		"AC1: real foe and unchanged trophy resolve")
	var normalized: Array = []
	for authored in [CUT, WAIL]:
		var valid := StitchedParts.validate_ability(authored)
		_check(valid.get("ok", false), "AC1: independent exact expected ability validates")
		if valid.get("ok", false):
			normalized.append(valid["ability"])
	_check(foe.get("abilities") == normalized, "AC1: loaded kit has exact ACC, damage, effects and poses")
	if normalized.size() == 2:
		for rank in range(0, 6):
			for mask in ["launch_mask", "target_mask"]:
				_check(StitchedParts.ranks_allowed(normalized[0][mask], rank) == (rank in [1, 2, 3]),
					"AC2: Ribbon Cut enumerates only ranks 1/2/3: " + mask)


func _battle(catalog: Dictionary, seed_value: int, rank: int = 1) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/stitched/s2_preview.json"))
	_check(preview is Dictionary, "real equipped four-hero preview exists")
	if not preview is Dictionary:
		return null
	var ids := [WRAITH, "scissor_crab"]
	if rank == 2:
		ids = ["scissor_crab", WRAITH]
	elif rank == 3:
		ids = ["scissor_crab", "moth_scribe", WRAITH]
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, enemy_id)
		_check(not foe.is_empty() and catalog["enemies"][enemy_id]["tier"] == "normal",
			"real distinct normal foe resolves: " + enemy_id)
		foes.append(foe)
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"])
	var created := StitchedRules.create({"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview["heroes"].duplicate(true), "parts": parts, "foes": foes})
	_check(created.get("ok", false), "AC2: real 4v2/3 seeded battle creates")
	if not created.get("ok", false):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size()
		and battle.get_unit(WRAITH)["rank"] == rank, "AC2: genuine occupied ranks")
	for hero in battle.get_heroes():
		_check(hero["hp"] == hero["max_hp"] and hero["hp"] > 9 and hero["statuses"].is_empty(),
			"healthy unmodified equipped preview doll")
	return battle


func _reach(battle: StitchedRules, actor: String, receipts: Array) -> bool:
	for step in range(20):
		if battle.current_actor_id() == actor:
			return true
		if battle.is_over():
			break
		var receipt := battle.pass_turn()
		_check(receipt.get("ok", false), "lawful pass to requested actor")
		receipts.append(receipt)
	_check(false, "must reach real actor turn: " + actor)
	return false


func _refuse(battle: StitchedRules, rank: int, receipts: Array) -> void:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var prior := receipts.duplicate(true)
	var rejected := battle.use_foe_ability("ribbon_cut", rank)
	_check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty()
		and before == battle.state_snapshot() and rng == battle.rng_state() and prior == receipts,
		"AC4: refusal preserves all state, actor, turn, prior receipts and RNG")
	receipts.append(rejected)


func _intent(battle: StitchedRules) -> Dictionary:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(WRAITH))
	_check(before == battle.state_snapshot() and rng == battle.rng_state(), "AC4: real intent is display-only")
	return intent


func _sweep(catalog: Dictionary, seed_value: int, rank: int, witnesses: Dictionary) -> Dictionary:
	var battle := _battle(catalog, seed_value, rank)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _reach(battle, WRAITH, receipts):
		return {}
	_check(battle.round_number() == 1, "AC4: next-Ribbon-Cut round reached")
	var intent := _intent(battle)
	_check(intent.get("ability_id") == "ribbon_cut" and intent.get("multi") == true
		and intent.get("affected_ranks") == [1, 2, 3] and intent.get("base_damage") == [2, 3]
		and intent.get("base_effects") == {"bleed": 1}, "AC4: genuine three-rank authored threat")
	for invalid_rank in [0, 4, 5]:
		_refuse(battle, invalid_rank, receipts)
	var before := battle.get_heroes().duplicate(true)
	var actor := battle.get_unit(WRAITH)
	var receipt := battle.use_foe_ability("ribbon_cut", 1 + seed_value % 3)
	receipts.append(receipt)
	_check(receipt.get("ok", false) and receipt.get("actor") == WRAITH
		and receipt.get("ability") == "ribbon_cut" and receipt.get("results", []).size() == 3,
		"AC2: one committed sweep has exactly three independent target receipts")
	if not receipt.get("ok", false) or receipt.get("results", []).size() != 3:
		return {}
	var seen: Array = []
	var landed: Dictionary = {}
	var streak := int(actor["miss_streak"])
	for result in receipt["results"]:
		var old: Dictionary = {}
		for hero in before:
			if hero["id"] == result["target"]:
				old = hero
		_check(not old.is_empty() and old.get("rank") in [1, 2, 3]
			and not seen.has(result["target"]) and result["target_rank"] == old.get("rank"),
			"AC2: each legally occupied front doll is processed once")
		if old.is_empty():
			continue
		seen.append(result["target"])
		_check(result["hit_chance"] == StitchedRules.hit_chance(88 + actor["acc"],
			StitchedRules.effective_dodge(old), streak)
			and result["hit"] == (result["roll"] <= result["hit_chance"]),
			"AC3: independent seeded ACC/DODGE hit test")
		streak = 0 if result["hit"] else streak + 1
		if result["hit"]:
			var bases: Array = [StitchedRules.crit_damage(3)] if result["crit"] else [2, 3]
			var damages: Array = []
			for base in bases:
				damages.append(StitchedRules.damage_after_modifiers(base, actor["statuses"],
					old["statuses"], false, 0, old["prot"]))
			_check(damages.has(result["damage"]) and result["target_hp"] == old["hp"] - result["damage"]
				and result["statuses"] == [{"status": "bleed", "duration": 1}],
				"AC3: hit rolls authored 2-3/crit through PROT and applies only Bleed 1")
			landed[result["target"]] = true
		else:
			_check(result["damage"] == 0 and not result["crit"] and result["statuses"].is_empty()
				and result["target_hp"] == old["hp"], "AC3: natural miss has no damage or statuses")
		if not witnesses.is_empty():
			witnesses["hit" if result["hit"] else "miss"] += 1
	# Actions enter the next actor's turn immediately; its Bleed may already have ticked.
	for old in before:
		var hero := battle.get_unit(old["id"])
		if old["rank"] == 4:
			_check(hero == old and not seen.has(old["id"]), "AC2: fourth doll remains entirely untouched")
			continue
		var result: Dictionary = receipt["results"][seen.find(old["id"])]
		var ticked: bool = landed.has(old["id"]) and battle.current_actor_id() == old["id"]
		_check(hero["hp"] == result["target_hp"] - (1 if ticked else 0)
			and int(hero["statuses"].get("bleed", 0)) == (1 if landed.has(old["id"]) and not ticked else 0)
			and hero["rank"] == old["rank"], "AC3: every doll's actual post-sweep HP/status/rank agrees")
	# Continue through one own turn of every hit victim, including the protected front doll.
	for old in before:
		if not landed.has(old["id"]):
			continue
		if not _reach(battle, old["id"], receipts):
			return {}
		var hero := battle.get_unit(old["id"])
		var result: Dictionary = receipt["results"][seen.find(old["id"])]
		_check(hero["hp"] == result["target_hp"] - 1 and not hero["statuses"].has("bleed")
			and hero["prot"] == old["prot"], "AC3: Bleed 1 persists until own turn then ticks unmitigated")
		if old["prot"] > 0 and not witnesses.is_empty():
			witnesses["tick_prot"] += 1
	return {"receipts": receipts, "state": battle.state_snapshot(), "rng": battle.rng_state()}


func _test_wail(catalog: Dictionary, seed_value: int, witnesses: Dictionary) -> void:
	var battle := _battle(catalog, seed_value)
	if battle == null:
		return
	var receipts: Array = []
	if not _reach(battle, WRAITH, receipts):
		return
	var before := battle.get_heroes().duplicate(true)
	var cast := battle.use_foe_ability("wraith_wail", 4)
	_check(cast.get("ok", false) and cast.get("results", []).size() == 1, "AC3: unchanged Wail stays single-target")
	if not cast.get("ok", false) or cast.get("results", []).size() != 1:
		return
	var hit: Dictionary = cast["results"][0]
	_check(hit["target"] == before[3]["id"] and hit["damage"] == 0, "AC3: Wail still reaches fourth doll without damage")
	for old in before:
		var hero := battle.get_unit(old["id"])
		var fray := 8 if old["rank"] == 4 and hit["hit"] else 0
		_check(hero["hp"] == old["hp"] and hero["fray"] == old["fray"] + fray
			and hero["statuses"].is_empty(), "AC3: only confirmed Wail target gains exactly Fray 8")
	if hit["hit"]:
		witnesses["wail_hit"] += 1


func _test_rear_launch(catalog: Dictionary) -> void:
	var battle := _battle(catalog, 1, 3)
	if battle == null:
		return
	var receipts: Array = []
	if not _reach(battle, WRAITH, receipts):
		return
	# Negative-only sparse formation, as in existing rank-four foe regressions:
	# reposition the existing third foe; never add a fourth starting enemy or force a hit.
	# All actions and projections under test still use the public battle interfaces.
	battle._units[WRAITH]["rank"] = 4
	_check(battle.get_foes().size() == 3 and battle.get_unit(WRAITH)["rank"] == 4,
		"AC4: same genuine Wraith occupies rank 4 with no invented extra foe")
	_refuse(battle, 1, receipts)
	_check(_intent(battle).get("ability_id") == "wraith_wail", "AC4: rear Wraith projects legal Wail, never Cut")


func _test_dead_wraith(catalog: Dictionary) -> void:
	var battle := _battle(catalog, 2)
	if battle == null:
		return
	var receipts: Array = []
	if not _reach(battle, "warden", receipts):
		return
	_refuse(battle, 1, receipts) # Wrong-side actor cannot use the foe kit.
	for step in range(180):
		if battle.get_unit(WRAITH)["hp"] <= 0:
			break
		var actor := battle.get_unit(battle.current_actor_id())
		var action: Dictionary
		if actor["side"] == "hero":
			action = battle.use_part(str(actor["parts"]["head"]["id"]), 1)
			if not action.get("ok", false):
				action = battle.pass_turn()
		else:
			action = battle.pass_turn()
		receipts.append(action)
	_check(battle.get_unit(WRAITH)["hp"] == 0 and battle.get_unit(WRAITH)["dead"],
		"AC4: real equipped hero attacks kill canonical Wraith")
	_check(battle.get_heaps().any(func(h: Dictionary) -> bool: return h["rank"] == 1),
		"AC4: genuine Wraith death leaves rank-blocking scrap")
	_check(_intent(battle).is_empty(), "AC4: dead Wraith has no phantom intent")
	_refuse(battle, 1, receipts)
	_check(StitchedFoeIntent.choose(battle, {"id": "absent_wraith", "rank": 5}).is_empty(),
		"AC4: nonexistent foe/rank cannot project an intent")


func _test_no_targets(catalog: Dictionary) -> void:
	var battle := _battle(catalog, 7)
	if battle == null:
		return
	var receipts: Array = []
	var witnessed := false
	for step in range(1200):
		if battle.is_over():
			break
		if battle.current_actor_id() == WRAITH:
			var alive_front := battle.get_heroes().filter(func(h: Dictionary) -> bool:
				return h["rank"] in [1, 2, 3] and not h["lost"])
			if alive_front.is_empty():
				_refuse(battle, 1, receipts)
				_check(_intent(battle).get("ability_id") == "wraith_wail",
					"AC4: no occupied legal Cut targets falls back to reachable Wail")
				witnessed = true
				break
			var cut := battle.use_foe_ability("ribbon_cut", 1)
			if not cut.get("ok", false):
				cut = battle.pass_turn()
			receipts.append(cut)
		else:
			receipts.append(battle.pass_turn())
	_check(witnessed, "AC4: real repeated sweeps remove all front targets while fourth doll survives")
