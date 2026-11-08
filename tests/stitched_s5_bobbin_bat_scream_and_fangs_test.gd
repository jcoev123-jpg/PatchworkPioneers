extends SceneTree
## S5 Bobbin Bat pin-fang and sonar change.
##
## The shipped run roster's single Bobbin Bat deliberately retunes two of its three authored
## Stitched actions: Bobbin Dive now reaches only the front doll and applies Bleed 1 on a
## confirmed hit (ACC 88, damage 3-4), and Sonar Shriek now rolls independently against every
## living doll in ranks 1-4 as a multi-target debuff that applies Fray 4 only to hits. The
## third action, Bobbin Drop, its legacy card intent, stats, trophy and every other foe stay
## untouched.
##
## Everything is exercised through the real StitchedEnemyCatalog, StitchedFoeIntent and
## StitchedRules public turns on the real four-doll preview party plus the canonical Bobbin and
## a real normal escort. Per-ID source lookups only: no catalog total or full ID order.
## Deterministic: one seeded RandomNumberGenerator per battle, a bounded seed witness search for
## a hit and a miss, and a public live-screen driver. The preview heroes occupy ranks 1-4 in
## their authored array order.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const POSES := "res://data/art/move_poses.json"

const BAT := "bobbin_bat"
const RAGLING := "ragling"
const GUARD := "button_guard"
const HOUND := "spoolback_hound"

const SEED_LIMIT := 48
const TURN_LIMIT := 240
const LIVE_PASSES := 24

const BOBBIN_DIVE := {
	"id": "bobbin_dive", "name": "Bobbin Dive", "kind": "melee",
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [3, 4], "crit": 0, "effects": {"bleed": 1},
	"self_move": 0, "move": "attack2",
}
const SONAR_SHRIEK := {
	"id": "sonar_shriek", "name": "Sonar Shriek", "kind": "debuff",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"fray": 4},
	"self_move": 0, "move": "skill",
}
const BOBBIN_DROP := {
	"id": "bobbin_drop", "name": "Bobbin Drop", "kind": "ranged",
	"launch": [2, 3, 4], "target": [2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 84, "dmg": [2, 3], "crit": 0, "effects": {}, "self_move": 0, "move": "attack3",
}
const BAT_PROFILE := {
	"max_hp": 27, "speed": 8, "dodge": 11, "acc": 0, "prot": 0,
	"is_boss": false, "turns_per_round": 1, "trophy": "bobbin_bat_wing",
	"abilities": [BOBBIN_DIVE, SONAR_SHRIEK, BOBBIN_DROP],
}
const BAT_INTENT := {"target": "lowest_living_hp", "actions": [
	{"type": "attack", "amount": 7, "hits": 2, "weight": 4},
	{"type": "debuff", "status": "weak", "amount": 1, "weight": 1},
	{"type": "block", "amount": 4, "weight": 1},
	{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
	{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
]}
const HOUND_REDLINE := {
	"id": "redline_reel", "name": "Redline Reel", "kind": "ranged",
	"launch": [1, 2, 3], "target": [2, 3, 4], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [2, 4], "crit": 0, "effects": {"pull": 1}, "self_move": 0, "move": "attack3",
}

var failures: Array[String] = []
var checks := 0
var _catalog: Dictionary = {}
var _preview: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"the real enemy catalog loads: " + str(_catalog.get("error", "")))
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_preview = preview if preview is Dictionary else {}
	_check(not _preview.is_empty() and _preview.get("heroes", []).size() == 4,
		"the shipped preview authors the real four-doll party")
	if not bool(_catalog.get("ok", false)) or _preview.is_empty():
		_finish()
		return
	_test_source()
	_test_malformed_and_preservation()
	_test_refusals()
	_test_absent_lost_rank()
	var witnesses := _scan_seeds()
	if int(witnesses.get("dive_hit", -1)) > 0:
		_test_dive_hit(int(witnesses["dive_hit"]))
	if int(witnesses.get("dive_miss", -1)) > 0:
		_test_dive_miss(int(witnesses["dive_miss"]))
	if int(witnesses.get("dive_rank_three", -1)) > 0:
		_test_rank_three_launch(int(witnesses["dive_rank_three"]))
	if int(witnesses.get("sonar", -1)) > 0:
		_test_sonar_mixed(int(witnesses["sonar"]))
	if int(witnesses.get("combined", -1)) > 0:
		await _test_live_driver(int(witnesses["combined"]))
	if int(witnesses.get("sonar", -1)) > 0:
		_test_replay(int(witnesses["sonar"]))
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_bobbin_bat_scream_and_fangs_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


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


func _raw_record(records: Variant, enemy_id: String) -> Dictionary:
	if not records is Array:
		return {}
	for record in records:
		if record is Dictionary and str(record.get("id", "")) == enemy_id:
			return record
	return {}


func _raw_ability(record: Dictionary, ability_id: String) -> Dictionary:
	for ability in record.get("stitched", {}).get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _loaded_ability(foe: Dictionary, ability_id: String) -> Dictionary:
	for ability in foe.get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


# ---------------------------------------------------------------- fixtures

func _config(seed_value: int, heroes: Array = [], foe_ids: Array = [BAT, RAGLING]) -> Dictionary:
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var party: Array = heroes.duplicate(true) if not heroes.is_empty() \
		else _preview["heroes"].duplicate(true)
	var foes: Array = []
	for enemy_id in foe_ids:
		foes.append(StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id)))
	return {
		"mode": "stitched",
		"seed": seed_value,
		"candle": 100,
		"heroes": party,
		"parts": parts,
		"foes": foes,
	}


func _make_battle(seed_value: int, heroes: Array = [],
		foe_ids: Array = [BAT, RAGLING]) -> StitchedRules:
	var config := _config(seed_value, heroes, foe_ids)
	for foe in config["foes"]:
		if foe is Dictionary and foe.is_empty():
			_check(false, "the real catalog resolves all fixture foes: " + str(foe_ids))
			return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)),
		"real seeded battle creates for seed %d: %s"
			% [seed_value, str(created.get("error", ""))])
	if not bool(created.get("ok", false)):
		return null
	return created["battle"]


