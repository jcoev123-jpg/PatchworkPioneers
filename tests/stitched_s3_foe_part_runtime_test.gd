extends SceneTree
## S3 runtime contract: independently accepted enemy parts in the actual StitchedRules battle.
const ENEMY_PATH := "res://data/parts/enemy_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const IDS := ["scissor_crab_claw_arm", "moth_swarm_wings", "felt_bulwark_button_shield"]
const BACKSTEP_IDS := ["spool_stalker_thread_legs", "bobbin_bat_wing"]
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_catalog_and_rejection()
	_test_combat_and_expiration()
	_test_movement_and_refresh()
	_test_stun_and_termination()
	_test_replay()
	_test_backstep_middle_rank()
	for failure in failures:
		printerr(failure)
	print("stitched_s3_foe_part_runtime_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(ENEMY_PATH)

func _base_config(seed_value: int = 719, tier: int = 1) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "real shipped S2 4v3 preview configuration exists")
		return {}
	var config: Dictionary = parsed
	var accepted := _catalog()
	if not accepted.get("ok", false):
		_check(false, "actual enemy catalog loads: " + str(accepted.get("error", "")))
		return {}
	config["parts"].append_array(accepted["parts"])
	config["seed"] = seed_value
	# Keep the shipped four heroes/three foes and equip only the new, real part IDs.
	config["heroes"][0]["parts"]["arms"] = {"id": IDS[0], "tier": tier}
	config["heroes"][0]["parts"]["legs"] = {"id": IDS[1], "tier": tier}
	config["heroes"][0]["parts"]["torso"] = {"id": IDS[2], "tier": tier}
	config["heroes"][0]["speed"] = 40  # fixed first turn; remaining units keep shipped actions
	config["foes"][0]["speed"] = 0
	config["foes"][1]["speed"] = 0
	config["foes"][2]["speed"] = 0
	return config

func _battle(seed_value: int = 719, tier: int = 1) -> StitchedRules:
	var cfg := _base_config(seed_value, tier)
	if cfg.is_empty():
		return null
	var created := StitchedRules.create(cfg)
	_check(bool(created.get("ok", false)), "four real equipped hero slots form valid combat: " + str(created.get("error", "")))
	return created.get("battle") if bool(created.get("ok", false)) else null

func _to(b: StitchedRules, actor_id: String, limit: int = 30) -> bool:
	for index in range(limit):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id:
			return true
		var receipt := b.pass_turn()
		if not bool(receipt.get("ok", false)):
			return false
	return false

func _test_catalog_and_rejection() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)), "AC1: accepted foe catalog passes engine load_catalog")
	if not bool(catalog.get("ok", false)):
		return
	for id in IDS:
		_check(catalog["by_id"].has(id), "AC1: named enemy drop part is available: " + id)
		if not catalog["by_id"].has(id):
			continue
		var part: Dictionary = catalog["by_id"][id]
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(ability).get("ok", false)), "AC1: %s tier %d ability validates" % [id, tier])
			if id == IDS[1]:
				_check(int(ability["effects"]["dodge"]) == [5, 7, 10][tier - 1] and int(ability["effects"]["duration"]) == 1, "AC1: Tatter Wings tier dodge pair")
			elif id == IDS[0]:
				_check(int(ability["effects"]["bleed"]) == [2, 3, 4][tier - 1], "AC1: Scissor Claw tier bleed")
			else:
				_check(int(ability["effects"]["guard"]) == [2, 3, 4][tier - 1], "AC1: Button Shield tier guard")
	var wing: Dictionary = catalog["by_id"][IDS[1]]["ability"]
	for malformed in [
		{"dodge": 5}, {"duration": 1}, {"dodge": 5, "duration": 0},
		{"dodge": 5, "duration": 9}, {"dodge": -1, "duration": 1},
		{"dodge": 101, "duration": 1}, {"dodge": 5.5, "duration": 1},
		{"dodge": 5, "duration": 1.5}, {"dodge": true, "duration": 1},
		{"dodge": 5, "duration": 1, "not_real": 3}
	]:
		var bad := wing.duplicate(true)
		bad["effects"] = malformed
		_check(not bool(StitchedParts.validate_ability(bad).get("ok", false)), "AC3: invalid paired effect rejects: " + str(malformed))
	for malformed in [{"dodge": 6}, {"duration": 1}, {"dodge": 6, "duration": -1}]:
		var mutated: Dictionary = catalog["by_id"][IDS[1]].duplicate(true)
		mutated["tiers"]["2"]["ability"]["effects"] = malformed
		_check(not bool(StitchedParts.validate_part(mutated).get("ok", false)), "AC3: malformed tier override rejects: " + str(malformed))

