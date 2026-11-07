extends SceneTree
## Both normal foes' authentic thread attacks persist through the struck doll's next turn.
## Uses the shipped enemy loader, preview roster, public foe action and real turn countdown.

const RUN := "res://data/enemies/run_enemies.json"
const TOUGH := "res://data/enemies/v3_tough_normals.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const LASH := {
	"id": "spool_lash", "name": "Spool Lash", "kind": "melee",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [3, 4], "crit": 0, "effects": {"tangled": 2},
	"self_move": 0, "move": "attack2",
}
const HURL := {
	"id": "yarn_hurl", "name": "Yarn Hurl", "kind": "ranged",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [2, 3], "crit": 0, "effects": {"tangled": 2},
	"self_move": 0, "move": "attack3",
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)), "AC1: real enemy catalog loads")
	if bool(catalog.get("ok", false)):
		_sources(catalog)
		for pair in [["spool_stalker", "spool_lash"], ["spindle_ram", "yarn_hurl"]]:
			var enemy_id: String = pair[0]
			var ability_id: String = pair[1]
			var hits := 0
			var misses := 0
			_invalid_launch(catalog, enemy_id, ability_id)
			for seed_value in range(1, 129):
				var first := _exercise(catalog, enemy_id, ability_id, seed_value, true)
				if first.is_empty():
					continue
				var replay := _exercise(catalog, enemy_id, ability_id, seed_value, false)
				_check(first == replay and not replay.is_empty(),
					"AC3: " + ability_id + " repeats all receipts, snapshots and RNG for seed " + str(seed_value))
				if bool(first["hit"]):
					hits += 1
				else:
					misses += 1
				if hits > 0 and misses > 0:
					break
			_check(hits > 0 and misses > 0,
				"AC2/3: genuine non-vacuous seeded hit AND natural miss for " + ability_id)
	for failure in failures:
		printerr(failure)
	print("stitched_s5_spool_tangle_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _record(path: String, enemy_id: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(raw is Array, "AC1: catalog JSON array: " + path)
	if not raw is Array:
		return {}
	var matches: Array = raw.filter(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == enemy_id)
	_check(matches.size() == 1, "AC1: one " + enemy_id + " source at " + path)
	return matches[0] if matches.size() == 1 else {}


func _sources(catalog: Dictionary) -> void:
	var stalker := _record(RUN, "spool_stalker")
	var ram := _record(RUN, "spindle_ram")
	_check(not ram.is_empty() and ram == _record(TOUGH, "spindle_ram"),
		"AC1: full Spindle Ram duplicate entries remain equal")
	for pair in [["spool_stalker", "spool_lash", LASH, stalker],
			["spindle_ram", "yarn_hurl", HURL, ram]]:
		var enemy_id: String = pair[0]
		var ability_id: String = pair[1]
		var expected: Dictionary = pair[2]
		var record: Dictionary = pair[3]
		if record.is_empty():
			continue
		var abilities: Array = record.get("stitched", {}).get("abilities", [])
		var raw_matches: Array = abilities.filter(func(entry: Dictionary) -> bool:
			return str(entry.get("id", "")) == ability_id)
		_check(raw_matches.size() == 1 and raw_matches[0] == JSON.parse_string(JSON.stringify(expected)),
			"AC1: exact authored " + ability_id + " differs only by its Tangled duration")
		var validated := StitchedParts.validate_ability(expected)
		var loaded := StitchedEnemyCatalog.foe_for(catalog, enemy_id)
		var kit: Array = loaded.get("abilities", [])
		var normalized: Array = kit.filter(func(ability: Dictionary) -> bool:
			return str(ability.get("id", "")) == ability_id)
		_check(bool(validated.get("ok", false)) and normalized.size() == 1
			and normalized[0] == validated.get("ability", {}),
			"AC1: real loader publishes the complete canonical " + ability_id + " kit")
	_check(stalker.get("stitched", {}).get("abilities", []).size() == 2
		and stalker["stitched"]["abilities"][1]["id"] == "spool_stalk"
		and stalker["stitched"]["abilities"][1]["effects"] == JSON.parse_string(JSON.stringify({"dodge": 5, "duration": 1})),
		"AC1: Spool Stalk's separate buff remains untouched")


func _battle(catalog: Dictionary, enemy_id: String, seed_value: int,
		rear: bool = false) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(preview is Dictionary, "shipped four-hero preview exists")
	if not preview is Dictionary:
		return null
	var ids := [enemy_id, "scissor_crab"]
	if rear:
		ids = ["scissor_crab", enemy_id]
	var foes: Array = []
	for foe_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, foe_id)
		_check(not foe.is_empty() and catalog["enemies"][foe_id]["tier"] == "normal",
			"real normal foe from loader: " + foe_id)
		foes.append(foe)
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"])
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview["heroes"].duplicate(true), "parts": parts, "foes": foes,
	})
	_check(bool(built.get("ok", false)), "seeded real 4v2 rules battle creates: " + str(built.get("error", "")))
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 2,
		"non-vacuous live hero/foe roster")
	var front: Dictionary = battle.get_heroes()[0]
	var next: Dictionary = battle.get_heroes()[1]
	_check(front["rank"] == 1 and next["rank"] == 2 and front["hp"] > 10
		and next["hp"] > 0 and front["statuses"].is_empty()
		and next["statuses"].is_empty() and battle.thread_cuts().is_empty(),
		"healthy, untangled rank-one victim has an otherwise-legal rank-two swap")
	return battle


