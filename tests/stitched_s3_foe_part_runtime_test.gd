extends SceneTree
## S3 runtime contract: independently accepted enemy parts in the actual StitchedRules battle.
const ENEMY_PATH := "res://data/parts/enemy_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const IDS := ["scissor_crab_claw_arm", "moth_swarm_wings", "felt_bulwark_button_shield"]
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_catalog_and_rejection()
	_test_combat_and_expiration()
	_test_movement_and_refresh()
	_test_stun_and_termination()
	_test_replay()
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