func _hero_map(battle: StitchedRules) -> Dictionary:
	var units: Dictionary = {}
	for hero in battle.get_heroes():
		units[str(hero["id"])] = hero.duplicate(true)
	return units


func _foe_map(battle: StitchedRules) -> Dictionary:
	var units: Dictionary = {}
	for foe in battle.get_foes():
		units[str(foe["id"])] = foe.duplicate(true)
	return units


func _hero_at(battle: StitchedRules, rank: int) -> Dictionary:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return hero
	return {}


## Plays the genuine rotation to the requested actor's turn in the requested round. Hero turns
## pass; foe turns commit the real projected choice. Every event is recorded for replay checks.
func _drive(battle: StitchedRules, wanted_round: int, actor_id: String,
		history: Array) -> bool:
	for _step in range(TURN_LIMIT):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		if battle.round_number() == wanted_round and battle.current_actor_id() == actor_id:
			return true
		var round_value := battle.round_number()
		var current := battle.current_actor_id()
		var choice: Dictionary = {}
		var receipt: Dictionary = {}
		var kind := "pass"
		if battle.current_side() == "hero":
			receipt = battle.pass_turn()
		else:
			choice = StitchedFoeIntent.choose(battle, battle.get_unit(current))
			if not choice.is_empty() and not bool(choice.get("pass", true)):
				receipt = battle.use_foe_ability(
					str(choice["ability_id"]), int(choice["target_rank"]))
				kind = "ability"
			else:
				receipt = battle.pass_turn()
		if not bool(receipt.get("ok", false)):
			return false
		history.append({
			"round": round_value,
			"actor": current,
			"kind": kind,
			"intent": _norm(choice),
			"receipt": _norm(receipt),
		})
	return false


func _expected_chance(battle: StitchedRules, actor: Dictionary, before: Dictionary,
		streak: int, base_acc: int) -> int:
	var acc := base_acc + int(actor.get("acc", 0)) \
		+ int(battle.candle_band().get("enemy_acc", 0))
	return StitchedRules.hit_chance(acc, StitchedRules.effective_dodge(before), streak)


# ---------------------------------------------------------------- AC1 authored source

