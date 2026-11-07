extends SceneTree
## Queen Crown SNIP: canonical catalog, live foe chooser, true seeded hit/miss and turn actions.
const FOE_IDS := ["moth_queen", "ragling", "ragling_guard"]
const PREVIEW := "res://data/stitched/s2_preview.json"
const BOSS := "res://data/enemies/boss.json"
const EFFECTS := {"tangled": 2, "snip": 1}
var failures: Array[String] = []
var checks := 0
var recording := true
var catalog: Dictionary = {}
var preview: Dictionary = {}


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(catalog.get("ok", false) and parsed is Dictionary, "AC1: shipped catalog and equipped preview validate")
	if bool(catalog.get("ok", false)) and parsed is Dictionary:
		preview = parsed
		_contract()
		var hit_seed := 0
		var miss_seed := 0
		recording = false
		for seed_value in range(1, 97):
			var trace := _trace(seed_value, false)
			if trace.is_empty():
				continue
			if trace["hit"] and hit_seed == 0:
				hit_seed = seed_value
			if not trace["hit"] and miss_seed == 0:
				miss_seed = seed_value
			if hit_seed > 0 and miss_seed > 0:
				break
		recording = true
		_check(hit_seed > 0 and miss_seed > 0, "AC2/4: bounded naturally landed and missed crown witnesses")
		for seed_value in [hit_seed, miss_seed]:
			if seed_value <= 0:
				continue
			var first := _trace(seed_value, true)
			var replay := _trace(seed_value, true)
			_check(not first.is_empty() and first == replay,
				"AC4: genuine hit/miss inputs replay all receipts, full snapshot, order and RNG")
		if hit_seed > 0:
			_driver(hit_seed)
		var repeat_seed := 0
		recording = false
		for seed_value in range(1, 97):
			if not _repeat(seed_value).is_empty():
				repeat_seed = seed_value
				break
		recording = true
		_check(repeat_seed > 0, "AC4: bounded two-landed-dive witness without forced RNG")
		if repeat_seed > 0:
			var first := _repeat(repeat_seed)
			_check(not first.is_empty() and first == _repeat(repeat_seed),
				"AC4: second landing refuses duplicate cut and replays all state/RNG")
		_off_turn()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_moth_queen_crown_snip_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if recording:
		checks += 1
		if not condition:
			failures.append(message)


func _contract() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSS))
	_check(raw is Array, "AC1: canonical boss JSON is an array")
	if not raw is Array:
		return
	var queen: Dictionary = {}
	for boss in raw:
		if boss.get("id") == "moth_queen":
			queen = boss
	_check(not queen.is_empty(), "AC1: actual Moth Queen record exists")
	if queen.is_empty():
		return
	var abilities: Array = queen["stitched"]["abilities"]
	_check(abilities.size() == 4 and abilities[0]["id"] == "queen_dust"
		and abilities[1]["id"] == "queen_dive" and abilities[2]["id"] == "queen_devour"
		and abilities[3]["id"] == "moth_veil", "AC1: untouched four-action order")
	var dive: Dictionary = abilities[1]
	var expected_dive := {"id": "queen_dive", "name": "Pin Crown Dive", "kind": "melee",
		"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
		"acc": 85, "dmg": [6, 8], "crit": 0, "effects": EFFECTS,
		"self_move": 0, "move": "attack3"}
	_check(JSON.parse_string(JSON.stringify(dive)) == JSON.parse_string(JSON.stringify(expected_dive)),
		"AC1: exact sole Dive change adds SNIP 1 beside Tangled 2")
	_check(StitchedParts.validate_ability(dive).get("ok", false), "AC1: unchanged validator accepts SNIP 1")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "moth_queen")
	_check(foe.get("max_hp") == 90 and foe.get("turns_per_round") == 2
		and foe.get("is_boss") == true and foe.get("speed") == 6
		and foe.get("dodge") == 10 and foe.get("prot") == 4
		and StitchedEnemyCatalog.trophy_for(catalog, "moth_queen") == "moth_queen_wing_crown"
		and foe.get("abilities", [])[1].get("effects") == EFFECTS,
		"AC1/4: real loaded boss, foreign-part trophy and two-turn kit")


func _config(seed_value: int) -> Dictionary:
	var config := preview.duplicate(true)
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"])
	config["foes"] = []
	for enemy_id in FOE_IDS:
		config["foes"].append(StitchedEnemyCatalog.foe_for(catalog, enemy_id))
	return config


func _battle(seed_value: int) -> StitchedRules:
	var created := StitchedRules.create(_config(seed_value))
	_check(created.get("ok", false), "AC2: four-versus-three genuine seeded fight builds")
	if not created.get("ok", false):
		return null
	var b: StitchedRules = created["battle"]
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
		and b.turn_order().count("moth_queen") == 2 and b.candle() == 100
		and b.get_unit("warden").get("rank") == 1
		and b.get_unit("moth_queen").get("rank") == 1,
		"AC2: real four equipped dolls, three foe ranks, boss two turns, bright candle")
	return b