func _test_combat_and_expiration() -> void:
	var b := _battle()
	if b == null:
		return
	_check(b.current_actor_id() == "warden" and b.get_heroes().size() == 4 and b.get_foes().size() == 3, "AC2: real 4v3 actor and foes are present")
	var hero := b.get_unit("warden")
	var innate := int(hero["base_dodge"])
	var permanent := int(hero["dodge"])
	_check(permanent == innate + 5 and hero["parts"]["legs"]["id"] == IDS[1], "AC2: equipped wings add only permanent tier-I stat")
	var before := b.state_snapshot()
	var rng := b.rng_state()
	_check(not bool(b.use_part(IDS[1], 2).get("ok", false)) and not bool(b.use_part("unknown", 1).get("ok", false)) and not bool(b.use_part(IDS[0], 5).get("ok", false)), "AC3: illegal self target, part, rank reject")
	_check(before == b.state_snapshot() and rng == b.rng_state(), "AC3: failed actions preserve complete state, turn, and RNG")
	var snip := b.use_part(IDS[0], 1)
	_check(bool(snip.get("ok", false)) and str(snip.get("part", "")) == IDS[0] and not snip.get("results", []).is_empty(), "AC2: real Scissor Claw action executes")
	if not bool(snip.get("ok", false)):
		return
	if not snip["results"].is_empty() and bool(snip["results"][0]["hit"]):
		_check(int(b.get_unit("fray_scavenger")["statuses"].get("bleed", 0)) == 2, "AC2: landed claw applies Bleed 2 to real foe")
		_check(_to(b, "fray_scavenger"), "AC2: bleeding foe gets scheduled turn")
		_check(int(b.get_unit("fray_scavenger")["hp"]) < 30, "AC2: Bleed damages on foe turn without protection")
	else:
		_check(false, "AC2: fixed-seed Scissor Claw needs a hit witness")
	_check(_to(b, "warden"), "AC2: return to equipped Warden for Flutter Back")
	var wing := b.use_part(IDS[1], 1)
	_check(bool(wing.get("ok", false)) and bool(wing.get("self_move", {}).get("ok", false)), "AC2: legal Flutter Back action includes validated swap")
	_check(int(b.get_unit("warden")["rank"]) == 2 and int(b.get_unit("seamstress")["rank"]) == 1, "AC2: Flutter Back swaps rank 1 to rank 2")
	hero = b.get_unit("warden")
	_check(int(hero["dodge"]) == permanent and int(hero["base_dodge"]) == innate and int(StitchedRules.effective_dodge(hero)) == permanent + 5 and int(hero["dodge_buff"]["turns"]) == 1, "AC2: one-turn bonus is temporary and distinct from gear/base stats")
	_check(_to(b, "fray_scavenger"), "AC2: foe takes a real turn against buffed hero")
	var foe := b.get_unit("fray_scavenger")
	var expected := StitchedRules.hit_chance(88 + int(foe["acc"]) + int(b.candle_band()["enemy_acc"]), permanent + 5, int(foe["miss_streak"]))
	var strike := b.use_foe_ability("sack_swing", 2)
	_check(bool(strike.get("ok", false)) and not strike.get("results", []).is_empty(), "AC2: foe makes a seeded real attack on buff")
	if not strike.get("results", []).is_empty():
		_check(int(strike["results"][0].get("hit_chance", -1)) == expected, "AC2: opponent's hit calculation includes exactly temporary Dodge")
	_check(_to(b, "warden"), "AC2: buff owner reaches next own turn")
	_check(int(StitchedRules.effective_dodge(b.get_unit("warden"))) == permanent + 5, "AC2: buff lasts through intervening enemy turns")
	var guard := b.use_part(IDS[2], 1)
	_check(bool(guard.get("ok", false)) and not guard["results"].is_empty(), "AC2: real Button Shield guard casts on legal ally")
	_check(str(b.get_unit("warden")["guard_target"]) == "seamstress" and int(b.get_unit("warden")["statuses"].get("guard", 0)) > 0, "AC2: guard redirects for living rank-one ally")
	_check(StitchedRules.effective_dodge(b.get_unit("warden")) == permanent, "AC2: Dodge expired after Warden's next action, no permanent change")
	_check(_to(b, "fray_scavenger"), "AC2: foe reaches guard target after cast")
	var guarded := b.use_foe_ability("sack_swing", 1)
	if bool(guarded.get("ok", false)) and not guarded["results"].is_empty():
		_check(str(guarded["results"][0].get("guarded_by", "")) == "warden", "AC2: live guard intercepts attack on ally")
	else:
		_check(false, "AC2: foe attack needed to prove guard intercept")