func _test_source() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	_check(raw is Array, "AC1: " + RUN + " parses as a JSON array")
	if not raw is Array:
		return
	var record := _raw_record(raw, BAT)
	var matches: Array = (raw as Array).filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == BAT)
	_check(matches.size() == 1 and not record.is_empty(),
		"AC1: the shipped roster authors exactly one Bobbin Bat by ID")
	if record.is_empty():
		return
	_check(str(record.get("name", "")) == "Bobbin Bat" and int(record.get("max_hp", 0)) == 27
		and bool(record.get("drain", false))
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/bobbin_bat.png",
		"AC1: Bobbin Bat keeps its legacy name, 27 HP, drain flag and bat art")
	_check(_norm(record.get("intent", {})) == _norm(BAT_INTENT),
		"AC1: the entire old weighted intent, including its separate legacy Weak 1, stays exact")
	_check(_norm(record.get("stitched", {})) == _norm(BAT_PROFILE),
		"AC1: the profile equals the authored stats/trophy and exactly the two retuned actions plus Drop")

	var dive_raw := _raw_ability(record, "bobbin_dive")
	var shriek_raw := _raw_ability(record, "sonar_shriek")
	var drop_raw := _raw_ability(record, "bobbin_drop")
	_check(_norm(dive_raw) == _norm(BOBBIN_DIVE),
		"AC1: Bobbin Dive is byte-exact apart from its effects becoming Bleed 1")
	_check(_norm(shriek_raw) == _norm(SONAR_SHRIEK),
		"AC1: Sonar Shriek is byte-exact apart from multi true and Fray 4 replacing Weak 1")
	_check(_norm(drop_raw) == _norm(BOBBIN_DROP),
		"AC1: Bobbin Drop stays byte-equivalent to its old authored record")
	_check(_norm(dive_raw.get("effects", {})) == _norm({"bleed": 1})
		and not dive_raw.get("effects", {}).has("fray"),
		"AC1: the dive's only new effect is Bleed 1, never Fray or Weak")
	_check(_norm(shriek_raw.get("effects", {})) == _norm({"fray": 4})
		and not shriek_raw.get("effects", {}).has("weak")
		and bool(shriek_raw.get("multi", false)),
		"AC1: the Stitched Sonar applies Fray 4 to all ranks and no longer applies Weak")

	var dive := StitchedParts.validate_ability(dive_raw, "test Bobbin Dive")
	var shriek := StitchedParts.validate_ability(shriek_raw, "test Sonar Shriek")
	var drop := StitchedParts.validate_ability(drop_raw, "test Bobbin Drop")
	_check(bool(dive.get("ok", false)) and bool(shriek.get("ok", false))
		and bool(drop.get("ok", false)),
		"AC1: StitchedParts validates all three Bobbin actions")
	if bool(dive.get("ok", false)):
		_check(str(dive["ability"].get("kind", "")) == "melee"
			and dive["ability"].get("launch") == [1, 3]
			and dive["ability"].get("target") == [1]
			and str(dive["ability"].get("target_side", "")) == "enemy"
			and not bool(dive["ability"].get("multi", true))
			and int(dive["ability"].get("acc", -1)) == 88
			and dive["ability"].get("dmg") == [3, 4]
			and int(dive["ability"].get("crit", -1)) == 0
			and _norm(dive["ability"].get("effects")) == _norm({"bleed": 1})
			and str(dive["ability"].get("move", "")) == "attack2",
			"AC1: normalized Bobbin Dive is the single-target front Bleed 1 attack2 dive")
	if bool(shriek.get("ok", false)):
		_check(str(shriek["ability"].get("kind", "")) == "debuff"
			and shriek["ability"].get("launch") == [1, 4]
			and shriek["ability"].get("target") == [1, 2, 3, 4]
			and bool(shriek["ability"].get("multi", false))
			and int(shriek["ability"].get("acc", -1)) == 90
			and shriek["ability"].get("dmg") == [0, 0]
			and _norm(shriek["ability"].get("effects")) == _norm({"fray": 4})
			and str(shriek["ability"].get("move", "")) == "skill",
			"AC1: normalized Sonar Shriek is the multi-target all-rank Fray 4 skill wave")
	if bool(drop.get("ok", false)):
		_check(str(drop["ability"].get("kind", "")) == "ranged"
			and drop["ability"].get("launch") == [2, 3, 4]
			and drop["ability"].get("target") == [2, 3, 4]
			and bool(drop["ability"].get("multi", false))
			and int(drop["ability"].get("acc", -1)) == 84
			and drop["ability"].get("dmg") == [2, 3]
			and _norm(drop["ability"].get("effects")) == _norm({})
			and str(drop["ability"].get("move", "")) == "attack3",
			"AC1: normalized Bobbin Drop keeps its multi-target 2-3 attack3 contract")

	# The canonical loader publishes the exact normalized kit through foe_for().
	var foe := StitchedEnemyCatalog.foe_for(_catalog, BAT)
	_check(not foe.is_empty() and str(foe.get("name", "")) == "Bobbin Bat"
		and int(foe.get("max_hp", 0)) == 27 and int(foe.get("speed", -1)) == 8
		and int(foe.get("dodge", -1)) == 11 and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 0 and not bool(foe.get("is_boss", true))
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the real loader keeps Bobbin stats and one turn per round")
	_check(StitchedEnemyCatalog.trophy_for(_catalog, BAT) == "bobbin_bat_wing",
		"AC1: the real loader still awards the bobbin wing trophy")
	if not foe.is_empty() and bool(dive.get("ok", false)) and bool(shriek.get("ok", false)) \
			and bool(drop.get("ok", false)):
		_check(foe.get("abilities") == [dive["ability"], shriek["ability"], drop["ability"]],
			"AC1: the loaded kit is exactly the validated Dive, Shriek and Drop in authored order")
		_check(_norm(_loaded_ability(foe, "bobbin_dive").get("effects")) == _norm({"bleed": 1})
			and bool(_loaded_ability(foe, "sonar_shriek").get("multi", false))
			and _norm(_loaded_ability(foe, "sonar_shriek").get("effects")) == _norm({"fray": 4})
			and _norm(_loaded_ability(foe, "bobbin_drop").get("effects")) == _norm({}),
			"AC1: the live catalog exposes the two deliberate changes and an unchanged Drop")

	# The existing paper-puppet poses already cover the two changed move families.
	var poses: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	var bat_poses: Dictionary = {}
	if poses is Dictionary:
		bat_poses = poses.get("enemies", {}).get(BAT, {})
	_check(str(bat_poses.get("attack2", {}).get("name", "")) == "Fang Bite"
		and str(bat_poses.get("attack2", {}).get("art", ""))
			== "res://assets/paper/enemies/bobbin_bat_attack2.png",
		"AC1: the dive keeps the existing attack2 Fang Bite pose")
	_check(str(bat_poses.get("skill", {}).get("name", "")) == "Screech"
		and "debuff" in bat_poses.get("skill", {}).get("covers", [])
		and str(bat_poses.get("skill", {}).get("art", ""))
			== "res://assets/paper/enemies/bobbin_bat_skill.png",
		"AC1: the sonar keeps the existing debuff skill Screech pose")

	# A named neighbour keeps its own authored record; no other foe is retuned.
	var hound := _raw_record(raw, HOUND)
	_check(not hound.is_empty() and str(hound.get("name", "")) == "Spoolback Hound"
		and _norm(_raw_ability(hound, "redline_reel")) == _norm(HOUND_REDLINE)
		and not StitchedEnemyCatalog.foe_for(_catalog, HOUND).is_empty(),
		"AC1: Spoolback Hound and its Redline Reel still resolve unchanged")
	_check(not StitchedEnemyCatalog.foe_for(_catalog, RAGLING).is_empty()
		and not StitchedEnemyCatalog.foe_for(_catalog, GUARD).is_empty(),
		"AC1: the unchanged normal escorts still resolve through the same loader")


## Invalid in-memory copies fail closed and never mutate the shipped source.
func _test_malformed_and_preservation() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	var record := _raw_record(raw, BAT)
	var before: Dictionary = record.duplicate(true)
	for probe in [
		["bobbin_dive", {"effects": {"pull": 2}}],
		["bobbin_dive", {"effects": {"bleed": 0}}],
		["bobbin_dive", {"target": [1, 5]}],
		["sonar_shriek", {"effects": {"pull": 2}}],
		["sonar_shriek", {"effects": {"fray": 0}}],
		["sonar_shriek", {"launch": [5]}],
		["bobbin_drop", {"effects": {"pull": 2}}],
		["bobbin_drop", {"target": [1, 5]}],
	]:
		var bad := _raw_ability(record, str(probe[0])).duplicate(true)
		for key in probe[1]:
			bad[key] = probe[1][key].duplicate(true)
		_check(not bool(StitchedParts.validate_ability(bad).get("ok", true)),
			"AC1: malformed %s copy %s fails closed" % [str(probe[0]), str(probe[1])])
	var after: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	_check(_raw_record(after, BAT) == before,
		"AC1: every rejected copy leaves the shipped Bobbin record byte-exact")
	_check(bool(_catalog.get("ok", false)),
		"AC1: the canonical catalog still validates after every refusal probe")


# ---------------------------------------------------------------- AC2/AC3 live traces

## Drive to the Bobbin's genuine round-one turn and commit its real projected Dive.
func _dive_trace(seed_value: int, foe_ids: Array = [BAT, RAGLING]) -> Dictionary:
	var battle := _make_battle(seed_value, [], foe_ids)
	if battle == null:
		return {}
	var history: Array = []
	if not _drive(battle, 1, BAT, history):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BAT))
	if str(intent.get("ability_id", "")) != "bobbin_dive":
		return {}
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var journal := battle.turn_events()
	var again := StitchedFoeIntent.choose(battle, battle.get_unit(BAT))
	var quiet := state == battle.state_snapshot() and rng == battle.rng_state() \
		and order == battle.turn_order() and journal == battle.turn_events() \
		and intent == again
	var actor := battle.get_unit(BAT)
	var heroes_before := _hero_map(battle)
	var foes_before := _foe_map(battle)
	var receipt := battle.use_foe_ability("bobbin_dive", int(intent.get("target_rank", 1)))
	return {
		"battle": battle,
		"history": history,
		"intent": intent,
		"receipt": receipt,
		"quiet": quiet,
		"round": battle.round_number(),
		"actor": actor,
		"heroes_before": heroes_before,
		"foes_before": foes_before,
		"heroes_after": _hero_map(battle),
		"foes_after": _foe_map(battle),
		"order": order,
		"rng": rng,
	}