func _to(b: StitchedRules, actor_id: String, receipts: Array, wanted_round: int = 0) -> bool:
	for step in range(130):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id and (wanted_round == 0 or b.round_number() == wanted_round):
			return true
		if wanted_round > 0 and b.round_number() > wanted_round:
			return false
		var passed := b.pass_turn()
		if not passed.get("ok", false):
			return false
		receipts.append(passed)
	return false


func _refuse(b: StitchedRules, action: Callable, expected: String, receipts: Array) -> void:
	var snapshot := b.state_snapshot()
	var order := b.turn_order()
	var rng := b.rng_state()
	var actor := b.current_actor_id()
	var refused: Dictionary = action.call()
	receipts.append(refused)
	_check(not refused.get("ok", true) and refused.get("error") == expected
		and b.state_snapshot() == snapshot and b.turn_order() == order
		and b.rng_state() == rng and b.current_actor_id() == actor,
		"AC3/4: " + expected + " refuses without state, turn, order or RNG mutation")


func _trace(seed_value: int, deep: bool) -> Dictionary:
	var b := _battle(seed_value)
	var receipts: Array = []
	if b == null or not _to(b, "moth_queen", receipts, 2):
		return {}
	var front := b.get_unit("warden")
	var queen := b.get_unit("moth_queen")
	_check(front.get("rank") == 1 and front.get("hp", 0) > 16 and not front.get("hanging", true)
		and front.get("statuses", {}).is_empty() and queen.get("rank") == 1
		and b.thread_cuts().is_empty() and b.round_number() == 2,
		"AC2: first living front doll and legal rank-one Queen before any attack")
	var before_intent := b.state_snapshot()
	var rng_intent := b.rng_state()
	var intent := StitchedFoeIntent.choose(b, queen)
	_check(intent.get("ability_id") == "queen_dive" and intent.get("target_rank") == 1
		and intent.get("base_effects") == EFFECTS and intent.get("base_damage") == [6, 8]
		and intent.get("base_acc") == 85 and not intent.get("pass", true)
		and before_intent == b.state_snapshot() and rng_intent == b.rng_state(),
		"AC2/4: real round-two live driver advertises Dive with SNIP, without mutation")
	_check(StitchedFoeIntent.choose(b, {}).is_empty()
		and StitchedFoeIntent.choose(b, {"id": "not_a_foe"}).is_empty()
		and StitchedFoeIntent.choose(b, b.get_unit("warden")).is_empty()
		and before_intent == b.state_snapshot() and rng_intent == b.rng_state(),
		"AC4: missing/stale/hero foe projection is fail-closed")
	for rank in [0, 2, 3, 4, 5]:
		_refuse(b, func(): return b.use_foe_ability("queen_dive", rank),
			"no legal target in rank %d" % rank, receipts)
	var cast := b.use_foe_ability("queen_dive", 1)
	receipts.append(cast)
	_check(cast.get("ok", false) and cast.get("actor") == "moth_queen"
		and cast.get("ability") == "queen_dive" and cast.get("results", []).size() == 1,
		"AC2: real foe ability resolves exactly the targeted front doll")
	if not cast.get("ok", false) or cast.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = cast["results"][0]
	var after := b.get_unit("warden")
	var chance := StitchedRules.hit_chance(85 + int(queen["acc"]) +
		int(b.candle_band()["enemy_acc"]), StitchedRules.effective_dodge(front),
		int(queen["miss_streak"]))
	_check(hit.get("target") == "warden" and hit.get("target_rank") == 1
		and hit.get("hit_chance") == chance and hit.has("roll")
		and hit.get("hit") == (int(hit.get("roll", 101)) <= chance),
		"AC2/4: natural seeded hit or miss rolls against ACC 85 and real target DODGE")
	if hit.get("hit", false):
		var base_rolls: Array = [StitchedRules.crit_damage(8)] if hit["crit"] else [6, 7, 8]
		var possible: Array = []
		for base in base_rolls:
			var candle_damage := StitchedS1BEffects.enemy_damage(
				int(base) + int(queen.get("dmg_bonus", 0)), b.candle())
			possible.append(StitchedRules.damage_after_modifiers(candle_damage,
				queen["statuses"], front["statuses"], false, 0, int(front["prot"])))
		var remaining := 1 if b.current_actor_id() == "warden" else 2
		_check(possible.has(hit["damage"]) and int(hit["damage"]) > 0
			and hit["target_hp"] == int(front["hp"]) - int(hit["damage"])
			and after["hp"] == hit["target_hp"] and not after["hanging"]
			and hit.get("statuses") == [{"status": "tangled", "duration": 2}]
			and int(after["statuses"].get("tangled", 0)) == remaining
			and hit.get("snip", {}).get("ok") == true
			and hit.get("snip", {}).get("after_rank") == 1
			and b.thread_cuts() == {"warden": 1},
			"AC2: true hit deals real PROT/candle damage, Tangled 2 and exactly one front SNIP")
		if deep:
			if not _to(b, "lantern_monk", receipts):
				return {}
			_refuse(b, func(): return b.use_part("any_torso_felt_coat", 1),
				"no legal target in rank 1", receipts)
			# Still cut, even if Tangled has ticked: these are independent mechanics.
			_check(b.thread_cuts() == {"warden": 1}, "AC3: blocked cross-cut heal leaves the cut intact")
			receipts.append(b.pass_turn())
			if not _to(b, "warden", receipts):
				return {}
			var tangled_before := int(b.get_unit("warden")["statuses"].get("tangled", 0))
			_refuse(b, func(): return b.move(1),
				"a tangled hero cannot move" if tangled_before > 0 else "the snipped hero cannot move", receipts)
			var tied := b.re_tie()
			receipts.append(tied)
			_check(tied == {"ok": true, "action": "re_tie", "actor": "warden"}
				and b.thread_cuts().is_empty() and b.current_actor_id() != "warden"
				and int(b.get_unit("warden")["statuses"].get("tangled", 0)) <= tangled_before,
				"AC3: only snipped hero RE-TIEs on its turn, clears cut and keeps independent Tangled timing")
			if not _to(b, "lantern_monk", receipts):
				return {}
			var hp_before := int(b.get_unit("warden")["hp"])
			var healed := b.use_part("any_torso_felt_coat", 1)
			receipts.append(healed)
			_check(healed.get("ok", false) and healed.get("results", []).size() == 1
				and int(b.get_unit("warden")["hp"]) == mini(int(b.get_unit("warden")["max_hp"]), hp_before + 5),
				"AC3: same real ally heal crosses the repaired boundary legally")
			if not _to(b, "warden", receipts):
				return {}
			_check(not b.get_unit("warden")["statuses"].has("tangled"),
				"AC3: two separate start-of-own-turn ticks expire Tangled independently of RE-TIE")
			var moved := b.move(1)
			receipts.append(moved)
			_check(moved.get("ok", false) and moved.get("from") == 1
				and moved.get("to") == 2 and moved.get("swapped") == "seamstress"
				and b.thread_cuts().is_empty(),
				"AC3: ordinary legal cross-boundary move returns only after RE-TIE and Tangled expiry")
	else:
		_check(hit.get("damage") == 0 and hit.get("statuses") == []
			and not hit.has("snip") and b.thread_cuts().is_empty()
			and after["hp"] == front["hp"] and not after["statuses"].has("tangled"),
			"AC4: natural miss has no damage, Tangled, SNIP receipt or cut")
	return {"hit": hit["hit"], "receipts": receipts, "state": b.state_snapshot(),
		"order": b.turn_order(), "rng": b.rng_state(), "heroes": b.get_heroes()}


