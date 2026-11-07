extends SceneTree
## S5 Clothespin Crusher: its giant wooden spring-jaw Clamp Crush binds a doll with Tangled 2
## and its thrown Pin Pitch exposes another doll with Exposed 2. Both are the real authored
## foe actions, loaded through StitchedEnemyCatalog, executed by genuine StitchedRules foe
## turns in a seeded four-doll preview fight, and drawn with their already-authored attack
## poses (move "attack" / "attack2").
##
## Catalog checks are by required id and source record, never by a catalog total or order.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const POSES := "res://data/art/move_poses.json"
const ENEMY_ID := "clothespin_crusher"
const OTHER_ID := "scissor_crab"
const CLAMP := {
	"id": "clamp_crush", "name": "Clamp Crush", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [4, 6], "crit": 0, "effects": {"tangled": 2},
	"self_move": 0, "move": "attack",
}
const PIN := {
	"id": "pin_pitch", "name": "Pin Pitch", "kind": "ranged",
	"launch": [1, 4], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 84, "dmg": [2, 3], "crit": 0, "effects": {"exposed": 2},
	"self_move": 0, "move": "attack2",
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)), "AC1: real enemy catalog loads")
	if bool(catalog.get("ok", false)):
		_source_contract(catalog)
		_pose_contract()
		_launch_gates(catalog)
		_witness(catalog, "clamp_crush")
		_witness(catalog, "pin_pitch")
	for failure in failures:
		printerr(failure)
	print("stitched_s5_clothespin_jaws_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _record(path: String, enemy_id: String) -> Dictionary:
	var raw: Variant = _read_json(path)
	_check(raw is Array, "AC1: catalog JSON array: " + path)
	if not raw is Array:
		return {}
	var matches: Array = raw.filter(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == enemy_id)
	_check(matches.size() == 1, "AC1: one " + enemy_id + " source at " + path)
	return matches[0] if matches.size() == 1 else {}


func _expected(value: Variant) -> Variant:
	# JSON numbers parse as floats; normalise the authored literal the same way.
	return JSON.parse_string(JSON.stringify(value))


func _ability(record: Dictionary, ability_id: String) -> Dictionary:
	var abilities: Array = record.get("stitched", {}).get("abilities", [])
	var matches: Array = abilities.filter(func(entry: Dictionary) -> bool:
		return str(entry.get("id", "")) == ability_id)
	_check(matches.size() == 1, "AC1: exactly one authored " + ability_id)
	return matches[0] if matches.size() == 1 else {}


func _source_contract(catalog: Dictionary) -> void:
	var record := _record(RUN, ENEMY_ID)
	if record.is_empty():
		return
	# AC1: the two authored actions differ from the old record only by effects and pose.
	_check(_ability(record, "clamp_crush") == _expected(CLAMP),
		"AC1: exact authored Clamp Crush keeps ACC 85, damage 4-6, launch 1-2, target rank 1")
	_check(_ability(record, "pin_pitch") == _expected(PIN),
		"AC1: exact authored Pin Pitch keeps ACC 84, damage 2-3, launch 1-4, target ranks 1-2")
	var profile: Dictionary = record.get("stitched", {})
	_check(record.get("name") == "Clothespin Crusher" and int(record.get("max_hp", 0)) == 30
		and record.get("art_path") == "res://assets/paper/enemies/clothespin_crusher.png",
		"AC1: legacy name, 30 HP and art path stay untouched")
	_check(int(profile.get("max_hp", 0)) == 30 and int(profile.get("speed", -1)) == 3
		and int(profile.get("dodge", -1)) == 3 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 8 and profile.get("is_boss") == false
		and int(profile.get("turns_per_round", 0)) == 1
		and profile.get("trophy") == "clothespin_crusher_clamp",
		"AC1: Stitched profile numbers, one turn and trophy are unchanged")
	# The old weighted card intent is retained verbatim beside the Stitched kit.
	var legacy_actions := [
		{"type": "snip_block", "amount": 0, "weight": 2},
		{"type": "attack", "amount": 8, "weight": 3},
		{"type": "block", "amount": 7, "weight": 1},
		{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 9, "hits": 2, "move": "attack3", "weight": 1}]
	var intent: Dictionary = record.get("intent", {})
	_check(intent.get("target") == "front" and intent.get("actions") == _expected_actions(legacy_actions),
		"AC1: the old weighted front-target intent is unchanged")
	# The shipped loader publishes the same authored kit, normalised, with its pose field.
	var foe := StitchedEnemyCatalog.foe_for(catalog, ENEMY_ID)
	_check(not foe.is_empty() and str(foe.get("name", "")) == "Clothespin Crusher"
		and int(foe.get("max_hp", 0)) == 30 and int(foe.get("speed", -1)) == 3
		and int(foe.get("dodge", -1)) == 3 and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 8 and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the real loader publishes the complete unchanged foe profile")
	_check(catalog.get("enemies", {}).get(ENEMY_ID, {}).get("tier") == "normal"
		and StitchedEnemyCatalog.trophy_for(catalog, ENEMY_ID) == "clothespin_crusher_clamp",
		"AC1: Clothespin Crusher stays one normal foe with its named trophy")
	var kit: Array = foe.get("abilities", [])
	_check(kit.size() == 2, "AC1: the foe keeps exactly its two authored Stitched actions")
	for pair in [["clamp_crush", CLAMP], ["pin_pitch", PIN]]:
		var ability_id: String = pair[0]
		var expected: Dictionary = pair[1]
		var validated := StitchedParts.validate_ability(expected)
		var normalized: Array = kit.filter(func(ability: Dictionary) -> bool:
			return str(ability.get("id", "")) == ability_id)
		_check(bool(validated.get("ok", false)) and normalized.size() == 1
			and normalized[0] == validated.get("ability", {}),
			"AC1: the real loader publishes the normalised canonical " + ability_id)
		var ability: Dictionary = normalized[0]
		_check(ability.get("multi") == false and int(ability.get("self_move", -1)) == 0
			and ability.get("target_side") == "enemy",
			"AC1: " + ability_id + " stays a single-target foe action with zero self-movement")
	_check(_ability(record, "clamp_crush").get("effects") == _expected({"tangled": 2})
		and _ability(record, "pin_pitch").get("effects") == _expected({"exposed": 2}),
		"AC1: only the clamp binds and only the pitch exposes")
	# Named neighbouring records keep their prior values (checked by id, never by total).
	var crab := _record(RUN, OTHER_ID)
	var pinch: Dictionary = _ability(crab, "pinch")
	_check(pinch.get("dmg") == _expected([3, 6])
		and pinch.get("effects") == _expected({"bleed": 2})
		and pinch.get("move") == "attack2" and int(crab.get("stitched", {}).get("max_hp", 0)) == 22,
		"AC1: the Scissor Crab's authored Pinch is untouched")
	var stalker := _record(RUN, "spool_stalker")
	var lash: Dictionary = _ability(stalker, "spool_lash")
	_check(lash.get("effects") == _expected({"tangled": 2}) and lash.get("move") == "attack2"
		and int(lash.get("acc", 0)) == 86,
		"AC1: the Spool Stalker's authored Spool Lash is untouched")
	var scavenger := _record(RUN, "fray_scavenger")
	_check(int(scavenger.get("max_hp", 0)) == 14
		and int(scavenger.get("stitched", {}).get("max_hp", 0)) == 24,
		"AC1: the Fray Scavenger's legacy and Stitched health are untouched")


func _expected_actions(actions: Array) -> Array:
	var normalized: Variant = _expected({"actions": actions})
	return normalized["actions"]


func _pose_contract() -> void:
	var manifest: Variant = _read_json(POSES)
	_check(manifest is Dictionary, "AC1: the live move-pose manifest loads")
	if not manifest is Dictionary:
		return
	var poses: Dictionary = manifest.get("enemies", {}).get(ENEMY_ID, {})
	var record := _record(RUN, ENEMY_ID)
	for pair in [["clamp_crush", "attack", "Clamp Crush", "clothespin_crusher_attack.png"],
			["pin_pitch", "attack2", "Pin Pitch", "clothespin_crusher_attack2.png"]]:
		var ability_id: String = pair[0]
		var pose_key: String = pair[1]
		var pose_name: String = pair[2]
		var art_file: String = pair[3]
		var entry: Dictionary = poses.get(pose_key, {})
		_check(entry.get("name") == pose_name
			and str(entry.get("art", "")) == "res://assets/paper/enemies/" + art_file
			and (entry.get("covers", []) as Array).has("attack"),
			"AC1: the existing " + pose_name + " pose art is authored at " + pose_key)
		# The authored ability's own pose field selects that exact existing manifest entry.
		var move := str(_ability(record, ability_id).get("move", ""))
		_check(move == pose_key and poses.has(move),
			"AC1: " + ability_id + " selects the existing " + pose_name + " pose")


func _battle(catalog: Dictionary, ids: Array, seed_value: int) -> StitchedRules:
	var preview: Variant = _read_json(PREVIEW)
	_check(preview is Dictionary, "AC1: the shipped four-hero preview exists")
	if not preview is Dictionary:
		return null
	var foes: Array = []
	for foe_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(foe_id))
		_check(not foe.is_empty() and catalog["enemies"][str(foe_id)]["tier"] == "normal",
			"real normal foe from loader: " + str(foe_id))
		foes.append(foe)
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"])
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview["heroes"].duplicate(true), "parts": parts, "foes": foes,
	})
	_check(bool(built.get("ok", false)),
		"AC2/AC3: seeded real %dv%d rules battle creates: %s"
			% [preview["heroes"].size(), foes.size(), str(built.get("error", ""))])
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size()
		and battle.candle() == 100,
		"AC2/AC3: non-vacuous candle-100 live hero/foe roster")
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
		target_rank: int, expected_error: String, inspect: bool,
		receipts: Array, snapshots: Array) -> Dictionary:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var rejected := battle.use_foe_ability(ability_id, target_rank)
	if inspect:
		_check(not bool(rejected.get("ok", true)) and rejected.get("error") == expected_error
			and before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: invalid " + ability_id + " target rank %d refuses atomically: %s"
				% [target_rank, expected_error])
	receipts.append(rejected)
	snapshots.append(battle.state_snapshot())
	return rejected