func _test_movement_and_refresh() -> void:
	var blocked := _battle(727)
	if blocked == null:
		return
	blocked._thread_cuts["warden"] = 1
	var before := blocked.state_snapshot()
	var rng := blocked.rng_state()
	var refused := blocked.use_part(IDS[1], 1)
	_check(not bool(refused.get("ok", false)) and before == blocked.state_snapshot() and rng == blocked.rng_state(), "AC3: snipped-thread Flutter Back refuses before any roll or mutation")
	blocked._thread_cuts.clear()
	blocked._units["warden"]["statuses"]["tangled"] = 1
	before = blocked.state_snapshot()
	rng = blocked.rng_state()
	refused = blocked.use_part(IDS[1], 1)
	_check(not bool(refused.get("ok", false)) and before == blocked.state_snapshot() and rng == blocked.rng_state(), "AC3: Tangled Flutter Back refuses without spending turn")
	var b := _battle(735)
	if b == null:
		return
	var permanent := int(b.get_unit("warden")["dodge"])
	_check(bool(b.use_part(IDS[1], 1).get("ok", false)), "AC2: first legal wing cast")
	_check(_to(b, "warden"), "AC2: wing wearer acts again")
	_check(bool(b.use_part(IDS[1], 2).get("ok", false)), "AC2: refreshing wings from rank 2 is legal")
	_check(int(b.get_unit("warden")["rank"]) == 3 and StitchedRules.effective_dodge(b.get_unit("warden")) == permanent + 5, "AC2: second cast refreshes, never stacks bonus")
	_check(_to(b, "warden"), "AC2: wearer gets a real Move turn")
	_check(bool(b.move(-1).get("ok", false)), "AC2: player Move uses actual adjacent rank-swap rules")
	_check(StitchedRules.effective_dodge(b.get_unit("warden")) == permanent, "AC2: refreshed buff expires after owner's Move")


func _test_stun_and_termination() -> void:
	var b := _battle(729)
	if b == null:
		return
	var baseline := int(b.get_unit("warden")["dodge"])
	_check(bool(b.use_part(IDS[1], 1).get("ok", false)), "AC2: cast one-turn Dodge before stun skip")
	b._units["warden"]["statuses"]["stun"] = 1
	_check(_to(b, "warden", 30), "AC2: stunned Warden's skipped turn is traversed before next real Warden turn")
	_check(StitchedRules.effective_dodge(b.get_unit("warden")) == baseline, "AC2: buff expires on stunned owner's skipped turn")
	var p := _battle(741)
	if p != null:
		var base := int(p.get_unit("warden")["dodge"])
		_check(bool(p.use_part(IDS[1], 1).get("ok", false)), "AC2: cast temporary Dodge before pass")
		_check(_to(p, "warden"), "AC2: next Warden pass turn arrives")
		_check(bool(p.pass_turn().get("ok", false)) and StitchedRules.effective_dodge(p.get_unit("warden")) == base, "AC2: Pass expires one-turn Dodge")
	var c := _battle(749)
	if c == null:
		return
	_check(bool(c.use_part(IDS[1], 1).get("ok", false)), "AC2: cast Dodge before combat termination")
	var ended := false
	for attempt in range(20):
		if not _to(c, "seamstress"):
			break
		var receipt := c.retreat()
		if bool(receipt.get("success", false)):
			ended = true
			break
	_check(ended and c.outcome() == "retreated" and c.get_unit("warden").get("dodge_buff", {}).is_empty(), "AC2: genuine successful retreat clears temporary buff")