func _repeat(seed_value: int) -> Dictionary:
	var b := _battle(seed_value)
	var receipts: Array = []
	if b == null or not _to(b, "moth_queen", receipts, 2):
		return {}
	var first := b.use_foe_ability("queen_dive", 1)
	receipts.append(first)
	if not first.get("ok", false) or first.get("results", []).size() != 1 or not first["results"][0]["hit"]:
		return {}
	if not _to(b, "moth_queen", receipts):
		return {}
	var second := b.use_foe_ability("queen_dive", 1)
	receipts.append(second)
	if not second.get("ok", false) or second.get("results", []).size() != 1 or not second["results"][0]["hit"]:
		return {}
	_check(second["results"][0].get("snip", {}).get("ok", true) == false
		and second["results"][0].get("snip", {}).get("error") == "no intact thread behind this hero"
		and second["results"][0].get("statuses") == [{"status": "tangled", "duration": 2}]
		and second["results"][0].get("damage", 0) > 0
		and b.thread_cuts() == {"warden": 1},
		"AC4: duplicate landed Dive still hits/Tangles but cannot add a second cut")
	return {"receipts": receipts, "state": b.state_snapshot(),
		"order": b.turn_order(), "rng": b.rng_state()}


func _driver(seed_value: int) -> void:
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(_config(seed_value)), "AC2: real battle-screen constructor accepts canonical boss fight")
	if stage.battle == null:
		stage.free()
		return
	var receipts: Array = []
	if not _to(stage.battle, "moth_queen", receipts, 2):
		_check(false, "AC2: real mounted controller battle reaches round-two Queen")
		stage.free()
		return
	stage._drive_foes()
	var observed := false
	for receipt in stage.receipts:
		if receipt.get("actor") != "moth_queen" or receipt.get("ability") != "queen_dive":
			continue
		if receipt.get("results", []).size() == 1 and receipt["results"][0].get("hit", false):
			observed = observed or bool(receipt["results"][0].get("snip", {}).get("ok", false))
	_check(observed, "AC2: existing live battle-screen foe driver executes real Dive and hit/SNIP receipt")
	stage.free()


func _off_turn() -> void:
	var b := _battle(17)
	if b == null:
		return
	var receipts: Array = []
	for step in range(16):
		if b.current_actor_id() != "moth_queen":
			break
		receipts.append(b.pass_turn())
	_check(b.current_actor_id() != "moth_queen", "AC4: genuine off-Queen actor found")
	if b.current_actor_id() != "moth_queen":
		var side := b.current_side()
		_refuse(b, func(): return b.use_foe_ability("queen_dive", 1),
			"it is not a foe turn" if side == "hero" else "the foe has no ability queen_dive", receipts)