func _launch_gates(catalog: Dictionary) -> void:
	# A real three-foe fight places the Clothespin Crusher at rank three, outside both launches.
	var rear := _battle(catalog, [OTHER_ID, "ragling", ENEMY_ID], 97)
	if rear != null:
		var receipts: Array = []
		var snapshots: Array = [rear.state_snapshot()]
		if _reach(rear, ENEMY_ID, receipts, snapshots, true):
			_check(int(rear.get_unit(ENEMY_ID)["rank"]) == 3,
				"AC4: real Clothespin Crusher at prohibited launch rank three")
			_reject_without_spend(rear, "clamp_crush", 1,
				"ability cannot launch from rank 3", true, receipts, snapshots)
			_reject_without_spend(rear, "pin_pitch", 1,
				"ability cannot launch from rank 3", true, receipts, snapshots)
			_check(bool(rear.pass_turn().get("ok", false)),
				"AC4: refused launch ranks leave the turn available for a legal pass")
	# A real two-foe fight places it at rank two, outside Pin Pitch's authored 1/4 launch.
	var middle := _battle(catalog, [OTHER_ID, ENEMY_ID], 98)
	if middle != null:
		var receipts: Array = []
		var snapshots: Array = [middle.state_snapshot()]
		if _reach(middle, ENEMY_ID, receipts, snapshots, true):
			_check(int(middle.get_unit(ENEMY_ID)["rank"]) == 2,
				"AC4: real Clothespin Crusher at prohibited Pin Pitch launch rank two")
			_reject_without_spend(middle, "pin_pitch", 1,
				"ability cannot launch from rank 2", true, receipts, snapshots)
			_check(bool(middle.pass_turn().get("ok", false)),
				"AC4: refused Pin Pitch launch keeps the turn and RNG intact")


