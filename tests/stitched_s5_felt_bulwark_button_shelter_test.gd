extends SceneTree
## S5 Felt Bulwark Button Shelter contract (Design v4 "Stitched").
##
## The canonical felt_moth_pressure front foe, the Felt Bulwark, may shelter its living Moth
## Scribe partner behind its button shield: one authored guard action appended to the Bulwark
## alone, and a symmetric Guard interception in StitchedRules that lets an enemy-side guard take
## a hero strike aimed at the protected foe. The existing hero Guard (Reckless bypass, thread
## cuts, expiry, stun and hit pipeline) is preserved exactly.
##
## Deterministic and headless: the real data/enemies/run_enemies.json, the canonical
## StitchedEnemyCatalog, the shipped s2 preview party, one seeded RNG per battle, public
## StitchedRules actions for every witness, bounded seed searches for hit witnesses and paired
## same-seed replays. Checks are by required ID; no catalog totals or ordered full-kit lists are
## asserted, so parallel catalog lanes stay merge-safe.

const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const ENCOUNTER_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const BULWARK := "felt_bulwark"
const SCRIBE := "moth_scribe"
const SHELTER := "button_shelter"
const WARDEN := "warden"
const SEAMSTRESS := "seamstress"
const WARDEN_ATTACK := "warden_head_iron_helm"
const SEAMSTRESS_ATTACK := "any_arm_red_thread"
const GUARD_BRACE := "warden_arm_brace"
const WARDEN_BUFF := "warden_torso_quilt"
const SEAMSTRESS_HEAL := "any_torso_felt_coat"
const AIM_RANK := 2
const WARDEN_ATTACK_ACC := 90
const WARDEN_ATTACK_DMG := [5, 8]

var checks := 0
var failures: Array[String] = []
var _catalog: Dictionary = {}
var _base_config: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"the canonical Stitched enemy catalog loads: " + str(_catalog.get("error", "")))
	if not bool(_catalog.get("ok", false)):
		_finish()
		return
	_base_config = _make_base_config()
	_check(not _base_config.is_empty(),
		"preview heroes and the canonical Bulwark+Scribe pair build a 4v2 setup")
	if _base_config.is_empty():
		_finish()
		return
	_test_source_contract()
	_test_catalog_contract()
	_test_live_driver_intent()
	_test_public_shelter()
	_test_redirect_and_expiry()
	_test_guarded_miss()
	_test_refusals_inert()
	_test_no_partner_or_self()
	_test_dead_partner_heap()
	_test_launch_rank()
	_test_dead_guardian()
	_test_hero_guard_preserved()
	_test_ally_actions_not_redirected()
	_test_seeded_replay()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_felt_bulwark_button_shelter_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- fixtures and small helpers

func _make_base_config() -> Dictionary:
	var config: Dictionary = StitchedBattleScreen.read_preview()
	if config.is_empty():
		return {}
	config["seed"] = 1
	config["candle"] = 100
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(_catalog, BULWARK),
		StitchedEnemyCatalog.foe_for(_catalog, SCRIBE),
	]
	if config["foes"][0].is_empty() or config["foes"][1].is_empty():
		return {}
	return config


func _new_battle(seed_value: int, foe_ids: Array = [BULWARK, SCRIBE]) -> StitchedRules:
	var config: Dictionary = _base_config.duplicate(true)
	config["seed"] = seed_value
	config["foes"] = []
	for foe_id in foe_ids:
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(foe_id))
		if foe.is_empty():
			return null
		config["foes"].append(foe)
	var built := StitchedRules.create(config)
	if not bool(built.get("ok", false)):
		return null
	return built["battle"]


## Walks real public turns until actor_id owns the turn. max_round 0 means no round bound.
func _to_actor(battle: StitchedRules, actor_id: String, max_round: int = 0) -> bool:
	for _step in range(240):
		if battle == null or battle.is_over():
			return false
		if max_round > 0 and battle.round_number() > max_round:
			return false
		if battle.current_actor_id() == actor_id:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


## Walks real public turns until actor_id owns the turn in exactly round_value.
func _to_actor_in_round(battle: StitchedRules, actor_id: String, round_value: int) -> bool:
	for _step in range(240):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > round_value:
			return false
		if battle.round_number() == round_value and battle.current_actor_id() == actor_id:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _single_result(receipt: Dictionary) -> Dictionary:
	if not bool(receipt.get("ok", false)):
		return {}
	var results: Array = receipt.get("results", [])
	if results.size() != 1:
		return {}
	return results[0]