## Drive to the Bobbin's genuine round-two turn and commit its real projected Sonar Shriek.
func _sonar_trace(seed_value: int, heroes: Array = []) -> Dictionary:
	var battle := _make_battle(seed_value, heroes)
	if battle == null:
		return {}
	var history: Array = []
	if not _drive(battle, 2, BAT, history):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BAT))
	if str(intent.get("ability_id", "")) != "sonar_shriek":
		return {}
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var journal := battle.turn_events()
	var again := StitchedFoeIntent.choose(battle, battle.get_unit(BAT))
	var quiet := state == battle.state_snapshot() and rng == battle.rng_state() \
		and order == battle.turn_order() and journal == battle.turn_events() \
		and intent == again
	var actor := battle.get_unit(BAT)
	var heroes_before := _hero_map(battle)
	var foes_before := _foe_map(battle)
	var receipt := battle.use_foe_ability("sonar_shriek", int(intent.get("target_rank", 1)))
	history.append({
		"round": 2,
		"actor": BAT,
		"kind": "ability",
		"intent": _norm(intent),
		"receipt": _norm(receipt),
	})
	return {
		"battle": battle,
		"history": history,
		"intent": intent,
		"receipt": receipt,
		"quiet": quiet,
		"round": battle.round_number(),
		"actor": actor,
		"heroes_before": heroes_before,
		"foes_before": foes_before,
		"heroes_after": _hero_map(battle),
		"foes_after": _foe_map(battle),
		"order": order,
		"rng": rng,
	}


func _results_hits(receipt: Dictionary) -> Array:
	var counts := [0, 0]
	for result in receipt.get("results", []):
		if bool(result.get("hit", false)):
			counts[0] += 1
		else:
			counts[1] += 1
	return counts


func _scan_seeds() -> Dictionary:
	var dive_hit := -1
	var dive_miss := -1
	var dive_rank_three := -1
	var sonar := -1
	var combined := -1
	var dive_hits := 0
	var dive_misses := 0
	var sonar_hits := 0
	var sonar_misses := 0
	for seed_value in range(1, SEED_LIMIT + 1):
		var seed_dive_hit := false
		var dive := _dive_trace(seed_value)
		if not dive.is_empty():
			var receipt: Dictionary = dive["receipt"]
			var results: Array = receipt.get("results", [])
			_check(bool(receipt.get("ok", false)) and results.size() == 1
				and int(results[0].get("target_rank", 0)) == 1,
				"AC3: seed %d resolves the single-target Dive against rank 1 only" % seed_value)
			if results.size() == 1:
				var result: Dictionary = results[0]
				var front := _hero_at(dive["battle"], 1)
				var front_after: Dictionary = dive["heroes_after"].get(
					str(front.get("id", "")), {})
				if bool(result.get("hit", false)):
					dive_hits += 1
					seed_dive_hit = not bool(result.get("crit", true))
					if dive_hit < 0 and seed_dive_hit \
							and int(front_after.get("statuses", {}).get("bleed", 0)) == 1 \
							and str(dive["battle"].current_actor_id()) != str(front.get("id", "")):
						dive_hit = seed_value
				else:
					dive_misses += 1
					if dive_miss < 0:
						dive_miss = seed_value
		if dive_rank_three < 0:
			var rank_three := _dive_trace(seed_value, [GUARD, RAGLING, BAT])
			if not rank_three.is_empty():
				dive_rank_three = seed_value
		var sonar_trace := _sonar_trace(seed_value)
		if not sonar_trace.is_empty():
			var sonar_receipt: Dictionary = sonar_trace["receipt"]
			var results: Array = sonar_receipt.get("results", [])
			var ranks: Array = []
			for result in results:
				ranks.append(int(result.get("target_rank", 0)))
			ranks.sort()
			_check(results.size() == 4 and ranks == [1, 2, 3, 4],
				"AC2: seed %d resolves one Sonar result per living rank 1-4" % seed_value)
			var counts := _results_hits(sonar_receipt)
			sonar_hits += int(counts[0])
			sonar_misses += int(counts[1])
			if int(counts[0]) > 0 and int(counts[1]) > 0 and sonar < 0:
				sonar = seed_value
			if int(counts[0]) > 0 and int(counts[1]) > 0 and combined < 0 and seed_dive_hit:
				combined = seed_value
	_check(dive_hits > 0 and dive_misses > 0,
		"AC3: the bounded seed cohort naturally witnesses both Dive hits and Dive misses")
	_check(sonar_hits > 0 and sonar_misses > 0,
		"AC2: the bounded seed cohort naturally witnesses both Sonar hits and Sonar misses")
	_check(dive_hit > 0 and dive_miss > 0 and dive_rank_three > 0,
		"AC3: witnesses exist for a landed front bleed, a Dive miss and a rank-3 launch")
	_check(sonar > 0, "AC2: one unmodified seed carries a Sonar hit and a miss in the same wave")
	_check(combined > 0,
		"AC4: one live witness seed carries a landed Dive and a mixed Sonar wave")
	return {
		"dive_hit": dive_hit,
		"dive_miss": dive_miss,
		"dive_rank_three": dive_rank_three,
		"sonar": sonar,
		"combined": combined,
		"dive_hits": dive_hits,
		"dive_misses": dive_misses,
		"sonar_hits": sonar_hits,
		"sonar_misses": sonar_misses,
	}


# ---------------------------------------------------------------- AC3 the front pin-fang