func _trace(seed_value: int) -> Dictionary:
	var b := _battle(seed_value, 2)
	if b == null:
		return {}
	var receipts: Array = []
	var actions := [[IDS[0], 1], [IDS[1], 1], [IDS[2], 1]]
	for action in actions:
		if not _to(b, "warden"):
			break
		receipts.append(b.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "state": b.state_snapshot(), "rng": b.rng_state()}

func _test_replay() -> void:
	var a := _trace(81237)
	var b := _trace(81237)
	_check(not a.is_empty() and a == b and a.get("receipts", []).size() == 3, "AC3: identical real tier-II three-part action sequence replays all receipts and RNG")
	for r in a.get("receipts", []):
		_check(bool(r.get("ok", false)), "AC3: replay action actually executed")

func _backstep_ability_id(part_id: String) -> String:
	if part_id == "spool_stalker_thread_legs":
		return "spool_step"
	return "bobbin_flit"

func _backstep_ability_name(part_id: String) -> String:
	if part_id == "spool_stalker_thread_legs":
		return "Spool Step"
	return "Bobbin Flit"

## Tier I/II/III leg stats and one-turn Dodge bonuses, copied from the design data.
func _backstep_stats(part_id: String) -> Array:
	if part_id == "spool_stalker_thread_legs":
		return [
			{"speed": 1, "dodge": 3},
			{"speed": 2, "dodge": 5},
			{"speed": 3, "dodge": 7},
		]
	return [
		{"speed": 2, "dodge": 2},
		{"speed": 3, "dodge": 4},
		{"speed": 4, "dodge": 6},
	]

func _backstep_dodges(part_id: String) -> Array:
	if part_id == "spool_stalker_thread_legs":
		return [4, 5, 6]
	return [5, 6, 7]

## AC1: the two named parts keep every authored field and now launch/target ranks 1-3.
func _test_backstep_catalog() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)), "AC1: catalog with corrected backstep masks loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return
	var names := {
		"spool_stalker_thread_legs": ["Thread Legs", "Spool one rank back and gain a turn of Dodge."],
		"bobbin_bat_wing": ["Bobbin Wing", "Flit one rank back on a bobbin wing with a turn of Dodge."],
	}
	for part_id in BACKSTEP_IDS:
		_check(catalog["by_id"].has(part_id), "AC1: named foreign legs part is present: " + part_id)
		if not catalog["by_id"].has(part_id):
			continue
		var part: Dictionary = catalog["by_id"][part_id]
		var expected_name: Array = names[part_id]
		_check(str(part["name"]) == str(expected_name[0]) and str(part["text"]) == str(expected_name[1]), "AC1: %s keeps its name and rules text" % part_id)
		_check(str(part["owner"]) == "any" and str(part["slot"]) == "legs", "AC1: %s stays an owner-any legs part" % part_id)
		_check(str(part["ability"]["id"]) == _backstep_ability_id(part_id) and str(part["ability"]["name"]) == _backstep_ability_name(part_id), "AC1: %s keeps its named ability" % part_id)
		var stats := _backstep_stats(part_id)
		var dodges := _backstep_dodges(part_id)
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var stat := StitchedParts.stat_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(ability).get("ok", false)), "AC1: %s tier %d ability still validates" % [part_id, tier])
			_check(str(ability["id"]) == _backstep_ability_id(part_id) and str(ability["kind"]) == "move" and str(ability["target_side"]) == "self" and not bool(ability["multi"]), "AC1: %s tier %d stays the single self-target move" % [part_id, tier])
			_check(ability["launch"] == [1, 2, 3] and ability["target"] == [1, 2, 3], "AC1: %s tier %d launches from and targets ranks 1-3" % [part_id, tier])
			for rank in [1, 2, 3]:
				_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), rank) and StitchedParts.ranks_allowed(int(ability["target_mask"]), rank), "AC1: %s tier %d allows rank %d for launch and target" % [part_id, tier, rank])
			for rank in [0, 4, 5]:
				_check(not StitchedParts.ranks_allowed(int(ability["launch_mask"]), rank) and not StitchedParts.ranks_allowed(int(ability["target_mask"]), rank), "AC3: %s tier %d still excludes rank %d" % [part_id, tier, rank])
			_check(int(ability["self_move"]) == 1, "AC1: %s tier %d keeps self_move +1" % [part_id, tier])
			_check(int(ability["effects"].get("dodge", -1)) == int(dodges[tier - 1]) and int(ability["effects"].get("duration", 0)) == 1, "AC1: %s tier %d keeps its one-turn Dodge" % [part_id, tier])
			_check(int(ability["acc"]) == 100 and ability["dmg"] == [0, 0] and int(ability["crit"]) == 0 and str(ability["move"]) == "skill", "AC1: %s tier %d keeps accuracy, damage, crit and skill pose" % [part_id, tier])
			_check(stat == stats[tier - 1], "AC1: %s tier %d keeps its authored stat %s" % [part_id, tier, str(stats[tier - 1])])