func _reach(battle: StitchedRules, actor_id: String, receipts: Array,
		snapshots: Array, inspect: bool) -> bool:
	for step in range(20):
		if battle.is_over():
			break
		if battle.current_actor_id() == actor_id:
			return true
		var passed := battle.pass_turn()
		if inspect:
			_check(bool(passed.get("ok", false)), "legal pass advances real turn order")
		receipts.append(passed)
		snapshots.append(battle.state_snapshot())
	if inspect:
		_check(false, "the real seeded turn order reaches " + actor_id)
	return false


func _reject_without_spend(battle: StitchedRules, ability_id: String,
		target_rank: int, expected_error: String, inspect: bool) -> Dictionary:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var rejected := battle.use_foe_ability(ability_id, target_rank)
	if inspect:
		_check(not bool(rejected.get("ok", true)) and rejected.get("error") == expected_error
			and before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC3: invalid " + ability_id + " target/launch refuses atomically: " + expected_error)
	return rejected


func _invalid_launch(catalog: Dictionary, enemy_id: String, ability_id: String) -> void:
	var battle := _battle(catalog, enemy_id, 93, true)
	if battle == null:
		return
	var receipts: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	if not _reach(battle, enemy_id, receipts, snapshots, true):
		return
	_check(battle.get_unit(enemy_id)["rank"] == 2,
		"AC3: real " + enemy_id + " at prohibited launch rank two")
	_reject_without_spend(battle, ability_id, 1, "ability cannot launch from rank 2", true)
	_check(bool(battle.pass_turn().get("ok", false)),
		"AC3: invalid launch leaves its turn available for a legal pass")


func _exercise(catalog: Dictionary, enemy_id: String, ability_id: String,
		seed_value: int, inspect: bool) -> Dictionary:
	var battle := _battle(catalog, enemy_id, seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	if not _reach(battle, enemy_id, receipts, snapshots, inspect):
		return {}
	var victim: String = str(battle.get_heroes()[0]["id"])
	var before_hero := battle.get_unit(victim)
	if inspect:
		_check(battle.get_unit(enemy_id)["rank"] == 1
			and before_hero["rank"] == 1 and before_hero["statuses"].is_empty(),
			"AC2: authentic foe rank-one launch and initially untangled victim")
	receipts.append(_reject_without_spend(battle, ability_id, 3,
		"no legal target in rank 3", inspect))
	snapshots.append(battle.state_snapshot())
	var receipt := battle.use_foe_ability(ability_id, 1)
	receipts.append(receipt)
	snapshots.append(battle.state_snapshot())
	var results: Array = receipt.get("results", [])
	if inspect:
		_check(bool(receipt.get("ok", false)) and receipt.get("actor") == enemy_id
			and receipt.get("ability") == ability_id and results.size() == 1,
			"AC2: real foe executes one authored attack on the intended target")
	if not bool(receipt.get("ok", false)) or results.size() != 1:
		return {}
	var result: Dictionary = results[0]
	var hit: bool = bool(result.get("hit", false))
	if inspect:
		_check(result.get("target") == victim and result.get("target_rank") == 1
			and result.get("hit") == (int(result.get("roll", 101)) <= int(result.get("hit_chance", 0))),
			"AC2/3: actual seeded hit roll and real doll target")
	var status_entries: Array = result.get("statuses", [])
	var tangle_count := 0
	for entry in status_entries:
		if entry is Dictionary and str(entry.get("status", "")) == "tangled":
			tangle_count += 1
			if inspect:
				_check(int(entry.get("duration", -1)) == 2,
					"AC2: successful binding receipt records Tangled 2")
	if inspect:
		_check(tangle_count == (1 if hit else 0),
			"AC2/3: hit adds exactly one Tangled 2, natural miss adds none")
		if not hit:
			_check(status_entries.is_empty() and int(result.get("damage", -1)) == 0
				and not battle.get_unit(victim)["statuses"].has("tangled"),
				"AC3: natural miss neither damages nor tangles its target")
	if not _reach(battle, victim, receipts, snapshots, inspect):
		return {}
	var at_turn := battle.get_unit(victim)
	if inspect:
		_check(battle.current_side() == "hero" and at_turn["rank"] == 1,
			"AC2: target actually enters a legal next hero turn")
		_check(int(at_turn["statuses"].get("tangled", 0)) == (1 if hit else 0),
			"AC2/3: exactly one start-of-turn countdown tick occurs after hit or miss")
	if hit:
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var refused := battle.move(1)
		receipts.append(refused)
		snapshots.append(battle.state_snapshot())
		if inspect:
			_check(not bool(refused.get("ok", true))
				and refused.get("error") == "a tangled hero cannot move"
				and before == battle.state_snapshot() and rng == battle.rng_state()
				and battle.get_unit(battle.get_heroes()[1]["id"])["rank"] == 2,
				"AC2: otherwise-legal Move rejects atomically with Tangled 1")
		var passed := battle.pass_turn()
		receipts.append(passed)
		snapshots.append(battle.state_snapshot())
		if inspect:
			_check(bool(passed.get("ok", false)),
				"AC2: affected doll may legally pass its tangled turn")
		if not _reach(battle, victim, receipts, snapshots, inspect):
			return {}
		if inspect:
			_check(int(battle.get_unit(victim)["statuses"].get("tangled", 0)) == 0,
				"AC2: following affected turn-start clears the binding")
	else:
		if inspect:
			_check(not at_turn["statuses"].has("tangled"),
				"AC3: missed doll arrives at its turn without Tangled")
	var moved := battle.move(1)
	receipts.append(moved)
	snapshots.append(battle.state_snapshot())
	if inspect:
		_check(bool(moved.get("ok", false)) and moved.get("actor") == victim
			and moved.get("from") == 1 and moved.get("to") == 2
			and not battle.get_unit(victim)["statuses"].has("tangled"),
			"AC2/3: ordinary rank-one swap succeeds once untangled")
	return {"hit": hit, "receipts": receipts, "snapshots": snapshots,
		"state": battle.state_snapshot(), "rng": battle.rng_state()}