func _test_dive_hit(seed_value: int) -> void:
	var trace := _dive_trace(seed_value)
	if trace.is_empty():
		_check(false, "AC3: the witness seed reaches the Bobbin's round-one Dive")
		return
	var battle: StitchedRules = trace["battle"]
	var intent: Dictionary = trace["intent"]
	var receipt: Dictionary = trace["receipt"]
	_check(bool(trace["quiet"]),
		"AC3: repeated live Dive projection spends no state, turn, journal or RNG")
	_check(int(trace["round"]) == 1 and int(battle.get_unit(BAT).get("rank", 0)) == 1,
		"AC3: the witness is the Bobbin's genuine round-one turn from launch rank 1")
	_check(str(intent.get("foe_id", "")) == BAT
		and str(intent.get("ability_id", "")) == "bobbin_dive"
		and str(intent.get("ability_name", "")) == "Bobbin Dive"
		and str(intent.get("ability_kind", "")) == "melee"
		and str(intent.get("target_side", "")) == "hero"
		and int(intent.get("target_rank", 0)) == 1
		and intent.get("affected_ranks", []) == [1]
		and int(intent.get("base_acc", -1)) == 88
		and intent.get("base_damage") == [3, 4]
		and _norm(intent.get("base_effects")) == _norm({"bleed": 1})
		and not bool(intent.get("multi", true))
		and not bool(intent.get("pass", true)),
		"AC3: the live chooser announces the single-target ACC-88 Bleed 1 front dive")
	var results: Array = receipt.get("results", [])
	_check(bool(receipt.get("ok", false)) and str(receipt.get("actor", "")) == BAT
		and str(receipt.get("ability", "")) == "bobbin_dive" and results.size() == 1,
		"AC3: the public Dive commits one front-rank result for the Bobbin")
	if results.size() != 1:
		return
	var result: Dictionary = results[0]
	var front := _hero_at(battle, 1)
	var front_id := str(front.get("id", ""))
	var before: Dictionary = trace["heroes_before"].get(front_id, {})
	_check(str(result.get("target", "")) == front_id
		and int(result.get("target_rank", 0)) == 1
		and str(result.get("target_side", "")) == "hero",
		"AC3: the result names the real living front doll in rank 1")
	var chance := _expected_chance(battle, trace["actor"], before,
		int(trace["actor"].get("miss_streak", 0)), 88)
	_check(int(result.get("hit_chance", -1)) == chance and result.has("roll")
		and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
		"AC3: the Dive rolls the authored ACC 88 against the front doll's real DODGE")
	_check(bool(result.get("hit", false)) and not bool(result.get("crit", true)),
		"AC3: the witness seed lands an uncritical pin-fang hit")
	_check(int(result.get("damage", -1)) >= 3 and int(result.get("damage", -1)) <= 4,
		"AC3: the landed Dive deals its authored 3-4 damage")
	_check(result.get("statuses", []) == [{"status": "bleed", "duration": 1}],
		"AC3: only a confirmed Dive hit applies exactly Bleed 1")
	var after: Dictionary = trace["heroes_after"].get(front_id, {})
	_check(int(after.get("hp", -1)) == int(before.get("hp", -2)) - int(result.get("damage", 0)),
		"AC3: the front doll's actual HP drops by exactly the rolled damage")
	_check(int(after.get("statuses", {}).get("bleed", 0)) == 1,
		"AC3: the front doll's real status ledger really carries Bleed 1 after the hit")
	_check(int(after.get("fray", -1)) == int(before.get("fray", -2)),
		"AC3: the Dive itself adds no Fray")
	# Every doll behind the front line and the whole foe line stay untouched.
	for rank in [2, 3, 4]:
		var other := _hero_at(battle, rank)
		var other_id := str(other.get("id", ""))
		_check(trace["heroes_after"].get(other_id) == trace["heroes_before"].get(other_id),
			"AC3: rank %d is never a Dive victim and keeps its entire state" % rank)
	for foe_id in trace["foes_before"]:
		_check(trace["foes_after"].get(foe_id) == trace["foes_before"].get(foe_id),
			"AC3: foe %s is never harmed by the heroes' Dive" % foe_id)


func _test_dive_miss(seed_value: int) -> void:
	var trace := _dive_trace(seed_value)
	if trace.is_empty():
		_check(false, "AC3: the miss witness reaches the Bobbin's round-one Dive")
		return
	var battle: StitchedRules = trace["battle"]
	var receipt: Dictionary = trace["receipt"]
	var results: Array = receipt.get("results", [])
	if results.size() != 1:
		_check(false, "AC3: the miss witness resolves one front-rank result")
		return
	var result: Dictionary = results[0]
	var front := _hero_at(battle, 1)
	var front_id := str(front.get("id", ""))
	var before: Dictionary = trace["heroes_before"].get(front_id, {})
	var after: Dictionary = trace["heroes_after"].get(front_id, {})
	var chance := _expected_chance(battle, trace["actor"], before,
		int(trace["actor"].get("miss_streak", 0)), 88)
	_check(int(result.get("hit_chance", -1)) == chance and result.has("roll")
		and not bool(result.get("hit", true))
		and int(result.get("roll", 0)) > chance,
		"AC3: the miss witness really rolls above the authored ACC 88 chance")
	_check(int(result.get("damage", -1)) == 0 and not bool(result.get("crit", true))
		and result.get("statuses", []).is_empty()
		and int(after.get("hp", -1)) == int(before.get("hp", -2))
		and int(after.get("statuses", {}).get("bleed", 0)) == 0
		and int(after.get("fray", -1)) == int(before.get("fray", -2)),
		"AC3: a missed Dive applies no Bleed, no damage and no Fray to the front doll")