## The shipped S2 preview with Warden wearing one real foreign backstep part in its test kit.
func _backstep_battle(part_id: String, seed_value: int) -> StitchedRules:
	var cfg := _base_config(seed_value)
	if cfg.is_empty():
		return null
	cfg["heroes"][0]["parts"]["legs"] = {"id": part_id, "tier": 1}
	var created := StitchedRules.create(cfg)
	_check(bool(created.get("ok", false)), "AC2: %s equips on Warden in the real 4v3 preview: %s" % [part_id, str(created.get("error", ""))])
	return created.get("battle") if bool(created.get("ok", false)) else null

## Runs one real scheduled Warden turn and checks its swap, rank and temporary Dodge.
func _check_backstep_cast(
	b: StitchedRules, part_id: String, from_rank: int, ally_id: String, permanent: int,
	innate: int, tier_dodge: int
) -> void:
	_check(b.current_actor_id() == "warden" and int(b.get_unit("warden")["rank"]) == from_rank, "AC2: %s is scheduled from allied rank %d" % [part_id, from_rank])
	var receipt := b.use_part(part_id, from_rank)
	_check(bool(receipt.get("ok", false)), "AC2: %s from rank %d is a legal use_part: %s" % [part_id, from_rank, str(receipt.get("error", ""))])
	if not bool(receipt.get("ok", false)):
		return
	_check(str(receipt.get("part", "")) == part_id and str(receipt.get("ability", "")) == _backstep_ability_id(part_id) and not receipt.get("results", []).is_empty(), "AC2: %s from rank %d executes its real part action" % [part_id, from_rank])
	var step: Dictionary = receipt.get("self_move", {})
	_check(bool(step.get("ok", false)), "AC2: %s from rank %d returns an ok self_move receipt" % [part_id, from_rank])
	_check(int(step.get("from", -1)) == from_rank and int(step.get("to", -1)) == from_rank + 1 and str(step.get("swapped", "")) == ally_id, "AC2: %s from rank %d swaps with %s into rank %d" % [part_id, from_rank, ally_id, from_rank + 1])
	var warden := b.get_unit("warden")
	_check(int(warden["rank"]) == from_rank + 1 and int(b.get_unit(ally_id)["rank"]) == from_rank, "AC2: %s ranks land as Warden %d and %s %d" % [part_id, from_rank + 1, ally_id, from_rank])
	_check(int(warden["dodge"]) == permanent and int(warden["base_dodge"]) == innate, "AC2: %s never changes permanent base or equipment Dodge" % part_id)
	_check(int(warden["dodge_buff"].get("amount", 0)) == tier_dodge and int(warden["dodge_buff"].get("turns", 0)) == 1, "AC2: %s grants its tiered one-turn Dodge %d" % [part_id, tier_dodge])
	_check(StitchedRules.effective_dodge(warden) == permanent + tier_dodge, "AC2: %s effective Dodge is gear plus the temporary bonus" % part_id)