func _ability_by_id(foe: Dictionary, ability_id: String) -> Dictionary:
	for ability in foe.get("abilities", []):
		if str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _norm(value: Variant) -> Variant:
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(_norm(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[key] = _norm(value[key])
		return dictionary
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return value


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _raw_record(raw_records: Array, enemy_id: String) -> Dictionary:
	for raw in raw_records:
		if raw is Dictionary and str(raw.get("id", "")) == enemy_id:
			return raw
	return {}


func _raw_ability(record: Dictionary, ability_id: String) -> Dictionary:
	var abilities: Array = record.get("stitched", {}).get("abilities", [])
	for ability in abilities:
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


# ---------------------------------------------------------------- AC1 source record

func _test_source_contract() -> void:
	var raw: Variant = _read_json(RUN_ENEMIES_PATH)
	_check(raw is Array and not (raw as Array).is_empty(),
		"AC1: the real run enemy catalog parses")
	if not raw is Array:
		return
	var record := _raw_record(raw, BULWARK)
	_check(not record.is_empty(), "AC1: the run catalog still authors felt_bulwark by ID")
	if record.is_empty():
		return
	_check(str(record.get("name", "")) == "Felt Bulwark"
		and int(record.get("max_hp", 0)) == 18
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/felt_bulwark.png",
		"AC1: Felt Bulwark keeps its name, original 18 HP and felt art")
	var expected_intent := {
		"target": "front",
		"actions": [
			{"type": "attack", "amount": 5, "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
			{"type": "block", "amount": 3, "weight": 3},
			{"type": "buff", "amount": 2, "weight": 1},
		],
	}
	_check(_norm(record.get("intent", {})) == _norm(expected_intent),
		"AC1: the legacy card intent is byte-for-byte unchanged")
	var stitched: Dictionary = record.get("stitched", {})
	_check(int(stitched.get("max_hp", 0)) == 18
		and int(stitched.get("speed", -1)) == 2
		and int(stitched.get("dodge", -1)) == 2
		and int(stitched.get("acc", -1)) == 0
		and int(stitched.get("prot", -1)) == 10
		and stitched.get("is_boss") == false
		and int(stitched.get("turns_per_round", 0)) == 1
		and str(stitched.get("trophy", "")) == "felt_bulwark_button_shield",
		"AC1: the Stitched profile keeps 18 HP, SPEED 2, DODGE 2, ACC 0, PROT 10, one turn and trophy")
	var expected_slam := {
		"id": "felt_slam",
		"name": "Felt Slam",
		"kind": "melee",
		"launch": [1, 2],
		"target": [1],
		"target_side": "enemy",
		"multi": false,
		"acc": 84,
		"dmg": [3, 4],
		"crit": 0,
		"effects": {},
		"self_move": 0,
		"move": "attack2",
	}
	var expected_pad := {
		"id": "bulwark_pad",
		"name": "Bulwark Pad",
		"kind": "buff",
		"launch": [1, 2],
		"target": [1],
		"target_side": "self",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"thorns": 2},
		"self_move": 0,
		"move": "skill",
	}
	var expected_shelter := {
		"id": "button_shelter",
		"name": "Button Shelter",
		"kind": "guard",
		"launch": [1, 2],
		"target": [2, 3],
		"target_side": "ally",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"guard": 2},
		"self_move": 0,
		"move": "skill",
	}
	# Per-ID assertions: the two existing moves stay exactly authored and the one new record is
	# the authored ally guard. No ordered full-kit list or ability total is asserted.
	_check(_norm(_raw_ability(record, "felt_slam")) == _norm(expected_slam),
		"AC1: Felt Slam is untouched")
	_check(_norm(_raw_ability(record, "bulwark_pad")) == _norm(expected_pad),
		"AC1: the self Thorns-2 Bulwark Pad is untouched")
	_check(_norm(_raw_ability(record, SHELTER)) == _norm(expected_shelter),
		"AC1: Felt Bulwark gains exactly the authored Button Shelter record")
	# The untouched partner keeps its authored kit by ID.
	var scribe := _raw_record(raw, SCRIBE)
	_check(not scribe.is_empty()
		and str(_raw_ability(scribe, "ink_flick").get("id", "")) == "ink_flick"
		and str(_raw_ability(scribe, "dust_scrawl").get("id", "")) == "dust_scrawl",
		"AC1: the Moth Scribe partner keeps its authored Ink Flick and Dust Scrawl")
	# The authored encounter still pairs the two foes, with the Bulwark in front.
	var parsed: Variant = _read_json(ENCOUNTER_PATH)
	var fight: Dictionary = parsed.get("Fight", {}) if parsed is Dictionary else {}
	var pressure: Dictionary = fight.get("felt_moth_pressure", {})
	_check(pressure.get("enemy_ids") == [BULWARK, SCRIBE],
		"AC1: the authored felt_moth_pressure fight still pairs Felt Bulwark and Moth Scribe")
	# Named neighbours stay present by ID, never by a catalog total or index.
	var swarm := _raw_record(raw, "moth_swarm")
	var skitter := _raw_record(raw, "pin_skitter")
	_check(not swarm.is_empty() and str(swarm.get("stitched", {}).get("abilities", [{}])[0].get("id", "")) == "wing_dust"
		and not skitter.is_empty()
		and str(skitter.get("stitched", {}).get("abilities", [{}])[0].get("id", "")) == "pin_prick",
		"AC1: named neighbouring enemy kits remain their own authored records")


# ---------------------------------------------------------------- AC1 normalized catalog

func _test_catalog_contract() -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, BULWARK)
	_check(not foe.is_empty(), "AC1: foe_for resolves the canonical felt_bulwark kit")
	if foe.is_empty():
		return
	_check(str(foe.get("id", "")) == BULWARK and str(foe.get("name", "")) == "Felt Bulwark"
		and int(foe.get("max_hp", 0)) == 18
		and int(foe.get("speed", -1)) == 2
		and int(foe.get("dodge", -1)) == 2
		and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 10
		and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the normalized foe keeps 18 HP, SPEED 2, DODGE 2, ACC 0, PROT 10 and one turn")
	_check(str(StitchedEnemyCatalog.trophy_for(_catalog, BULWARK)) == "felt_bulwark_button_shield",
		"AC1: the normalized foe still drops the button shield trophy")
	var slam := _ability_by_id(foe, "felt_slam")
	var pad := _ability_by_id(foe, "bulwark_pad")
	var shelter := _ability_by_id(foe, SHELTER)
	_check(not slam.is_empty()
		and slam.get("launch") == [1, 2] and slam.get("target") == [1]
		and int(slam.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
		and int(slam.get("target_mask", 0)) == StitchedParts.rank_mask([1])
		and str(slam.get("kind", "")) == "melee" and str(slam.get("target_side", "")) == "enemy"
		and int(slam.get("acc", 0)) == 84 and slam.get("dmg") == [3, 4]
		and slam.get("effects") == {} and str(slam.get("move", "")) == "attack2",
		"AC1: normalized Felt Slam keeps its melee ranks, ACC 84, 3-4 damage and attack2 pose")
	_check(not pad.is_empty()
		and pad.get("launch") == [1, 2] and pad.get("target") == [1]
		and int(pad.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
		and int(pad.get("target_mask", 0)) == StitchedParts.rank_mask([1])
		and str(pad.get("kind", "")) == "buff" and str(pad.get("target_side", "")) == "self"
		and pad.get("effects") == {"thorns": 2} and str(pad.get("move", "")) == "skill",
		"AC1: normalized Bulwark Pad stays a self Thorns-2 buff with the skill pose")
	_check(not shelter.is_empty()
		and str(shelter.get("name", "")) == "Button Shelter"
		and str(shelter.get("kind", "")) == "guard"
		and shelter.get("launch") == [1, 2] and shelter.get("target") == [2, 3]
		and int(shelter.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
		and int(shelter.get("target_mask", 0)) == StitchedParts.rank_mask([2, 3])
		and str(shelter.get("target_side", "")) == "ally"
		and shelter.get("multi") == false
		and int(shelter.get("acc", 0)) == 100 and shelter.get("dmg") == [0, 0]
		and int(shelter.get("crit", -1)) == 0 and int(shelter.get("mark_damage", -1)) == 0
		and shelter.get("effects") == {"guard": 2}
		and int(shelter.get("self_move", -1)) == 0
		and str(shelter.get("move", "")) == "skill",
		"AC1: normalized Button Shelter guards only living allies in ranks 2-3 from launch 1-2")
	var validated := StitchedParts.validate_ability(shelter, "test button_shelter")
	_check(bool(validated.get("ok", false))
		and validated.get("ability", {}).get("effects") == {"guard": 2}
		and str(validated.get("ability", {}).get("target_side", "")) == "ally"
		and str(validated.get("ability", {}).get("kind", "")) == "guard",
		"AC1: StitchedParts.validate_ability accepts Button Shelter as an ally guard")


# ---------------------------------------------------------------- live foe driver reachability

func _test_live_driver_intent() -> void:
	# The shipped battle screen feeds StitchedFoeIntent.choose into use_foe_ability. The new
	# authored action must be reachable through that same real driver, not only a direct call.
	var battle := _new_battle(645500)
	_check(battle != null, "AC2: seeded Bulwark+Scribe battle builds for the live driver")
	if battle == null:
		return
	if not _to_actor_in_round(battle, BULWARK, 3):
		_check(false, "AC2: the Bulwark reaches its genuine round-three turn")
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BULWARK))
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC2: the live intent projection stays state and RNG read-only")
	_check(str(intent.get("ability_id", "")) == SHELTER
		and str(intent.get("ability_kind", "")) == "guard"
		and not bool(intent.get("pass", true))
		and int(intent.get("target_rank", 0)) == AIM_RANK
		and intent.get("affected_ranks", []) == [AIM_RANK]
		and intent.get("base_effects", {}) == {"guard": 2},
		"AC2: the real foe driver announces Button Shelter on the living rank-2 Scribe")
	var cast := battle.use_foe_ability(str(intent.get("ability_id", "")), int(intent.get("target_rank", 0)))
	_check(bool(cast.get("ok", false)) and str(cast.get("ability", "")) == SHELTER
		and int(battle.get_unit(BULWARK)["statuses"].get("guard", 0)) == 2
		and str(battle.get_unit(BULWARK).get("guard_target", "")) == SCRIBE,
		"AC2: the driver's announced action commits the same Guard 2 on the Bulwark")


# ---------------------------------------------------------------- AC2 public Button Shelter

func _play_shelter(seed_value: int) -> Dictionary:
	var battle := _new_battle(seed_value)
	if battle == null or not _to_actor(battle, BULWARK, 1):
		return {}
	var before := battle.state_snapshot()
	var bulwark_before := battle.get_unit(BULWARK)
	var scribe_before := battle.get_unit(SCRIBE)
	var order_once := battle.turn_order().count(BULWARK) == 1
	var cast := battle.use_foe_ability(SHELTER, AIM_RANK)
	return {
		"battle": battle,
		"before": before,
		"order_once": order_once,
		"cast": cast,
		"bulwark_before": bulwark_before,
		"scribe_before": scribe_before,
		"bulwark_after": battle.get_unit(BULWARK),
		"scribe_after": battle.get_unit(SCRIBE),
		"snapshot": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"next_actor": battle.current_actor_id(),
	}


func _find_shelter_seed() -> int:
	for seed_value in range(646100, 646500):
		var run := _play_shelter(seed_value)
		if run.is_empty():
			continue
		var bulwark_after: Dictionary = run["bulwark_after"]
		if bool(run["cast"].get("ok", false)) \
				and int(bulwark_after["statuses"].get("guard", 0)) == 2 \
				and str(run["next_actor"]) != BULWARK:
			return seed_value
	return -1


func _test_public_shelter() -> void:
	var seed_value := _find_shelter_seed()
	_check(seed_value > 0, "AC2: bounded seed witness for a genuine round-one Felt Bulwark turn")
	if seed_value <= 0:
		return
	var run := _play_shelter(seed_value)
	_check(not run.is_empty(),
		"AC2: the seeded 4v2 Bulwark+Scribe battle reaches the Bulwark's own turn")
	if run.is_empty():
		return
	var cast: Dictionary = run["cast"]
	var hit := _single_result(cast)
	var bulwark_before: Dictionary = run["bulwark_before"]
	var bulwark_after: Dictionary = run["bulwark_after"]
	var scribe_before: Dictionary = run["scribe_before"]
	var scribe_after: Dictionary = run["scribe_after"]
	_check(bool(cast.get("ok", false)) and str(cast.get("action", "")) == "ability"
		and str(cast.get("actor", "")) == BULWARK and str(cast.get("ability", "")) == SHELTER,
		"AC2: public use_foe_ability(button_shelter, 2) commits on the Bulwark's real turn")
	_check(not hit.is_empty()
		and str(hit.get("target", "")) == SCRIBE
		and str(hit.get("target_side", "")) == "foe"
		and int(hit.get("target_rank", 0)) == AIM_RANK,
		"AC2: the single result is the living rank-2 Moth Scribe")
	_check(not hit.is_empty() and bool(hit.get("hit", false))
		and int(hit.get("damage", -1)) == 0
		and not bool(hit.get("crit", true))
		and hit.get("statuses", []) == [{"status": "guard", "duration": 2, "guards": SCRIBE}],
		"AC2: the shelter is a zero-damage Guard 2 receipt on the Scribe")
	_check(int(bulwark_after["statuses"].get("guard", 0)) == 2
		and str(bulwark_after.get("guard_target", "")) == SCRIBE,
		"AC2: the authoritative Bulwark snapshot carries Guard 2 aimed at the Scribe")
	_check(scribe_after == scribe_before,
		"AC2: the Scribe is only the protected ally: HP, statuses and fray untouched")
	_check(int(bulwark_after.get("hp", 0)) == int(bulwark_before.get("hp", -1))
		and bulwark_after["statuses"] == {"guard": 2},
		"AC2: the ability causes no attack, damage or unrelated status")
	_check(bool(run["order_once"]),
		"AC2: the ordinary non-boss Bulwark owns exactly one turn in the round")
	_check(int(run["before"]["round"]) != int(run["snapshot"]["round"])
		or int(run["before"]["turn_index"]) != int(run["snapshot"]["turn_index"]),
		"AC2: the cast spends exactly one foe turn")
	# Same seed and the same real sequence replay the cast, state and RNG exactly.
	var replay := _play_shelter(seed_value)
	_check(not replay.is_empty()
		and _norm(replay["cast"]) == _norm(run["cast"])
		and _norm(replay["snapshot"]) == _norm(run["snapshot"])
		and int(replay["rng"]) == int(run["rng"]),
		"AC2: an identical seed and action sequence replays the shelter, snapshot and RNG")


# ---------------------------------------------------------------- AC3 redirect and expiry

func _possible_damages(attacker: Dictionary, defender: Dictionary, crit: bool) -> Array:
	var values: Array = []
	var bonus := int(attacker.get("dmg_bonus", 0))
	var defender_statuses: Dictionary = defender.get("statuses", {})
	var attacker_statuses: Dictionary = attacker.get("statuses", {})
	var marked := int(defender_statuses.get("mark", 0)) > 0
	var prot := int(defender.get("prot", 0))
	if crit:
		values.append(StitchedRules.damage_after_modifiers(
			StitchedRules.crit_damage(int(WARDEN_ATTACK_DMG[1])) + bonus,
			attacker_statuses, defender_statuses, marked, 0, prot))
		return values
	for rolled in range(int(WARDEN_ATTACK_DMG[0]), int(WARDEN_ATTACK_DMG[1]) + 1):
		values.append(StitchedRules.damage_after_modifiers(
			rolled + bonus, attacker_statuses, defender_statuses, marked, 0, prot))
	return values


func _probe_redirect(seed_value: int, require_hit: bool = true) -> Dictionary:
	var run := _play_shelter(seed_value)
	if run.is_empty():
		return {}
	var battle: StitchedRules = run["battle"]
	if not _to_actor(battle, WARDEN, 0):
		return {}
	var warden := battle.get_unit(WARDEN)
	var head: Dictionary = warden.get("parts", {}).get("head", {})
	if str(head.get("id", "")) != WARDEN_ATTACK or bool(head.get("torn", false)):
		return {}
	var bulwark := battle.get_unit(BULWARK)
	var scribe := battle.get_unit(SCRIBE)
	var attack := battle.use_part(WARDEN_ATTACK, AIM_RANK)
	var hit := _single_result(attack)
	if not bool(attack.get("ok", false)) or hit.is_empty():
		return {}
	if str(hit.get("guarded_by", "")) != BULWARK or bool(hit.get("hit", false)) != require_hit:
		return {}
	run["warden_before"] = warden
	run["bulwark_before_attack"] = bulwark
	run["scribe_before_attack"] = scribe
	run["guard_before_attack"] = int(bulwark["statuses"].get("guard", 0))
	run["attack"] = attack
	run["hit"] = hit
	run["bulwark_after_attack"] = battle.get_unit(BULWARK)
	run["scribe_after_attack"] = battle.get_unit(SCRIBE)
	return run


func _find_redirect_seed(require_hit: bool = true) -> int:
	for seed_value in range(647100, 647800):
		if not _probe_redirect(seed_value, require_hit).is_empty():
			return seed_value
	return -1


func _test_redirect_and_expiry() -> void:
	var seed_value := _find_redirect_seed()
	_check(seed_value > 0,
		"AC3: bounded seed witness for a genuine landed strike on the sheltered Scribe")
	if seed_value <= 0:
		return
	var run := _probe_redirect(seed_value)
	_check(not run.is_empty(),
		"AC3: the same seed reaches a real Warden turn with the enemy Guard still active")
	if run.is_empty():
		return
	var battle: StitchedRules = run["battle"]
	var hit: Dictionary = run["hit"]
	var warden: Dictionary = run["warden_before"]
	var bulwark: Dictionary = run["bulwark_before_attack"]
	var scribe: Dictionary = run["scribe_before_attack"]
	var bulwark_after: Dictionary = run["bulwark_after_attack"]
	var scribe_after: Dictionary = run["scribe_after_attack"]
	_check(int(run["guard_before_attack"]) > 0,
		"AC3: the Bulwark's Guard is still active when the hero strikes")
	_check(str(hit.get("guarded_by", "")) == BULWARK
		and str(hit.get("target", "")) == BULWARK
		and int(hit.get("target_rank", 0)) == 1
		and str(hit.get("target_side", "")) == "foe",
		"AC3: the receipt names the Bulwark as guarded_by and as the real target")
	_check(int(scribe_after.get("hp", -1)) == int(scribe.get("hp", -2))
		and scribe_after.get("statuses", {}) == scribe.get("statuses", {}),
		"AC3: the protected Scribe's HP and statuses take no part of the redirected hit")
	_check(int(hit.get("damage", 0)) > 0
		and int(bulwark_after.get("hp", 0)) == int(bulwark.get("hp", -1)) - int(hit.get("damage", 0)),
		"AC3: exactly one landed hit damages the Bulwark for the receipt's damage")
	var expected_chance := StitchedRules.hit_chance(
		WARDEN_ATTACK_ACC + int(warden.get("acc", 0)),
		StitchedRules.effective_dodge(bulwark),
		int(warden.get("miss_streak", 0)))
	_check(int(hit.get("hit_chance", -1)) == expected_chance,
		"AC3: ordinary ACC/DODGE hit chance is used against the guarding Bulwark")
	_check(_possible_damages(warden, bulwark, bool(hit.get("crit", false))).has(
		int(hit.get("damage", -1))),
		"AC3: the landed damage is an ordinary PROT-cut damage value")
	_check(int(bulwark_after["statuses"].get("weak", 0)) == 1
		and int(scribe_after["statuses"].get("weak", 0)) == 0,
		"AC3: the strike's Weak 1 lands once on the Bulwark, not the Scribe")
	# Real public turns carry the Guard to its own expiry.
	var expired := false
	for _step in range(80):
		if battle.is_over():
			break
		var now := battle.get_unit(BULWARK)
		if int(now["statuses"].get("guard", 0)) == 0 and str(now.get("guard_target", "")).is_empty():
			expired = true
			break
		if not bool(battle.pass_turn().get("ok", false)):
			break
	_check(expired, "AC3: the Bulwark's Guard really expires on its own later turns")
	if not expired:
		return
	if not _to_actor(battle, WARDEN, 0):
		_check(false, "AC3: a later real Warden turn follows the expiry")
		return
	var open_bulwark := battle.get_unit(BULWARK)
	var open_scribe := battle.get_unit(SCRIBE)
	var open_attack := battle.use_part(WARDEN_ATTACK, AIM_RANK)
	var open_hit := _single_result(open_attack)
	_check(not open_hit.is_empty()
		and str(open_hit.get("target", "")) == SCRIBE
		and int(open_hit.get("target_rank", 0)) == AIM_RANK
		and not open_hit.has("guarded_by"),
		"AC3: after expiry the same legal attack reaches the aimed Moth Scribe normally")
	if not open_hit.is_empty() and bool(open_hit.get("hit", false)):
		_check(int(battle.get_unit(SCRIBE).get("hp", 0))
			== int(open_scribe.get("hp", -1)) - int(open_hit.get("damage", 0))
			and int(battle.get_unit(BULWARK).get("hp", -1)) == int(open_bulwark.get("hp", -2)),
			"AC3: the post-expiry hit lands on the Scribe and leaves the Bulwark alone")


# ---------------------------------------------------------------- AC3 guarded miss

func _test_guarded_miss() -> void:
	var seed_value := _find_redirect_seed(false)
	_check(seed_value > 0,
		"AC3: bounded seed witness for a missed strike on the sheltered Scribe")
	if seed_value <= 0:
		return
	var run := _probe_redirect(seed_value, false)
	_check(not run.is_empty(),
		"AC3: the miss seed reaches a real Warden turn with the enemy Guard still active")
	if run.is_empty():
		return
	var hit: Dictionary = run["hit"]
	var bulwark: Dictionary = run["bulwark_before_attack"]
	var scribe: Dictionary = run["scribe_before_attack"]
	_check(not bool(hit.get("hit", true))
		and str(hit.get("guarded_by", "")) == BULWARK
		and str(hit.get("target", "")) == BULWARK
		and int(hit.get("target_rank", 0)) == 1
		and int(hit.get("damage", -1)) == 0,
		"AC3: a miss is rolled against the guarding Bulwark, never the Scribe")
	_check(int(run["bulwark_after_attack"].get("hp", -1)) == int(bulwark.get("hp", -2))
		and run["scribe_after_attack"].get("hp", -1) == scribe.get("hp", -2)
		and run["scribe_after_attack"].get("statuses", {}) == scribe.get("statuses", {}),
		"AC3: the guarded miss damages and marks neither the Bulwark nor the Scribe")
	_check(int(run["warden_before"].get("miss_streak", 0)) + 1
		== int(run["battle"].get_unit(WARDEN).get("miss_streak", -1)),
		"AC3: an ordinary miss still raises the attacker's miss streak")


# ---------------------------------------------------------------- AC4 refusals and negatives
func _test_refusals_inert() -> void:
	var seed_value := _find_shelter_seed()
	if seed_value <= 0:
		_check(false, "AC4: refusal witness seed exists")
		return
	var battle := _new_battle(seed_value)
	if battle == null or not _to_actor(battle, WARDEN, 1):
		_check(false, "AC4: refusal witness reaches a real hero turn")
		return
	# Off-turn: a hero owns the turn, so a foe ability must fail closed.
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var off_turn := battle.use_foe_ability(SHELTER, AIM_RANK)
	_check(not bool(off_turn.get("ok", true))
		and str(off_turn.get("error", "")).contains("not a foe turn")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: an off-turn Button Shelter is refused with identical state and RNG")
	if not _to_actor(battle, BULWARK, 1):
		_check(false, "AC4: refusal witness reaches the Bulwark's own turn")
		return
	state = battle.state_snapshot()
	rng = battle.rng_state()
	var self_rank := battle.use_foe_ability(SHELTER, 1)
	var empty_rank := battle.use_foe_ability(SHELTER, 4)
	_check(not bool(self_rank.get("ok", true))
		and str(self_rank.get("error", "")).contains("no legal target in rank 1")
		and not bool(empty_rank.get("ok", true))
		and str(empty_rank.get("error", "")).contains("no legal target in rank 4")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: the Bulwark's own rank and an empty rank are refused without state or RNG")


func _test_no_partner_or_self() -> void:
	# Scribe in front, Bulwark behind: rank 2 is the Bulwark itself and rank 3 has no ally.
	var battle := _new_battle(648100, [SCRIBE, BULWARK])
	_check(battle != null and int(battle.get_unit(BULWARK)["rank"]) == AIM_RANK,
		"AC4: the reversed pair really places the Bulwark in rank 2")
	if battle == null:
		return
	if not _to_actor(battle, BULWARK, 0):
		_check(false, "AC4: the rank-2 Bulwark still gets a real turn")
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var self_cast := battle.use_foe_ability(SHELTER, AIM_RANK)
	var empty_cast := battle.use_foe_ability(SHELTER, 3)
	_check(not bool(self_cast.get("ok", true))
		and str(self_cast.get("error", "")).contains("no legal target in rank 2")
		and not bool(empty_cast.get("ok", true))
		and str(empty_cast.get("error", "")).contains("no legal target in rank 3")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: a self-guard and a missing partner rank fail closed without state or RNG")


func _hero_attack_or_pass(battle: StitchedRules, rank: int) -> bool:
	var actor_id := battle.current_actor_id()
	var part_id := ""
	if actor_id == WARDEN:
		part_id = WARDEN_ATTACK
	elif actor_id == SEAMSTRESS:
		part_id = SEAMSTRESS_ATTACK
	if not part_id.is_empty():
		var receipt := battle.use_part(part_id, rank)
		if bool(receipt.get("ok", false)):
			return true
	return bool(battle.pass_turn().get("ok", false))


func _probe_dead_partner(seed_value: int) -> Dictionary:
	var battle := _new_battle(seed_value)
	if battle == null:
		return {}
	for _step in range(200):
		if battle.is_over():
			return {}
		if bool(battle.get_unit(SCRIBE).get("dead", false)):
			return {"battle": battle}
		if battle.current_side() == "hero":
			if not _hero_attack_or_pass(battle, AIM_RANK):
				return {}
		elif not bool(battle.pass_turn().get("ok", false)):
			return {}
	return {}


func _test_dead_partner_heap() -> void:
	var run: Dictionary = {}
	var seed_value := 0
	for candidate in range(648500, 648900):
		run = _probe_dead_partner(candidate)
		if not run.is_empty():
			seed_value = candidate
			break
	_check(seed_value > 0, "AC4: bounded seed witness for a publicly felled Scribe")
	if seed_value <= 0:
		return
	var battle: StitchedRules = run["battle"]
	var heap_rank := 0
	for heap in battle.get_heaps():
		if str(heap.get("foe_id", "")) == SCRIBE:
			heap_rank = int(heap.get("rank", 0))
	_check(heap_rank == AIM_RANK,
		"AC4: the fallen Scribe's scrap heap really occupies the aimed rank 2")
	if not _to_actor(battle, BULWARK, 0):
		_check(false, "AC4: the Bulwark still gets a real turn after its partner falls")
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var cast := battle.use_foe_ability(SHELTER, AIM_RANK)
	_check(not bool(cast.get("ok", true))
		and str(cast.get("error", "")).contains("no legal target in rank 2")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: Button Shelter refuses a scrap-heap rank inertly and never guards the dead")


func _test_launch_rank() -> void:
	# A canonical three-foe line puts the Bulwark in rank 3, outside its authored launch 1-2.
	var battle := _new_battle(649300, ["pin_skitter", SCRIBE, BULWARK])
	_check(battle != null and int(battle.get_unit(BULWARK)["rank"]) == 3,
		"AC4: the three-foe line really places the Bulwark in rank 3")
	if battle == null:
		return
	if not _to_actor(battle, BULWARK, 0):
		_check(false, "AC4: the rank-3 Bulwark still gets a real turn")
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var cast := battle.use_foe_ability(SHELTER, AIM_RANK)
	_check(not bool(cast.get("ok", true))
		and str(cast.get("error", "")).contains("cannot launch from rank 3")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: a Bulwark outside its launch ranks fails closed without state or RNG")


func _probe_dead_guardian(seed_value: int) -> Dictionary:
	var run := _play_shelter(seed_value)
	if run.is_empty():
		return {}
	var battle: StitchedRules = run["battle"]
	var guard_before_kill := -1
	var killed := false
	for _step in range(200):
		if battle.is_over():
			break
		var bulwark := battle.get_unit(BULWARK)
		if bool(bulwark.get("dead", false)):
			killed = true
			break
		if battle.current_side() == "hero":
			guard_before_kill = int(bulwark["statuses"].get("guard", 0))
			var part_id := ""
			if battle.current_actor_id() == WARDEN:
				part_id = WARDEN_ATTACK
			elif battle.current_actor_id() == SEAMSTRESS:
				part_id = SEAMSTRESS_ATTACK
			var struck := false
			if not part_id.is_empty():
				struck = bool(battle.use_part(part_id, 1).get("ok", false))
			if not struck and not bool(battle.pass_turn().get("ok", false)):
				break
		elif not bool(battle.pass_turn().get("ok", false)):
			break
	if not killed:
		return {}
	run["guard_before_kill"] = guard_before_kill
	run["dead_bulwark"] = battle.get_unit(BULWARK)
	return run


func _test_dead_guardian() -> void:
	var run: Dictionary = {}
	var seed_value := 0
	for candidate in range(650100, 650600):
		run = _probe_dead_guardian(candidate)
		if not run.is_empty() and int(run.get("guard_before_kill", 0)) > 0:
			seed_value = candidate
			break
	_check(seed_value > 0,
		"AC4: bounded seed witness for a Bulwark that dies with its Guard still live")
	if seed_value <= 0:
		return
	var battle: StitchedRules = run["battle"]
	var dead: Dictionary = run["dead_bulwark"]
	_check(bool(dead.get("dead", false)) and dead.get("statuses", {}).is_empty(),
		"AC4: a fallen foe guardian keeps no Guard status")
	if not _to_actor(battle, WARDEN, 0):
		_check(false, "AC4: a real Warden turn follows the guardian's death")
		return
	var scribe_before := battle.get_unit(SCRIBE)
	var strike := battle.use_part(WARDEN_ATTACK, AIM_RANK)
	var hit := _single_result(strike)
	_check(not hit.is_empty() and str(hit.get("target", "")) == SCRIBE
		and not hit.has("guarded_by"),
		"AC4: a dead guardian never redirects a later strike aimed at the Scribe")
	if not hit.is_empty() and bool(hit.get("hit", false)):
		_check(int(battle.get_unit(SCRIBE).get("hp", 0))
			== int(scribe_before.get("hp", -1)) - int(hit.get("damage", 0)),
			"AC4: the unguarded post-death hit lands on the Scribe itself")


func _test_hero_guard_preserved() -> void:
	# The Tinker really wears the guard brace. Step it forward into rank 2 (public move) so the
	# brace's authored launch ranks allow it, then guard the front Warden.
	var guard_battle := _new_battle(651100)
	if guard_battle == null or not _to_actor(guard_battle, "tinker", 1):
		_check(false, "AC4: hero-guard witness reaches a real Tinker turn")
		return
	var stepped := guard_battle.move(-1)
	_check(bool(stepped.get("ok", false))
		and int(guard_battle.get_unit("tinker")["rank"]) == 2,
		"AC4: the Tinker steps forward so its equipped brace can launch")
	if not bool(stepped.get("ok", false)) or not _to_actor(guard_battle, "tinker", 2):
		_check(false, "AC4: the Tinker reaches its next real turn")
		return
	var cast := guard_battle.use_part(GUARD_BRACE, 1)
	var tinker := guard_battle.get_unit("tinker")
	_check(bool(cast.get("ok", false))
		and int(tinker["statuses"].get("guard", 0)) == 2
		and str(tinker.get("guard_target", "")) == WARDEN,
		"AC4: the existing hero Guard still guards the living front doll")
	# The Bulwark's ordinary Felt Slam aimed at rank 1 must still be taken by the hero guardian.
	var reached := false
	for _step in range(40):
		if guard_battle.is_over():
			break
		if int(guard_battle.get_unit("tinker")["statuses"].get("guard", 0)) <= 0:
			break
		if guard_battle.current_actor_id() == BULWARK:
			reached = true
			break
		if not bool(guard_battle.pass_turn().get("ok", false)):
			break
	_check(reached, "AC4: the Bulwark reaches a real turn while the hero Guard is live")
	if not reached:
		return
	var warden_before := guard_battle.get_unit(WARDEN)
	var slam := guard_battle.use_foe_ability("felt_slam", 1)
	var slam_hit := _single_result(slam)
	_check(not slam_hit.is_empty()
		and str(slam_hit.get("guarded_by", "")) == "tinker"
		and str(slam_hit.get("target", "")) == "tinker"
		and int(slam_hit.get("target_rank", 0)) == 2
		and int(guard_battle.get_unit(WARDEN).get("hp", 0)) == int(warden_before.get("hp", -1)),
		"AC4: the existing hero Guard still intercepts a foe hit aimed at its doll")
	# A hero Guard never crosses teams: a hero strike aimed at a foe is not redirected.
	var foe_battle := _new_battle(651200)
	if foe_battle == null or not _to_actor(foe_battle, "tinker", 1):
		_check(false, "AC4: cross-team witness reaches a real Tinker turn")
		return
	if not bool(foe_battle.move(-1).get("ok", false)) or not _to_actor(foe_battle, "tinker", 2):
		_check(false, "AC4: cross-team witness steps the Tinker forward")
		return
	if not bool(foe_battle.use_part(GUARD_BRACE, 1).get("ok", false)):
		_check(false, "AC4: cross-team witness keeps a live hero Guard")
		return
	if not _to_actor(foe_battle, WARDEN, 0):
		_check(false, "AC4: cross-team witness reaches the Warden's next turn")
		return
	_check(int(foe_battle.get_unit("tinker")["statuses"].get("guard", 0)) > 0,
		"AC4: the hero Guard is still live when the Warden strikes a foe")
	var foe_strike := foe_battle.use_part(WARDEN_ATTACK, AIM_RANK)
	var foe_hit := _single_result(foe_strike)
	_check(not foe_hit.is_empty()
		and str(foe_hit.get("target", "")) == SCRIBE
		and not foe_hit.has("guarded_by"),
		"AC4: a hero Guard never redirects a strike aimed at a foe")


func _test_ally_actions_not_redirected() -> void:
	# Let the Bulwark's real Felt Slam wound the Warden, then heal and buff allies publicly.
	var battle := _new_battle(652100)
	_check(battle != null, "AC4: ally-action witness battle builds")
	if battle == null:
		return
	var wounded := false
	for _step in range(80):
		if battle.is_over():
			break
		if int(battle.get_unit(WARDEN).get("hp", 0)) < int(battle.get_unit(WARDEN).get("max_hp", 0)):
			wounded = true
			break
		if battle.current_actor_id() == BULWARK:
			var slam := battle.use_foe_ability("felt_slam", 1)
			if bool(slam.get("ok", false)):
				continue
		if not bool(battle.pass_turn().get("ok", false)):
			break
	_check(wounded, "AC4: the Bulwark's ordinary Felt Slam really wounds the front doll")
	if not wounded:
		return
	# The rear Lantern Monk wears the ally mending coat (launch 1 or 4) and heals the Warden.
	if not _to_actor(battle, "lantern_monk", 0):
		_check(false, "AC4: the Lantern Monk reaches a real turn for the ally heal")
		return
	var warden_before := battle.get_unit(WARDEN)
	var heal := battle.use_part(SEAMSTRESS_HEAL, 1)
	var heal_hit := _single_result(heal)
	var healed := int(battle.get_unit(WARDEN).get("hp", 0)) - int(warden_before.get("hp", 0))
	_check(not heal_hit.is_empty()
		and str(heal_hit.get("target", "")) == WARDEN
		and not heal_hit.has("guarded_by")
		and healed > 0,
		"AC4: an ally-targeted heal resolves on its doll and is never redirected")
	# The Warden's quilt buff is an ally buff on the rear rank, never a guard redirect.
	if not _to_actor(battle, WARDEN, 0):
		_check(false, "AC4: the Warden reaches a real turn for the ally buff")
		return
	var monk_before := battle.get_unit("lantern_monk")
	var buff := battle.use_part(WARDEN_BUFF, 4)
	var buff_hit := _single_result(buff)
	var monk_after := battle.get_unit("lantern_monk")
	_check(not buff_hit.is_empty()
		and str(buff_hit.get("target", "")) == "lantern_monk"
		and not buff_hit.has("guarded_by")
		and int(monk_after["statuses"].get("thorns", 0)) == 2
		and monk_after["statuses"].get("thorns", 0) != monk_before["statuses"].get("thorns", 0),
		"AC4: an ally-targeted buff lands on its doll and is never redirected")


# ---------------------------------------------------------------- AC4 seeded replay

func _scripted_trace(seed_value: int) -> Array:
	var battle := _new_battle(seed_value)
	if battle == null or not _to_actor(battle, BULWARK, 1):
		return []
	var trace: Array = []
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BULWARK))
	var cast := battle.use_foe_ability(SHELTER, AIM_RANK)
	trace.append({
		"step": "shelter", "intent": intent, "receipt": cast,
		"snapshot": battle.state_snapshot(), "rng": battle.rng_state(),
		"actor": battle.current_actor_id(),
	})
	if not _to_actor(battle, WARDEN, 0):
		return []
	var guarded := battle.use_part(WARDEN_ATTACK, AIM_RANK)
	trace.append({
		"step": "guarded_attack", "receipt": guarded,
		"snapshot": battle.state_snapshot(), "rng": battle.rng_state(),
		"actor": battle.current_actor_id(),
	})
	for _step in range(80):
		if battle.is_over():
			return trace
		if int(battle.get_unit(BULWARK)["statuses"].get("guard", 0)) == 0:
			break
		if not bool(battle.pass_turn().get("ok", false)):
			return trace
	if not _to_actor(battle, WARDEN, 0):
		return trace
	var open := battle.use_part(WARDEN_ATTACK, AIM_RANK)
	trace.append({
		"step": "open_attack", "receipt": open,
		"snapshot": battle.state_snapshot(), "rng": battle.rng_state(),
		"actor": battle.current_actor_id(),
	})
	return trace


func _test_seeded_replay() -> void:
	var seed_value := _find_redirect_seed()
	_check(seed_value > 0, "AC4: bounded replay seed witness exists")
	if seed_value <= 0:
		return
	var first := _scripted_trace(seed_value)
	var second := _scripted_trace(seed_value)
	_check(first.size() == 3 and second.size() == 3 and _norm(first) == _norm(second),
		"AC4: identical seed and legal action sequence replay intents, receipts, state and RNG")
	_check(first.size() == 3
		and str(first[0]["step"]) == "shelter"
		and str(first[1]["step"]) == "guarded_attack"
		and str(first[2]["step"]) == "open_attack",
		"AC4: the replayed script really shelters, strikes the guard, then strikes openly")
	if first.size() == 3:
		var sheltered: Dictionary = first[0]["receipt"]
		var sheltered_result := _single_result(sheltered)
		var sheltered_statuses: Array = sheltered_result.get("statuses", [])
		var guarded_hit := _single_result(first[1]["receipt"])
		var open_hit := _single_result(first[2]["receipt"])
		_check(bool(sheltered.get("ok", false))
			and sheltered_statuses.size() == 1
			and int(sheltered_statuses[0].get("duration", 0)) == 2
			and str(sheltered_statuses[0].get("guards", "")) == SCRIBE
			and str(guarded_hit.get("guarded_by", "")) == BULWARK
			and str(open_hit.get("target", "")) == SCRIBE
			and not open_hit.has("guarded_by"),
			"AC4: the replayed receipts keep the shelter, the redirect and the open strike")