func _test_rank_three_launch(seed_value: int) -> void:
	var trace := _dive_trace(seed_value, [GUARD, RAGLING, BAT])
	if trace.is_empty():
		_check(false, "AC3: the rank-three witness reaches the Bobbin's Dive turn")
		return
	var battle: StitchedRules = trace["battle"]
	var receipt: Dictionary = trace["receipt"]
	var results: Array = receipt.get("results", [])
	_check(int(battle.get_unit(BAT).get("rank", 0)) == 3,
		"AC3: the three-foe line really places the Bobbin in rank 3")
	_check(bool(receipt.get("ok", false)) and str(receipt.get("ability", "")) == "bobbin_dive"
		and results.size() == 1 and int(results[0].get("target_rank", 0)) == 1,
		"AC3: Bobbin Dive launches from legal rank 3 and still reaches the front doll")
	if results.size() != 1:
		return
	var front := _hero_at(battle, 1)
	var front_id := str(front.get("id", ""))
	var before: Dictionary = trace["heroes_before"].get(front_id, {})
	var after: Dictionary = trace["heroes_after"].get(front_id, {})
	if bool(results[0].get("hit", false)):
		_check(results[0].get("statuses", []) == [{"status": "bleed", "duration": 1}]
			and int(after.get("statuses", {}).get("bleed", 0)) == 1,
			"AC3: a rank-3 Dive that hits still applies exactly Bleed 1 to rank 1")
	else:
		_check(not bool(results[0].get("hit", true)) and results[0].get("statuses", []).is_empty()
			and int(after.get("statuses", {}).get("bleed", 0)) == 0,
			"AC3: a rank-3 Dive that misses still applies no Bleed")
	var result: Dictionary = results[0]
	var chance := _expected_chance(battle, trace["actor"], before,
		int(trace["actor"].get("miss_streak", 0)), 88)
	_check(int(result.get("hit_chance", -1)) == chance
		and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
		"AC3: the rank-3 launch keeps the identical ACC 88 chance formula")


# ---------------------------------------------------------------- AC2 the all-rank sonar

func _test_sonar_mixed(seed_value: int) -> void:
	var trace := _sonar_trace(seed_value)
	if trace.is_empty():
		_check(false, "AC2: the witness seed reaches the Bobbin's round-two Sonar")
		return
	var battle: StitchedRules = trace["battle"]
	var intent: Dictionary = trace["intent"]
	var receipt: Dictionary = trace["receipt"]
	_check(bool(trace["quiet"]),
		"AC2: repeated live Sonar projection spends no state, turn, journal or RNG")
	_check(int(trace["round"]) == 2 and str(trace["actor"].get("id", "")) == BAT
		and int(trace["actor"].get("rank", 0)) == 1,
		"AC2: the witness is the Bobbin's genuine round-two turn from launch rank 1")
	_check(str(intent.get("ability_id", "")) == "sonar_shriek"
		and str(intent.get("ability_name", "")) == "Sonar Shriek"
		and str(intent.get("ability_kind", "")) == "debuff"
		and str(intent.get("target_side", "")) == "hero"
		and int(intent.get("target_rank", 0)) == 1
		and intent.get("affected_ranks", []) == [1, 2, 3, 4]
		and bool(intent.get("multi", false))
		and int(intent.get("base_acc", -1)) == 90
		and intent.get("base_damage") == [0, 0]
		and _norm(intent.get("base_effects")) == _norm({"fray": 4})
		and not bool(intent.get("pass", true)),
		"AC2: the live chooser announces the multi-target ACC-90 Fray 4 wave on all four ranks")
	var history_cycle: Array = []
	for event in trace["history"]:
		if str(event.get("actor", "")) == BAT and str(event.get("kind", "")) == "ability":
			history_cycle.append(str(event.get("intent", {}).get("ability_id", "")))
	_check(history_cycle == ["bobbin_dive", "sonar_shriek"],
		"AC2: the genuine live rotation really played the retuned Dive then Sonar in order")
	var results: Array = receipt.get("results", [])
	_check(bool(receipt.get("ok", false)) and str(receipt.get("actor", "")) == BAT
		and str(receipt.get("ability", "")) == "sonar_shriek",
		"AC2: the public Sonar commits as the Bobbin's authored wave")
	_check(results.size() == 4, "AC2: one independent result exists for each living doll")
	var ranks: Array = []
	for result in results:
		ranks.append(int(result.get("target_rank", 0)))
	ranks.sort()
	_check(ranks == [1, 2, 3, 4], "AC2: the wave reaches exactly ranks 1, 2, 3 and 4")
	var streak := int(trace["actor"].get("miss_streak", 0))
	var hits := 0
	var misses := 0
	var seen: Dictionary = {}
	for result in results:
		var target_id := str(result.get("target", ""))
		var before: Dictionary = trace["heroes_before"].get(target_id, {})
		var after: Dictionary = trace["heroes_after"].get(target_id, {})
		var target_rank := int(result.get("target_rank", 0))
		_check(not before.is_empty() and int(before.get("rank", 0)) == target_rank
			and str(result.get("target_side", "")) == "hero" and not seen.has(target_id),
			"AC2: the wave names a real, distinct living doll in rank %d" % target_rank)
		seen[target_id] = true
		if before.is_empty():
			continue
		var chance := StitchedRules.hit_chance(
			90 + int(trace["actor"].get("acc", 0))
				+ int(battle.candle_band().get("enemy_acc", 0)),
			StitchedRules.effective_dodge(before), streak)
		_check(int(result.get("hit_chance", -1)) == chance and result.has("roll")
			and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
			"AC2: doll %s rolls its own independent seeded ACC 90 chance" % target_id)
		streak = 0 if bool(result.get("hit", false)) else streak + 1
		_check(int(result.get("damage", -1)) == 0 and not bool(result.get("crit", true))
			and int(result.get("target_hp", -1)) == int(before.get("hp", -2)),
			"AC2: the zero-damage wave leaves doll %s's HP untouched" % target_id)
		_check(result.get("statuses", []).is_empty(),
			"AC2: the wave attaches no status to doll %s (Fray is a ledger, not Weak)" % target_id)
		_check(after.get("statuses", {}) == before.get("statuses", {}),
			"AC2: no Weak or other status appears on doll %s from the Sonar" % target_id)
		if bool(result.get("hit", false)):
			hits += 1
			var fray_event: Dictionary = result.get("fray_event", {})
			_check(bool(fray_event.get("ok", false))
				and int(fray_event.get("change", 0)) == 4
				and int(fray_event.get("before", -1)) == int(before.get("fray", -2))
				and int(after.get("fray", -1)) == int(before.get("fray", -2)) + 4,
				"AC2: a confirmed Sonar hit adds exactly Fray 4 to doll %s" % target_id)
		else:
			misses += 1
			_check(not result.has("fray_event")
				and int(after.get("fray", -1)) == int(before.get("fray", -2)),
				"AC2: a missed Sonar recipient gains no Fray and no phantom event")
	_check(hits > 0 and misses > 0,
		"AC2: the witness wave really contains both confirmed hits and misses")
	for foe_id in trace["foes_before"]:
		_check(trace["foes_after"].get(foe_id) == trace["foes_before"].get(foe_id),
			"AC2: the hero-side wave leaves foe %s completely untouched" % foe_id)