func _test_backstep_runtime(part_id: String) -> void:
	var b := _backstep_battle(part_id, 731)
	if b == null:
		return
	var warden := b.get_unit("warden")
	_check(b.current_actor_id() == "warden" and b.get_heroes().size() == 4, "AC2: %s keeps the shipped four heroes and seeded first Warden turn" % part_id)
	var foes := b.get_foes()
	_check(foes.size() == 3, "AC2: %s keeps exactly the three shipped starting foes" % part_id)
	for foe_id in ["fray_scavenger", "scissor_crab", "moth_scribe"]:
		var seen := false
		for foe in foes:
			if str(foe["id"]) == foe_id:
				seen = true
		_check(seen, "AC2: %s starts with the shipped foe %s" % [part_id, foe_id])
	var stat: Dictionary = _backstep_stats(part_id)[0]
	var permanent := int(warden["dodge"])
	var innate := int(warden["base_dodge"])
	_check(str(warden["parts"]["legs"]["id"]) == part_id and int(warden["parts"]["legs"]["tier"]) == 1, "AC2: %s is the equipped tier-I legs kit" % part_id)
	_check(permanent == innate + int(stat["dodge"]) and warden["dodge_buff"].is_empty(), "AC2: %s tier-I stat is permanent before the first cast" % part_id)
	var tier_dodge := int(_backstep_dodges(part_id)[0])
	_check_backstep_cast(b, part_id, 1, "seamstress", permanent, innate, tier_dodge)
	if not _to(b, "warden"):
		_check(false, "AC2: %s reaches its next scheduled Warden turn" % part_id)
		return
	# Blocked middle-rank witness: a Tangled swap partner refuses before any spend.
	b._units["tinker"]["statuses"]["tangled"] = 1
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var refused := b.use_part(part_id, 2)
	_check(not bool(refused.get("ok", false)), "AC3: %s refuses a Tangled rank-3 swap partner" % part_id)
	_check(before == b.state_snapshot() and rng == b.rng_state(), "AC3: %s blocked middle-rank swap spends no turn, state or RNG" % part_id)
	b._units["tinker"]["statuses"].erase("tangled")
	_check_backstep_cast(b, part_id, 2, "tinker", permanent, innate, tier_dodge)
	if not _to(b, "warden"):
		_check(false, "AC2: %s reaches its rank-3 scheduled turn" % part_id)
		return
	_check_backstep_cast(b, part_id, 3, "lantern_monk", permanent, innate, tier_dodge)
	if not _to(b, "warden"):
		_check(false, "AC2: %s reaches its rank-4 scheduled turn" % part_id)
		return
	# Rank 4 has no backward destination: launch/target stop at 3, nothing may be spent.
	before = b.state_snapshot()
	rng = b.rng_state()
	var at_back := b.use_part(part_id, 4)
	_check(not bool(at_back.get("ok", false)), "AC3: %s from rank 4 rejects the impossible backward step" % part_id)
	_check(before == b.state_snapshot() and rng == b.rng_state(), "AC3: %s rank-4 refusal spends no turn, state or RNG" % part_id)
	warden = b.get_unit("warden")
	_check(int(warden["rank"]) == 4 and int(warden["dodge"]) == permanent and StitchedRules.effective_dodge(warden) == permanent + tier_dodge and int(warden["dodge_buff"].get("amount", 0)) == tier_dodge, "AC3: %s rank-4 refusal grants no extra Dodge" % part_id)

## The same seeded cast sequence twice: receipts, state and RNG must be equal.
func _backstep_trace(part_id: String, seed_value: int) -> Dictionary:
	var b := _backstep_battle(part_id, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for rank in [1, 2, 3]:
		if not _to(b, "warden"):
			return {}
		receipts.append(b.use_part(part_id, rank))
	if not _to(b, "warden"):
		return {}
	var refusal := b.use_part(part_id, 4)
	return {"receipts": receipts, "refusal": refusal, "state": b.state_snapshot(), "rng": b.rng_state()}

func _test_backstep_middle_rank() -> void:
	_test_backstep_catalog()
	for part_id in BACKSTEP_IDS:
		_test_backstep_runtime(part_id)
		var first := _backstep_trace(part_id, 81239)
		var second := _backstep_trace(part_id, 81239)
		_check(not first.is_empty() and first == second and first.get("receipts", []).size() == 3, "AC2: %s seeded three-rank cast sequence replays receipts, state and RNG" % part_id)
		for receipt in first.get("receipts", []):
			_check(bool(receipt.get("ok", false)), "AC2: %s replayed middle-rank cast actually executed" % part_id)
		_check(not bool(first.get("refusal", {}).get("ok", false)), "AC3: %s replay ends on the same rank-4 refusal" % part_id)