func _witness(catalog: Dictionary, ability_id: String) -> void:
	var hits := 0
	var misses := 0
	for seed_value in range(1, 129):
		var first := _exercise(catalog, ability_id, seed_value, true)
		if first.is_empty():
			continue
		var replay := _exercise(catalog, ability_id, seed_value, false)
		_check(first == replay and not replay.is_empty(),
			"AC4: " + ability_id + " repeats receipts, turn order, states and RNG for seed "
				+ str(seed_value))
		if bool(first["hit"]):
			hits += 1
		else:
			misses += 1
		if hits > 0 and misses > 0:
			break
	_check(hits > 0 and misses > 0,
		"AC3/AC4: genuine non-vacuous seeded hit AND natural miss witnessed for " + ability_id)


func _exercise(catalog: Dictionary, ability_id: String, seed_value: int,
		inspect: bool) -> Dictionary:
	if ability_id == "clamp_crush":
		return _clamp_exercise(catalog, seed_value, inspect)
	return _pin_exercise(catalog, seed_value, inspect)


func _clamp_exercise(catalog: Dictionary, seed_value: int, inspect: bool) -> Dictionary:
	var battle := _battle(catalog, [ENEMY_ID, OTHER_ID], seed_value)
	if battle == null:
		return {}
	var receipt_list: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	if not _reach(battle, ENEMY_ID, receipt_list, snapshots, inspect):
		return {}
	var actor := battle.get_unit(ENEMY_ID)
	var victim := str(battle.get_heroes()[0]["id"])
	var before_hero := battle.get_unit(victim)
	if inspect:
		_check(int(actor["rank"]) == 1 and battle.current_side() == "foe",
			"AC2: authentic Clothespin Crusher rank-one foe turn")
		_check(victim == "warden" and int(before_hero["rank"]) == 1
			and before_hero["statuses"].is_empty(),
			"AC2: initially untangled front-rank hero is the real target")
	# AC4: hero actions are refused during the foe's genuine turn.
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var wrong_move := battle.move(1)
	var wrong_part := battle.use_part("warden_arm_shield_bash", 1)
	receipt_list.append(wrong_move)
	receipt_list.append(wrong_part)
	snapshots.append(battle.state_snapshot())
	snapshots.append(battle.state_snapshot())
	if inspect:
		_check(wrong_move.get("error") == "it is not a hero turn"
			and wrong_part.get("error") == "it is not a hero turn"
			and before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: wrong-side hero actions refuse with unchanged state, turn and RNG")
	# AC4: an occupied rank outside target [1] and an impossible rank both refuse.
	_reject_without_spend(battle, "clamp_crush", 3, "no legal target in rank 3",
		inspect, receipt_list, snapshots)
	_reject_without_spend(battle, "clamp_crush", 5, "no legal target in rank 5",
		inspect, receipt_list, snapshots)
	var receipt := battle.use_foe_ability("clamp_crush", 1)
	receipt_list.append(receipt)
	snapshots.append(battle.state_snapshot())
	var results: Array = receipt.get("results", [])
	if inspect:
		_check(bool(receipt.get("ok", false)) and receipt.get("actor") == ENEMY_ID
			and receipt.get("ability") == "clamp_crush" and results.size() == 1,
			"AC2: real foe executes one authored Clamp Crush on the intended doll")
	if not bool(receipt.get("ok", false)) or results.size() != 1:
		return {}
	var result: Dictionary = results[0]
	var hit: bool = bool(result.get("hit", false))
	if inspect:
		_check(result.get("target") == victim and int(result.get("target_rank", 0)) == 1,
			"AC2: Clamp Crush really aims at the front-rank doll")
		_check(int(result.get("hit_chance", 0)) == StitchedRules.hit_chance(
			85 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"]),
			battle.effective_dodge(before_hero), int(actor["miss_streak"]))
			and int(result.get("hit_chance", 0)) == 80,
			"AC1/AC2: Clamp Crush hit chance is authored ACC 85 against the real doll DODGE")
		_check(result.get("hit") == (int(result.get("roll", 101)) <= int(result.get("hit_chance", 0))),
			"AC2: the receipt is a real seeded hit roll")
	var binding := 0
	for entry in result.get("statuses", []):
		if entry is Dictionary and str(entry.get("status", "")) == "tangled":
			binding += 1
			if inspect:
				_check(int(entry.get("duration", -1)) == 2,
					"AC2: a confirmed clamp receipt records Tangled 2")
	if inspect:
		_check(binding == (1 if hit else 0),
			"AC2/AC3: hit adds exactly one Tangled 2, natural miss adds none")
		var live := int(battle.get_unit(victim)["statuses"].get("tangled", 0))
		if hit:
			_check(live == (1 if battle.current_actor_id() == victim else 2),
				"AC2: the struck doll really carries Tangled 2 (ticked to 1 on its own turn)")
		else:
			_check(live == 0,
				"AC3: a natural Clamp Crush miss leaves its doll untangled")
		if not hit:
			_check((result.get("statuses", []) as Array).is_empty()
				and int(result.get("damage", -1)) == 0
				and int(result.get("target_hp", -1)) == int(before_hero["hp"])
				and not battle.get_unit(victim)["statuses"].has("tangled"),
				"AC3: a natural Clamp Crush miss neither damages nor tangles its doll")
	if not _reach(battle, victim, receipt_list, snapshots, inspect):
		return {}
	var at_turn := battle.get_unit(victim)
	if inspect:
		_check(battle.current_side() == "hero" and int(at_turn["rank"]) == 1,
			"AC2: the bound doll actually enters its next natural hero turn")
		_check(int(at_turn["statuses"].get("tangled", 0)) == (1 if hit else 0),
			"AC2/AC3: exactly one start-of-own-turn countdown tick occurs")
	if hit:
		var prot := int(at_turn["prot"])
		var bound_damage := StitchedRules.damage_after_modifiers(
			6, {}, at_turn["statuses"], false, 0, prot)
		var plain_damage := StitchedRules.damage_after_modifiers(6, {}, {}, false, 0, prot)
		if inspect:
			_check(bound_damage == StitchedRules.apply_protection(8, prot)
				and plain_damage == StitchedRules.apply_protection(6, prot)
				and bound_damage > plain_damage,
				"AC2: while Tangled is live, incoming direct damage gains the shared flat +2")
		# AC4: a foe action is refused during the doll's genuine turn.
		before = battle.state_snapshot()
		rng = battle.rng_state()
		var wrong_foe := battle.use_foe_ability("clamp_crush", 1)
		receipt_list.append(wrong_foe)
		snapshots.append(battle.state_snapshot())
		if inspect:
			_check(wrong_foe.get("error") == "it is not a foe turn"
				and before == battle.state_snapshot() and rng == battle.rng_state(),
				"AC4: wrong-side foe action refuses on the hero turn without spend")
		# AC2: the otherwise-legal rank-one Move is refused while Tangled 1 is active.
		before = battle.state_snapshot()
		rng = battle.rng_state()
		var refused := battle.move(1)
		receipt_list.append(refused)
		snapshots.append(battle.state_snapshot())
		if inspect:
			_check(not bool(refused.get("ok", true))
				and refused.get("error") == "a tangled hero cannot move"
				and before == battle.state_snapshot() and rng == battle.rng_state()
				and int(battle.get_heroes()[1]["rank"]) == 2,
				"AC2: an otherwise-legal Move rejects atomically with Tangled 1")
		var passed := battle.pass_turn()
		receipt_list.append(passed)
		snapshots.append(battle.state_snapshot())
		if inspect:
			_check(bool(passed.get("ok", false)),
				"AC2: the bound doll may legally pass its tangled turn")
		if not _reach(battle, victim, receipt_list, snapshots, inspect):
			return {}
		if inspect:
			_check(not battle.get_unit(victim)["statuses"].has("tangled"),
				"AC2: the following affected turn-start clears the binding")
	else:
		if inspect:
			_check(not at_turn["statuses"].has("tangled"),
				"AC3: a missed doll arrives at its turn without Tangled")
	var swap_target := str(battle.get_heroes()[1]["id"])
	var moved := battle.move(1)
	receipt_list.append(moved)
	snapshots.append(battle.state_snapshot())
	if inspect:
		_check(bool(moved.get("ok", false)) and moved.get("actor") == victim
			and int(moved.get("from", 0)) == 1 and int(moved.get("to", 0)) == 2
			and moved.get("swapped") == swap_target
			and not battle.get_unit(victim)["statuses"].has("tangled"),
			"AC2/AC3: ordinary rank-one swap succeeds once the binding expires")
	return {"hit": hit, "receipts": receipt_list, "snapshots": snapshots,
		"state": battle.state_snapshot(), "rng": battle.rng_state()}


func _pin_exercise(catalog: Dictionary, seed_value: int, inspect: bool) -> Dictionary:
	var battle := _battle(catalog, [ENEMY_ID, OTHER_ID], seed_value)
	if battle == null:
		return {}
	var receipt_list: Array = []
	var snapshots: Array = [battle.state_snapshot()]
	if not _reach(battle, ENEMY_ID, receipt_list, snapshots, inspect):
		return {}
	var actor := battle.get_unit(ENEMY_ID)
	var victim := str(battle.get_heroes()[1]["id"])
	var before_hero := battle.get_unit(victim)
	if inspect:
		_check(int(actor["rank"]) == 1 and battle.current_side() == "foe",
			"AC3: authentic Clothespin Crusher legal Pin Pitch foe turn")
		_check(victim == "seamstress" and int(before_hero["rank"]) == 2
			and before_hero["statuses"].is_empty(),
			"AC3: initially unexposed rank-two hero is the real target")
	# AC4: hero actions are refused during the foe's genuine turn.
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var wrong_move := battle.move(1)
	var wrong_part := battle.use_part("any_arm_red_thread", 1)
	receipt_list.append(wrong_move)
	receipt_list.append(wrong_part)
	snapshots.append(battle.state_snapshot())
	snapshots.append(battle.state_snapshot())
	if inspect:
		_check(wrong_move.get("error") == "it is not a hero turn"
			and wrong_part.get("error") == "it is not a hero turn"
			and before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: wrong-side hero actions refuse with unchanged state, turn and RNG")
	# AC4: target [1,2] refuses an occupied rank three and an impossible rank five.
	_reject_without_spend(battle, "pin_pitch", 3, "no legal target in rank 3",
		inspect, receipt_list, snapshots)
	_reject_without_spend(battle, "pin_pitch", 5, "no legal target in rank 5",
		inspect, receipt_list, snapshots)
	var receipt := battle.use_foe_ability("pin_pitch", 2)
	receipt_list.append(receipt)
	snapshots.append(battle.state_snapshot())
	var results: Array = receipt.get("results", [])
	if inspect:
		_check(bool(receipt.get("ok", false)) and receipt.get("actor") == ENEMY_ID
			and receipt.get("ability") == "pin_pitch" and results.size() == 1,
			"AC3: real foe executes one authored Pin Pitch on the intended doll")
	if not bool(receipt.get("ok", false)) or results.size() != 1:
		return {}
	var result: Dictionary = results[0]
	var hit: bool = bool(result.get("hit", false))
	if inspect:
		_check(result.get("target") == victim and int(result.get("target_rank", 0)) == 2,
			"AC3: Pin Pitch really aims at the rank-two doll")
		_check(int(result.get("hit_chance", 0)) == StitchedRules.hit_chance(
			84 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"]),
			battle.effective_dodge(before_hero), int(actor["miss_streak"]))
			and int(result.get("hit_chance", 0)) == 73,
			"AC1/AC3: Pin Pitch hit chance is authored ACC 84 against the real doll DODGE")
		_check(result.get("hit") == (int(result.get("roll", 101)) <= int(result.get("hit_chance", 0))),
			"AC3: the receipt is a real seeded hit roll")
	var exposure := 0
	for entry in result.get("statuses", []):
		if entry is Dictionary and str(entry.get("status", "")) == "exposed":
			exposure += 1
			if inspect:
				_check(int(entry.get("duration", -1)) == 2,
					"AC3: a confirmed Pin Pitch receipt records Exposed 2")
	if inspect:
		_check(exposure == (1 if hit else 0),
			"AC3/AC4: hit adds exactly one Exposed 2, natural miss adds none")
		var live := int(battle.get_unit(victim)["statuses"].get("exposed", 0))
		if hit:
			_check(live == (1 if battle.current_actor_id() == victim else 2),
				"AC3: the struck doll really carries Exposed 2 (ticked to 1 on its own turn)")
		else:
			_check(live == 0,
				"AC4: a natural Pin Pitch miss leaves its doll unexposed")
		if not hit:
			_check((result.get("statuses", []) as Array).is_empty()
				and int(result.get("damage", -1)) == 0
				and int(result.get("target_hp", -1)) == int(before_hero["hp"])
				and not battle.get_unit(victim)["statuses"].has("exposed"),
				"AC3: a natural Pin Pitch miss neither damages nor exposes its doll")
	if not _reach(battle, victim, receipt_list, snapshots, inspect):
		return {}
	var at_turn := battle.get_unit(victim)
	if inspect:
		_check(battle.current_side() == "hero" and int(at_turn["rank"]) == 2,
			"AC3: the pinned doll actually enters its next natural hero turn")
		_check(int(at_turn["statuses"].get("exposed", 0)) == (1 if hit else 0),
			"AC3/AC4: exactly one start-of-own-turn countdown leaves Exposed 1")
	if hit:
		if inspect:
			_check(StitchedRules.damage_after_modifiers(6, {}, at_turn["statuses"], false, 0, 0) == 9
				and StitchedRules.damage_after_modifiers(6, {}, {}, false, 0, 0) == 6,
				"AC3: while Exposed is live, direct damage is multiplied 1.5x before PROT")
			_check(StitchedRules.damage_after_modifiers(6, {}, {"exposed": 1}, false, 0, 40)
				== StitchedRules.apply_protection(9, 40)
				and StitchedRules.damage_after_modifiers(6, {}, {"exposed": 1}, false, 0, 40) == 6
				and StitchedRules.damage_after_modifiers(6, {}, {}, false, 0, 40) == 4,
				"AC3: the 1.5x Exposed factor is applied before the shared PROT cut")
		# AC4: a foe action is refused during the doll's genuine turn.
		before = battle.state_snapshot()
		rng = battle.rng_state()
		var wrong_foe := battle.use_foe_ability("pin_pitch", 2)
		receipt_list.append(wrong_foe)
		snapshots.append(battle.state_snapshot())
		if inspect:
			_check(wrong_foe.get("error") == "it is not a foe turn"
				and before == battle.state_snapshot() and rng == battle.rng_state(),
				"AC4: wrong-side foe action refuses on the hero turn without spend")
		var passed := battle.pass_turn()
		receipt_list.append(passed)
		snapshots.append(battle.state_snapshot())
		if inspect:
			_check(bool(passed.get("ok", false)),
				"AC3: the exposed doll may legally pass its turn")
		if not _reach(battle, victim, receipt_list, snapshots, inspect):
			return {}
		if inspect:
			_check(not battle.get_unit(victim)["statuses"].has("exposed"),
				"AC3: the following affected turn-start expires the exposure")
	else:
		if inspect:
			_check(not at_turn["statuses"].has("exposed"),
				"AC4: a missed doll arrives at its turn without Exposed")
	var swap_target := str(battle.get_heroes()[0]["id"])
	var moved := battle.move(-1)
	receipt_list.append(moved)
	snapshots.append(battle.state_snapshot())
	if inspect:
		_check(bool(moved.get("ok", false)) and moved.get("actor") == victim
			and int(moved.get("from", 0)) == 2 and int(moved.get("to", 0)) == 1
			and moved.get("swapped") == swap_target
			and not battle.get_unit(victim)["statuses"].has("exposed"),
			"AC3: ordinary rank-two swap succeeds once the exposure expires")
	return {"hit": hit, "receipts": receipt_list, "snapshots": snapshots,
		"state": battle.state_snapshot(), "rng": battle.rng_state()}