# ---------------------------------------------------------------- refusal and absent coverage

func _check_refusal(battle: StitchedRules, ability_id: String, rank: int,
		fragment: String, message: String) -> void:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var journal := battle.turn_events()
	var actor := battle.current_actor_id()
	var round_value := battle.round_number()
	var receipt := battle.use_foe_ability(ability_id, rank)
	_check(not bool(receipt.get("ok", true))
		and str(receipt.get("error", "")).contains(fragment)
		and before == battle.state_snapshot() and rng == battle.rng_state()
		and order == battle.turn_order() and journal == battle.turn_events()
		and actor == battle.current_actor_id() and round_value == battle.round_number(),
		message + " (got %s)" % str(receipt.get("error", "")))


func _test_refusals() -> void:
	# From legal rank 1, wrong target ranks and unauthored actions are refused atomically.
	var legal := _make_battle(3)
	if legal == null:
		return
	var history: Array = []
	if not _drive(legal, 1, BAT, history):
		_check(false, "AC3/AC4: the refusal fixture reaches the Bobbin's legal rank-1 turn")
		return
	_check_refusal(legal, "bobbin_dive", 2, "no legal target in rank 2",
		"AC3: the Dive refuses hero rank 2 with no state, journal or RNG change")
	_check_refusal(legal, "bobbin_dive", 0, "no legal target in rank 0",
		"AC3: the Dive refuses rank 0 with no state, journal or RNG change")
	_check_refusal(legal, "bobbin_dive", 5, "no legal target in rank 5",
		"AC3: the Dive refuses rank 5 with no state, journal or RNG change")
	_check_refusal(legal, "sonar_shriek", 0, "no legal target in rank 0",
		"AC2: the Sonar refuses rank 0 with no state, journal or RNG change")
	_check_refusal(legal, "sonar_shriek", 5, "no legal target in rank 5",
		"AC2: the Sonar refuses rank 5 with no state, journal or RNG change")
	_check_refusal(legal, "bobbin_peck", 1, "the foe has no ability bobbin_peck",
		"AC2/AC3: an unauthored move is refused with no state, journal or RNG change")
	var still_legal := legal.use_foe_ability("sonar_shriek", 1)
	_check(bool(still_legal.get("ok", false)) and still_legal.get("results", []).size() == 4,
		"AC2: the refused probes leave the real all-rank Sonar available")

	# A rank-2 Bobbin can launch neither changed action: both authored launch masks fail.
	var wrong_rank := _make_battle(5, [], [RAGLING, BAT])
	if wrong_rank == null:
		return
	var wrong_history: Array = []
	if not _drive(wrong_rank, 1, BAT, wrong_history):
		_check(false, "AC4: the wrong-launch fixture reaches the rank-2 Bobbin's turn")
		return
	_check(int(wrong_rank.get_unit(BAT).get("rank", 0)) == 2,
		"AC4: the two-foe line really places the Bobbin in rank 2")
	_check_refusal(wrong_rank, "bobbin_dive", 1, "ability cannot launch from rank 2",
		"AC3: Bobbin Dive refuses an illegal launch rank with no state, journal or RNG change")
	_check_refusal(wrong_rank, "sonar_shriek", 1, "ability cannot launch from rank 2",
		"AC2: Sonar Shriek refuses an illegal launch rank with no state, journal or RNG change")

	# A foe move on a hero turn is refused without spending the hero's turn.
	var hero_turn := _make_battle(7)
	if hero_turn == null:
		return
	for _step in range(20):
		if hero_turn.is_over() or hero_turn.current_side() == "hero":
			break
		hero_turn.pass_turn()
	_check(hero_turn.current_side() == "hero",
		"AC4: a real hero turn precedes the actor probe")
	_check_refusal(hero_turn, "sonar_shriek", 1, "it is not a foe turn",
		"AC4: a Bobbin move on a hero turn spends no state, journal, turn or RNG")


func _test_absent_lost_rank() -> void:
	var party: Array = _preview["heroes"].duplicate(true)
	party[3].merge({"hp": 0, "lost": true, "parts": {}}, true)
	var lost_id := str(party[3]["id"])
	var battle := _make_battle(5, party)
	if battle == null:
		return
	var history: Array = []
	if not _drive(battle, 2, BAT, history):
		_check(false, "AC2: the absent-doll battle reaches the Bobbin's round-two Sonar")
		return
	_check(bool(battle.get_unit(lost_id).get("lost", false))
		and int(battle.get_unit(lost_id).get("hp", -1)) == 0,
		"AC2: the rank-4 doll really is LOST before the Sonar")
	var ghost := battle.get_unit(lost_id)
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BAT))
	_check(state == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: the projection over the absent roster spends no state or RNG")
	_check(str(intent.get("ability_id", "")) == "sonar_shriek"
		and bool(intent.get("multi", false))
		and intent.get("affected_ranks", []) == [1, 2, 3]
		and int(intent.get("target_rank", 0)) == 1,
		"AC2: the forecast names only living ranks 1-3, never the ghost rank 4")
	_check_refusal(battle, "sonar_shriek", 0, "no legal target in rank 0",
		"AC2: rank 0 is refused atomically over the absent roster")
	_check_refusal(battle, "sonar_shriek", 5, "no legal target in rank 5",
		"AC2: rank 5 is refused atomically over the absent roster")
	var heroes_before := _hero_map(battle)
	var receipt := battle.use_foe_ability("sonar_shriek", int(intent.get("target_rank", 1)))
	var results: Array = receipt.get("results", [])
	_check(bool(receipt.get("ok", false)) and results.size() == 3,
		"AC2: the legal Sonar returns three results, never a ghost fourth")
	var ranks: Array = []
	for result in results:
		ranks.append(int(result.get("target_rank", 0)))
		_check(str(result.get("target", "")) != lost_id,
			"AC2: the LOST doll never receives a Sonar receipt or Fray")
	ranks.sort()
	_check(ranks == [1, 2, 3], "AC2: the other living ranks 1, 2 and 3 are still reached")
	_check(battle.get_unit(lost_id) == ghost,
		"AC2: the LOST doll's HP, partless state and statuses stay completely untouched")
	for result in results:
		var target_id := str(result.get("target", ""))
		var before: Dictionary = heroes_before.get(target_id, {})
		var after := battle.get_unit(target_id)
		if bool(result.get("hit", false)):
			_check(int(after.get("fray", -1)) == int(before.get("fray", -2)) + 4,
				"AC2: the absent wave still frays confirmed living hits by exactly four")
		else:
			_check(int(after.get("fray", -1)) == int(before.get("fray", -2)),
				"AC2: an absent wave miss still leaves its recipient's Fray unchanged")


# ---------------------------------------------------------------- AC4 replay

func _scripted_sonar(seed_value: int) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	var history: Array = []
	if not _drive(battle, 2, BAT, history):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BAT))
	var receipt := battle.use_foe_ability("sonar_shriek", int(intent.get("target_rank", 1)))
	history.append({
		"round": battle.round_number(),
		"actor": BAT,
		"kind": "ability",
		"intent": _norm(intent),
		"receipt": _norm(receipt),
	})
	return {
		"events": _norm(history),
		"receipts": _norm(history.map(func(event: Dictionary) -> Variant:
			return event.get("receipt", {}))),
		"units": _norm(battle.state_snapshot()["units"]),
		"order": _norm(battle.turn_order()),
		"snapshot": _norm(battle.state_snapshot()),
		"rng": battle.rng_state(),
	}


func _scripted_dive(seed_value: int) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	var history: Array = []
	if not _drive(battle, 1, BAT, history):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BAT))
	var receipt := battle.use_foe_ability("bobbin_dive", int(intent.get("target_rank", 1)))
	history.append({
		"round": battle.round_number(),
		"actor": BAT,
		"kind": "ability",
		"intent": _norm(intent),
		"receipt": _norm(receipt),
	})
	return {
		"events": _norm(history),
		"receipts": _norm(history.map(func(event: Dictionary) -> Variant:
			return event.get("receipt", {}))),
		"units": _norm(battle.state_snapshot()["units"]),
		"order": _norm(battle.turn_order()),
		"snapshot": _norm(battle.state_snapshot()),
		"rng": battle.rng_state(),
	}


func _test_replay(seed_value: int) -> void:
	var first := _scripted_sonar(seed_value)
	var second := _scripted_sonar(seed_value)
	_check(not first.is_empty() and first == second,
		"AC4: the same seed replays identical Dive/Sonar receipts, units, order, state and RNG")
	var events: Array = first.get("events", [])
	var last: Dictionary = events.back() if not events.is_empty() else {}
	_check(str(last.get("intent", {}).get("ability_id", "")) == "sonar_shriek"
		and str(last.get("receipt", {}).get("ability", "")) == "sonar_shriek",
		"AC4: the replayed script really finishes with the round-two Sonar")
	var dive_first := _scripted_dive(seed_value)
	var dive_second := _scripted_dive(seed_value)
	_check(not dive_first.is_empty() and dive_first == dive_second,
		"AC4: the same seed replays an identical standalone Dive trace and RNG position")


# ---------------------------------------------------------------- AC4 live screen driver

func _test_live_driver(seed_value: int) -> void:
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(_config(seed_value)),
		"AC4: the real battle screen admits the seeded Bobbin fight")
	if stage.battle == null:
		stage.free()
		return
	root.add_child(stage)
	await process_frame
	var dive: Dictionary = {}
	var sonar: Dictionary = {}
	for _step in range(LIVE_PASSES):
		var battle := stage.battle
		if battle == null or battle.is_over() or battle.current_side() != "hero":
			break
		stage.submit_pass()
	for receipt in stage.receipts:
		if str(receipt.get("actor", "")) != BAT:
			continue
		if str(receipt.get("ability", "")) == "bobbin_dive" and dive.is_empty():
			dive = receipt
		elif str(receipt.get("ability", "")) == "sonar_shriek" and sonar.is_empty():
			sonar = receipt
	_check(not dive.is_empty(),
		"AC3: the shipped live foe driver executes the retuned Bobbin Dive in real play")
	_check(not sonar.is_empty(),
		"AC2: the shipped live foe driver executes the retuned Sonar Shriek in real play")
	if not dive.is_empty():
		var results: Array = dive.get("results", [])
		_check(results.size() == 1 and int(results[0].get("target_rank", 0)) == 1,
			"AC3: the live Dive still reaches only the front doll")
		if results.size() == 1 and bool(results[0].get("hit", false)):
			_check(results[0].get("statuses", []) == [{"status": "bleed", "duration": 1}],
				"AC3: a live landing Dive applies exactly Bleed 1 to the front doll")
	if not sonar.is_empty():
		var results: Array = sonar.get("results", [])
		var ranks: Array = []
		var hits := 0
		var misses := 0
		for result in results:
			ranks.append(int(result.get("target_rank", 0)))
			_check(int(result.get("damage", -1)) == 0,
				"AC2: the live Sonar deals no direct damage")
			_check(result.has("roll"),
				"AC2: every live Sonar recipient receives its own seeded roll")
			_check(bool(result.get("hit", false))
				or (result.get("statuses", []).is_empty() and not result.has("fray_event")),
				"AC2: a live Sonar miss applies neither Fray nor a status")
			_check(not bool(result.get("hit", false))
				or int(result.get("fray_event", {}).get("change", 0)) == 4,
				"AC2: a live Sonar hit applies exactly Fray 4")
			if bool(result.get("hit", false)):
				hits += 1
			else:
				misses += 1
		ranks.sort()
		_check(results.size() == 4 and ranks == [1, 2, 3, 4],
			"AC2: the live driver reaches exactly all four living doll ranks")
		_check(hits > 0 and misses > 0,
			"AC2: the live witness wave contains both landed and missed recipients")
	stage.free()
	await process_frame
