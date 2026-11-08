extends SceneTree
## S5 Moth Swarm contract: the canonical five-moth kit gains one third-turn Tattercloud Knot,
## and its Wing Dust now hunts the most-frayed legal doll instead of the nearest rank.
##
## Checks are by required enemy/ability ID against the real run_enemies.json and the pure
## StitchedEnemyCatalog/StitchedRules/StitchedFoeIntent stack. No catalog totals or global
## ordering are asserted, so parallel catalog lanes can add enemies safely.
##
## Deterministic: one seeded RandomNumberGenerator per battle, public pass/ability turns only,
## and a bounded seed search for a mixed hit/miss Tattercloud witness. No UI is mounted.

const SWARM := "moth_swarm"
const BULWARK := "felt_bulwark"
const WING_DUST := "wing_dust"
const SWARM_BLUR := "swarm_blur"
const TATTERCLOUD := "tattercloud_knot"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const MOVE_POSES_PATH := "res://data/art/move_poses.json"
const FRAY_PER_HIT := 3

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
		"the real s2_preview four-hero/part fixture plus two canonical foes builds a 4v2 setup")
	_test_source_contract()
	_test_catalog_contract()
	_test_fear_hunt_choice()
	_test_tattercloud_round_three()
	_test_refusals()
	_test_seeded_replay()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_moth_swarm_fear_hunt_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- fixtures and small helpers

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _make_base_config() -> Dictionary:
	var config: Dictionary = StitchedBattleScreen.read_preview()
	if config.is_empty():
		return {}
	config["seed"] = 1
	config["candle"] = 100
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(_catalog, SWARM),
		StitchedEnemyCatalog.foe_for(_catalog, BULWARK),
	]
	if config["foes"][0].is_empty() or config["foes"][1].is_empty():
		return {}
	return config


func _new_battle(seed_value: int) -> StitchedRules:
	var config: Dictionary = _base_config.duplicate(true)
	config["seed"] = seed_value
	var built := StitchedRules.create(config)
	if not bool(built.get("ok", false)):
		return null
	return built["battle"]


func _hero_id_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


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


## Passes every turn until the Moth Swarm owns a genuine turn in wanted_round. Read-only
## choices drive the other foes, so no wall-clock or unseeded draw can enter the fixture.
func _to_swarm(battle: StitchedRules, wanted_round: int) -> bool:
	for _step in range(80):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		if battle.round_number() == wanted_round and battle.current_actor_id() == SWARM:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


## Plays the genuine round rotation up to the Moth Swarm's wanted_round turn. Foe turns use
## the real chooser and commit through StitchedRules; hero turns pass. Every event is recorded
## so a replay can compare the whole legal sequence, not only its final receipt.
func _drive_to_swarm(battle: StitchedRules, wanted_round: int, events: Array) -> bool:
	for _step in range(240):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		if battle.round_number() == wanted_round and battle.current_actor_id() == SWARM:
			return true
		var round_value := battle.round_number()
		var actor_id := battle.current_actor_id()
		if battle.current_side() == "hero":
			var passed := battle.pass_turn()
			if not bool(passed.get("ok", false)):
				return false
			events.append({
				"round": round_value,
				"actor": actor_id,
				"kind": "pass",
				"receipt": _norm(passed),
			})
			continue
		var actor := battle.get_unit(actor_id)
		var choice := StitchedFoeIntent.choose(battle, actor)
		var receipt: Dictionary = {}
		var kind := "pass"
		if not choice.is_empty() and not bool(choice.get("pass", true)):
			receipt = battle.use_foe_ability(
				str(choice["ability_id"]), int(choice["target_rank"]))
			kind = "ability"
		if not bool(receipt.get("ok", false)):
			receipt = battle.pass_turn()
			kind = "pass"
		if not bool(receipt.get("ok", false)):
			return false
		events.append({
			"round": round_value,
			"actor": actor_id,
			"kind": kind,
			"intent": _norm(choice),
			"receipt": _norm(receipt),
		})
	return false


func _find_ability(foe: Dictionary, ability_id: String) -> Dictionary:
	for ability in foe.get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


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


# ---------------------------------------------------------------- AC1 authored source

func _test_source_contract() -> void:
	var raw: Variant = _read_json(RUN_ENEMIES_PATH)
	_check(raw is Array and not (raw as Array).is_empty(),
		"AC1: the real run enemy catalog parses")
	if not raw is Array:
		return
	var record := _raw_record(raw, SWARM)
	_check(not record.is_empty(), "AC1: the run catalog still authors moth_swarm by ID")
	if record.is_empty():
		return

	# The untouched legacy card record and identity stay exactly as authored.
	_check(str(record.get("name", "")) == "Moth Swarm"
		and int(record.get("max_hp", 0)) == 21
		and record.get("chew_block_on_attack") == true
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/moth_swarm.png",
		"AC1: Moth Swarm keeps its name, legacy 21 HP, chew trait and moth art")
	var expected_intent := {
		"target": "front",
		"actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "attack", "amount": 7, "weight": 3},
			{"type": "debuff", "status": "weak", "amount": 1, "weight": 1},
			{"type": "summon", "amount": 0, "weight": 1},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1},
		],
	}
	_check(_norm(record.get("intent", {})) == _norm(expected_intent),
		"AC1: all five legacy Moth Swarm intent actions are byte-for-byte unchanged")

	var stitched: Dictionary = record.get("stitched", {})
	_check(int(stitched.get("max_hp", 0)) == 21
		and int(stitched.get("speed", -1)) == 6
		and int(stitched.get("dodge", -1)) == 12
		and int(stitched.get("acc", -1)) == 0
		and int(stitched.get("prot", -1)) == 0
		and stitched.get("is_boss") == false
		and int(stitched.get("turns_per_round", 0)) == 1
		and str(stitched.get("trophy", "")) == "moth_swarm_wings",
		"AC1: the Stitched profile keeps 21 HP, SPEED 6, DODGE 12, ACC 0, PROT 0, one turn and trophy")

	var abilities: Array = stitched.get("abilities", [])
	_check(abilities.size() == 3,
		"AC1: Moth Swarm authors exactly its two original moves plus one appended action")
	var ordered_ids: Array = []
	for ability in abilities:
		ordered_ids.append(str(ability.get("id", "")))
	_check(ordered_ids == [WING_DUST, SWARM_BLUR, TATTERCLOUD],
		"AC1: the appended move follows Wing Dust and Swarm Blur in the round rotation")

	var expected_dust := {
		"id": WING_DUST,
		"name": "Wing Dust",
		"kind": "ranged",
		"launch": [1, 4],
		"target": [1, 3],
		"target_side": "enemy",
		"multi": false,
		"acc": 86,
		"dmg": [2, 3],
		"crit": 0,
		"effects": {"fray": 4},
		"self_move": 0,
		"move": "attack2",
	}
	var expected_blur := {
		"id": SWARM_BLUR,
		"name": "Swarm Blur",
		"kind": "buff",
		"launch": [1, 3],
		"target": [1, 3],
		"target_side": "self",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"dodge": 6, "duration": 1},
		"self_move": 0,
		"move": "skill",
	}
	var expected_knot := {
		"id": TATTERCLOUD,
		"name": "Tattercloud Knot",
		"kind": "debuff",
		"launch": [1, 2, 3, 4],
		"target": [1, 2, 3],
		"target_side": "enemy",
		"multi": true,
		"acc": 88,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"tangled": 1, "fray": 3},
		"self_move": 0,
		"move": "skill",
	}
	_check(_norm(_raw_ability(record, WING_DUST)) == _norm(expected_dust),
		"AC1: Wing Dust keeps its exact authored numbers, ranks and attack2 pose")
	_check(_norm(_raw_ability(record, SWARM_BLUR)) == _norm(expected_blur),
		"AC1: Swarm Blur keeps its exact authored numbers and skill pose")
	var raw_knot := _raw_ability(record, TATTERCLOUD)
	_check(_norm(raw_knot) == _norm(expected_knot),
		"AC1: Tattercloud Knot authors the exact group debuff, rank 1-3 spread and skill pose")

	var valid := StitchedParts.validate_ability(raw_knot, "test Moth Swarm tattercloud_knot")
	_check(bool(valid.get("ok", false)),
		"AC1: StitchedParts validates the appended Tattercloud Knot")
	if bool(valid.get("ok", false)):
		var checked: Dictionary = valid["ability"]
		_check(checked.get("launch") == [1, 2, 3, 4]
			and checked.get("target") == [1, 2, 3]
			and int(checked.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4])
			and int(checked.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3])
			and checked.get("effects") == {"tangled": 1, "fray": 3}
			and bool(checked.get("multi", false))
			and str(checked.get("move", "")) == "skill",
			"AC1: the validated move tangles/frays living ranks 1-3 only, never rank 4")

	# Named neighbours still keep their own earlier authored records.
	var scribe := _raw_record(raw, "moth_scribe")
	var bulwark := _raw_record(raw, BULWARK)
	_check(not scribe.is_empty()
		and str(scribe.get("name", "")) == "Moth Scribe"
		and int(scribe.get("max_hp", 0)) == 14
		and str(_raw_ability(scribe, "ink_flick").get("id", "")) == "ink_flick",
		"AC1: the earlier named Moth Scribe record and Ink Flick remain authored")
	_check(not bulwark.is_empty()
		and str(bulwark.get("name", "")) == "Felt Bulwark"
		and int(bulwark.get("max_hp", 0)) == 18
		and str(_raw_ability(bulwark, "felt_slam").get("id", "")) == "felt_slam",
		"AC1: the earlier named Felt Bulwark record and Felt Slam remain authored")

	# The existing skill pose is still the one this enemy's third action uses.
	var poses: Variant = _read_json(MOVE_POSES_PATH)
	var swarm_skill: Dictionary = {}
	if poses is Dictionary:
		var enemy_poses: Dictionary = (poses as Dictionary).get("enemies", {})
		var swarm_poses: Dictionary = enemy_poses.get(SWARM, {})
		swarm_skill = swarm_poses.get("skill", {})
	var covers: Array = swarm_skill.get("covers", [])
	_check(str(swarm_skill.get("name", "")) == "Dust Cloud"
		and str(swarm_skill.get("art", "")) == "res://assets/paper/enemies/moth_swarm_skill.png"
		and "debuff" in covers,
		"AC1: the existing Dust Cloud skill pose already covers the new debuff, with no art edit")


# ---------------------------------------------------------------- AC1 normalized catalog

func _test_catalog_contract() -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, SWARM)
	_check(not foe.is_empty(), "AC1: foe_for resolves the canonical moth_swarm kit")
	if foe.is_empty():
		return
	_check(str(foe.get("id", "")) == SWARM and str(foe.get("name", "")) == "Moth Swarm"
		and int(foe.get("max_hp", 0)) == 21
		and int(foe.get("speed", -1)) == 6
		and int(foe.get("dodge", -1)) == 12
		and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 0
		and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the normalized foe keeps its 21 HP, SPEED 6, DODGE 12, ACC 0, PROT 0 and one turn")
	_check(str(StitchedEnemyCatalog.trophy_for(_catalog, SWARM)) == "moth_swarm_wings",
		"AC1: the normalized foe still drops the moth wings trophy")

	var dust := _find_ability(foe, WING_DUST)
	var blur := _find_ability(foe, SWARM_BLUR)
	var knot := _find_ability(foe, TATTERCLOUD)
	var wing_mask := StitchedParts.rank_mask([1, 3])
	_check(not dust.is_empty()
		and dust.get("launch") == [1, 4] and dust.get("target") == [1, 3]
		and int(dust.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 4])
		and int(dust.get("target_mask", 0)) == wing_mask
		and int(dust.get("acc", 0)) == 86 and dust.get("dmg") == [2, 3]
		and int(dust.get("crit", -1)) == 0
		and dust.get("effects") == {"fray": 4}
		and str(dust.get("move", "")) == "attack2",
		"AC1: normalized Wing Dust reaches ranks 1 and 3 only, with ACC 86, 2-3 damage and Fray 4")
	_check(not blur.is_empty()
		and int(blur.get("target_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(blur.get("acc", 0)) == 100 and blur.get("dmg") == [0, 0]
		and blur.get("effects") == {"dodge": 6, "duration": 1}
		and str(blur.get("move", "")) == "skill",
		"AC1: normalized Swarm Blur keeps its self Dodge 6 buff and skill pose")
	_check(not knot.is_empty()
		and knot.get("launch") == [1, 2, 3, 4] and knot.get("target") == [1, 2, 3]
		and int(knot.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4])
		and int(knot.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3])
		and bool(knot.get("multi", false))
		and int(knot.get("acc", 0)) == 88 and knot.get("dmg") == [0, 0]
		and int(knot.get("crit", -1)) == 0
		and knot.get("effects") == {"tangled": 1, "fray": 3}
		and str(knot.get("move", "")) == "skill",
		"AC1: normalized Tattercloud Knot is a multi debuff on living ranks 1-3 with ACC 88")

	# An existing canonical neighbour still resolves its own kit through the same loader.
	var bulwark := StitchedEnemyCatalog.foe_for(_catalog, BULWARK)
	_check(not bulwark.is_empty() and str(bulwark.get("name", "")) == "Felt Bulwark"
		and int(bulwark.get("max_hp", 0)) == 18
		and not _find_ability(bulwark, "felt_slam").is_empty(),
		"AC1: the canonical Felt Bulwark partner still resolves unchanged")


# ---------------------------------------------------------------- AC2 fear-hunting intent

func _inspect_choice(battle: StitchedRules) -> Dictionary:
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor := battle.current_actor_id()
	var round_value := battle.round_number()
	var first := StitchedFoeIntent.choose(battle, battle.get_unit(SWARM))
	var second := StitchedFoeIntent.choose(battle, battle.get_unit(SWARM))
	return {
		"choice": first,
		"repeat_equal": first == second,
		"read_only": state == battle.state_snapshot()
			and rng == battle.rng_state()
			and actor == battle.current_actor_id()
			and round_value == battle.round_number(),
	}


func _test_fear_hunt_choice() -> void:
	var battle := _new_battle(620100)
	_check(battle != null and _to_swarm(battle, 1),
		"AC2: a seeded 4v2 fight reaches a genuine round-one Moth Swarm turn")
	if battle == null or not _to_swarm(battle, 1):
		return
	var dust := _find_ability(battle.get_unit(SWARM), WING_DUST)
	_check(not dust.is_empty(), "AC2: the living Moth Swarm really owns Wing Dust")
	if dust.is_empty():
		return
	_check(battle._legal_targets(battle.get_unit(SWARM), dust, 2).is_empty()
		and battle._legal_targets(battle.get_unit(SWARM), dust, 4).is_empty(),
		"AC2: Wing Dust's authored mask really makes rank 2 and rank 4 ineligible")

	var rank_one := _hero_id_at(battle, 1)
	var rank_two := _hero_id_at(battle, 2)
	var rank_three := _hero_id_at(battle, 3)
	var rank_four := _hero_id_at(battle, 4)
	_check(rank_one != "" and rank_two != "" and rank_three != "" and rank_four != "",
		"AC2: all four fixture dolls really occupy distinct ranks")
	if rank_one.is_empty() or rank_two.is_empty() or rank_three.is_empty() or rank_four.is_empty():
		return
	var pristine: Dictionary = battle._units.duplicate(true)

	# Rank 2 carries the biggest FRAY but is not a legal Wing Dust rank; rank 4 too.
	battle._units[rank_one]["fray"] = 10
	battle._units[rank_two]["fray"] = 90
	battle._units[rank_three]["fray"] = 40
	battle._units[rank_four]["fray"] = 95
	var high := _inspect_choice(battle)
	var high_choice: Dictionary = high["choice"]
	_check(bool(high["read_only"]) and bool(high["repeat_equal"]),
		"AC2: repeated highest-FRAY projection reads no state, RNG or turn")
	_check(str(high_choice.get("ability_id", "")) == WING_DUST
		and int(high_choice.get("target_rank", 0)) == 3
		and high_choice.get("affected_ranks", []) == [3]
		and str(high_choice.get("target_side", "")) == "hero"
		and bool(high_choice.get("pass", true)) == false,
		"AC2: Wing Dust chooses legal rank 3 over lower rank 1 while illegal rank 2/4 stay ignored")
	_check(int(high_choice.get("base_acc", -1)) == 86
		and high_choice.get("base_damage", []) == [2, 3]
		and high_choice.get("base_effects", {}) == {"fray": 4}
		and bool(high_choice.get("multi", true)) == false,
		"AC2: the fear-hunting intent still announces Wing Dust's authored numbers")

	# Equal FRAY ties prefer the lower legal rank (1 before 3).
	battle._units[rank_one]["fray"] = 50
	battle._units[rank_three]["fray"] = 50
	var tie := _inspect_choice(battle)
	_check(str(tie["choice"].get("ability_id", "")) == WING_DUST
		and int(tie["choice"].get("target_rank", 0)) == 1
		and bool(tie["read_only"]),
		"AC2: equal FRAY chooses the lower legal rank 1")

	# A LOST rank 3 can never be selected even with the greatest FRAY.
	battle._units[rank_three]["fray"] = 80
	battle._units[rank_three]["lost"] = true
	var lost := _inspect_choice(battle)
	_check(battle._legal_targets(battle.get_unit(SWARM), dust, 3).is_empty()
		and int(lost["choice"].get("target_rank", 0)) == 1
		and str(lost["choice"].get("ability_id", "")) == WING_DUST,
		"AC2: a LOST highest-FRAY rank 3 is excluded and rank 1 is chosen")
	_check(bool(lost["read_only"]), "AC2: the LOST-rank projection mutates nothing")

	# A missing rank 3 behaves the same: the legality authority simply has no doll there.
	battle._units = pristine.duplicate(true)
	battle._units[rank_one]["fray"] = 10
	battle._units[rank_three]["fray"] = 80
	battle._units.erase(rank_three)
	var missing := _inspect_choice(battle)
	_check(int(missing["choice"].get("target_rank", 0)) == 1
		and bool(missing["read_only"]),
		"AC2: an absent rank 3 leaves the legal rank 1 choice with no mutation")
	battle._units = pristine.duplicate(true)

	# With every rank 1-3 doll gone, Wing Dust keeps the ordinary next-ability fallback.
	battle._units[rank_one]["lost"] = true
	battle._units[rank_two]["lost"] = true
	battle._units[rank_three]["lost"] = true
	var empty := _inspect_choice(battle)
	_check(str(empty["choice"].get("ability_id", "")) == SWARM_BLUR
		and bool(empty["read_only"]),
		"AC2: vanished legal targets fall through to the next authored move, not a phantom hit")
	battle._units = pristine.duplicate(true)

	# Commit the real fear-hunting choice and verify the receipt names the same legal doll.
	battle._units[rank_one]["fray"] = 10
	battle._units[rank_two]["fray"] = 90
	battle._units[rank_three]["fray"] = 40
	var commit_choice: Dictionary = _inspect_choice(battle)["choice"]
	var cast := battle.use_foe_ability(WING_DUST, int(commit_choice.get("target_rank", 0)))
	var results: Array = cast.get("results", [])
	_check(bool(cast.get("ok", false))
		and str(cast.get("ability", "")) == WING_DUST
		and str(cast.get("target", "")) == rank_three
		and results.size() == 1
		and str(results[0].get("target", "")) == rank_three
		and int(results[0].get("target_rank", 0)) == 3,
		"AC2: the committed Wing Dust targets and receipts the same legal highest-FRAY rank 3")
	battle._units = pristine.duplicate(true)


# ---------------------------------------------------------------- AC3 natural third round

func _probe_tattercloud(seed_value: int) -> Dictionary:
	var battle := _new_battle(seed_value)
	if battle == null:
		return {}
	var history: Array = []
	if not _drive_to_swarm(battle, 3, history):
		return {}
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(SWARM))
	if str(choice.get("ability_id", "")) != TATTERCLOUD:
		return {}
	var receipt := battle.use_foe_ability(TATTERCLOUD, int(choice.get("target_rank", 1)))
	if not bool(receipt.get("ok", false)):
		return {}
	var hits := 0
	var misses := 0
	for result in receipt.get("results", []):
		if bool(result.get("hit", false)):
			hits += 1
		else:
			misses += 1
	return {
		"hits": hits,
		"misses": misses,
		"next_side": battle.current_side(),
	}


func _find_tattercloud_seed() -> int:
	for seed_value in range(630100, 630500):
		var probe := _probe_tattercloud(seed_value)
		if not probe.is_empty() and int(probe.get("hits", 0)) > 0 \
				and int(probe.get("misses", 0)) > 0 \
				and str(probe.get("next_side", "")) == "foe":
			return seed_value
	return -1


func _play_tattercloud(seed_value: int) -> Dictionary:
	var battle := _new_battle(seed_value)
	if battle == null:
		return {}
	var history: Array = []
	if not _drive_to_swarm(battle, 3, history):
		return {}
	var state_before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var actor_before := battle.current_actor_id()
	var round_before := battle.round_number()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(SWARM))
	var repeat := StitchedFoeIntent.choose(battle, battle.get_unit(SWARM))
	var state_after_choice := battle.state_snapshot()
	var rng_after_choice := battle.rng_state()
	var actor_after_choice := battle.current_actor_id()
	var round_after_choice := battle.round_number()
	var before_units: Dictionary = {}
	for hero in battle.get_heroes():
		before_units[str(hero["id"])] = hero.duplicate(true)
	var receipt := battle.use_foe_ability(TATTERCLOUD, int(choice.get("target_rank", 1)))
	var after_units: Dictionary = {}
	for hero in battle.get_heroes():
		after_units[str(hero["id"])] = hero.duplicate(true)
	var next_side := battle.current_side()
	return {
		"battle": battle,
		"history": history,
		"choice": choice,
		"repeat_equal": choice == repeat,
		"read_only": state_before == state_after_choice
			and rng_before == rng_after_choice
			and actor_before == actor_after_choice
			and round_before == round_after_choice,
		"actor_before": actor_before,
		"round_before": round_before,
		"receipt": receipt,
		"before_units": before_units,
		"after_units": after_units,
		"next_side": next_side,
	}


func _advance_to_hero(battle: StitchedRules, hero_id: String) -> bool:
	for _step in range(80):
		if battle == null or battle.is_over():
			return false
		if battle.current_actor_id() == hero_id:
			return true
		if battle.current_side() == "hero":
			if not bool(battle.pass_turn().get("ok", false)):
				return false
			continue
		var choice := StitchedFoeIntent.choose(battle, battle.get_unit(battle.current_actor_id()))
		var receipt: Dictionary = {}
		if not choice.is_empty() and not bool(choice.get("pass", true)):
			receipt = battle.use_foe_ability(
				str(choice["ability_id"]), int(choice["target_rank"]))
		if not bool(receipt.get("ok", false)):
			receipt = battle.pass_turn()
		if not bool(receipt.get("ok", false)):
			return false
	return false


func _test_tattercloud_round_three() -> void:
	var seed_value := _find_tattercloud_seed()
	_check(seed_value > 0,
		"AC3: bounded seed witness for a mixed hit/miss round-three Tattercloud Knot")
	if seed_value <= 0:
		return
	var data := _play_tattercloud(seed_value)
	_check(not data.is_empty(), "AC3: the witnessed battle reaches its natural third Moth Swarm turn")
	if data.is_empty():
		return
	var history: Array = data["history"]
	var swarm_cycle: Array = []
	for event in history:
		if str(event.get("actor", "")) == SWARM and str(event.get("kind", "")) == "ability":
			swarm_cycle.append(str(event.get("intent", {}).get("ability_id", "")))
	_check(swarm_cycle == [WING_DUST, SWARM_BLUR],
		"AC3: the natural rotation really played Wing Dust then Swarm Blur before round three")

	var choice: Dictionary = data["choice"]
	_check(bool(data["repeat_equal"]) and bool(data["read_only"]),
		"AC3: repeated round-three intent projection spends no state, RNG or turn")
	_check(int(data["round_before"]) == 3
		and str(data["actor_before"]) == SWARM
		and str(choice.get("ability_id", "")) == TATTERCLOUD
		and str(choice.get("ability_name", "")) == "Tattercloud Knot"
		and str(choice.get("ability_kind", "")) == "debuff"
		and str(choice.get("target_side", "")) == "hero"
		and bool(choice.get("multi", false))
		and choice.get("affected_ranks", []) == [1, 2, 3]
		and int(choice.get("target_rank", 0)) == 1,
		"AC3: round three announces the multi debuff across living ranks 1-3, never rank 4")
	_check(int(choice.get("base_acc", -1)) == 88
		and choice.get("base_damage", []) == [0, 0]
		and int(choice.get("base_crit", -1)) == 0
		and choice.get("base_effects", {}) == {"tangled": 1, "fray": 3},
		"AC3: the intent discloses the exact authored ACC, zero damage, Tangled 1 and Fray 3")

	var receipt: Dictionary = data["receipt"]
	_check(bool(receipt.get("ok", false))
		and str(receipt.get("ability", "")) == TATTERCLOUD
		and str(receipt.get("actor", "")) == SWARM,
		"AC3: Tattercloud Knot commits through the existing StitchedRules foe action")
	var results: Array = receipt.get("results", [])
	var before_units: Dictionary = data["before_units"]
	var after_units: Dictionary = data["after_units"]
	var living_legal := 0
	for unit_id in before_units:
		var unit: Dictionary = before_units[unit_id]
		if int(unit.get("rank", 0)) >= 1 and int(unit.get("rank", 0)) <= 3 \
				and not bool(unit.get("lost", false)):
			living_legal += 1
	_check(results.size() == living_legal and living_legal == 3,
		"AC3: one target receipt is emitted per living legal hero in ranks 1-3")
	var hits := 0
	var misses := 0
	var first_hit_id := ""
	for result in results:
		var target_id := str(result.get("target", ""))
		var target_rank := int(result.get("target_rank", 0))
		_check(target_rank >= 1 and target_rank <= 3 and target_id != "",
			"AC3: every receipt names a real living hero in ranks 1-3")
		var before: Dictionary = before_units.get(target_id, {})
		var after: Dictionary = after_units.get(target_id, {})
		if bool(result.get("hit", false)):
			hits += 1
			if first_hit_id.is_empty():
				first_hit_id = target_id
			var statuses: Array = result.get("statuses", [])
			var fray_event: Dictionary = result.get("fray_event", {})
			_check(statuses == [{"status": "tangled", "duration": 1}]
				and bool(fray_event.get("ok", false))
				and int(fray_event.get("change", 0)) == FRAY_PER_HIT,
				"AC3: a confirmed hit applies exactly Tangled 1 and Fray 3")
			_check(int(after.get("fray", 0)) == int(before.get("fray", 0)) + FRAY_PER_HIT,
				"AC3: a confirmed hit raises the affected doll's actual FRAY by exactly three")
			_check(int(after.get("statuses", {}).get("tangled", 0)) == 1,
				"AC3: Tangled 1 is present before that doll's ordinary start-of-turn tick")
		else:
			misses += 1
			_check(result.get("statuses", []).is_empty()
				and not result.has("fray_event")
				and int(after.get("fray", 0)) == int(before.get("fray", 0))
				and int(after.get("statuses", {}).get("tangled", 0)) == 0,
				"AC3: a missed Tattercloud hit applies neither Tangled nor Fray")
	_check(hits > 0 and misses > 0,
		"AC3: the seeded witness really contains both landed and missed recipients")
	_check(str(data["next_side"]) == "foe",
		"AC3: the witness leaves the next turn to a foe, so no hero start-of-turn tick hid the status")

	var rank_four := _hero_id_at(data["battle"], 4)
	var four_before: Dictionary = before_units.get(rank_four, {})
	var four_after: Dictionary = after_units.get(rank_four, {})
	var rank_four_hit := false
	for result in results:
		if int(result.get("target_rank", 0)) == 4:
			rank_four_hit = true
	_check(rank_four != "" and not rank_four_hit
		and int(four_after.get("fray", 0)) == int(four_before.get("fray", 0))
		and int(four_after.get("statuses", {}).get("tangled", 0)) == 0,
		"AC3: rank 4 never appears in the results and keeps its FRAY and statuses untouched")

	# Tangled is a one-turn clock: the affected doll's next real turn consumes it.
	if not first_hit_id.is_empty():
		var battle: StitchedRules = data["battle"]
		_check(_advance_to_hero(battle, first_hit_id),
			"AC3: the seeded witness can reach the first-hit doll's next real turn")
		_check(int(battle.get_unit(first_hit_id).get("statuses", {}).get("tangled", 0)) == 0,
			"AC3: Tangled 1 lasts exactly one affected hero turn under existing timing")
		var cycle_history: Array = []
		_check(_drive_to_swarm(battle, 4, cycle_history),
			"AC3: the seeded witness reaches the Moth Swarm's natural fourth round")
		var repeat_choice := StitchedFoeIntent.choose(battle, battle.get_unit(SWARM))
		_check(str(repeat_choice.get("ability_id", "")) == WING_DUST,
			"AC3: the round-four rotation repeats back to Wing Dust")


# ---------------------------------------------------------------- AC4 replay and refusals

func _scripted_trace(seed_value: int) -> Dictionary:
	var battle := _new_battle(seed_value)
	if battle == null:
		return {}
	var events: Array = []
	if not _drive_to_swarm(battle, 3, events):
		return {}
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(SWARM))
	var receipt := battle.use_foe_ability(TATTERCLOUD, int(choice.get("target_rank", 1)))
	events.append({
		"round": battle.round_number(),
		"actor": SWARM,
		"kind": "ability",
		"intent": _norm(choice),
		"receipt": _norm(receipt),
	})
	return {
		"events": _norm(events),
		"snapshot": _norm(battle.state_snapshot()),
		"rng": battle.rng_state(),
	}


func _test_seeded_replay() -> void:
	var seed_value := _find_tattercloud_seed()
	_check(seed_value > 0, "AC4: bounded replay seed witness exists")
	if seed_value <= 0:
		return
	var first := _scripted_trace(seed_value)
	var second := _scripted_trace(seed_value)
	_check(not first.is_empty() and not second.is_empty()
		and first["events"] == second["events"]
		and first["snapshot"] == second["snapshot"]
		and int(first["rng"]) == int(second["rng"]),
		"AC4: the same authored roster and seed replay identical intents, receipts, state and RNG")
	var events: Array = first.get("events", [])
	var last: Dictionary = events.back() if not events.is_empty() else {}
	_check(str(last.get("intent", {}).get("ability_id", "")) == TATTERCLOUD
		and str(last.get("receipt", {}).get("ability", "")) == TATTERCLOUD,
		"AC4: the replayed script really finishes with the round-three Tattercloud Knot")


func _test_refusals() -> void:
	var battle := _new_battle(620500)
	_check(battle != null and _to_swarm(battle, 1),
		"AC4: a genuine Moth Swarm turn precedes the rejection checks")
	if battle == null or not _to_swarm(battle, 1):
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor := battle.current_actor_id()
	var round_value := battle.round_number()
	for probe in [
		["not_an_ability", 1],
		[WING_DUST, 2],
		[WING_DUST, 4],
		[TATTERCLOUD, 4],
		[TATTERCLOUD, 0],
	]:
		var refused := battle.use_foe_ability(str(probe[0]), int(probe[1]))
		_check(not bool(refused.get("ok", true))
			and state == battle.state_snapshot()
			and rng == battle.rng_state()
			and actor == battle.current_actor_id()
			and round_value == battle.round_number(),
			"AC4: unknown ability or invalid target rank spends no state, RNG or turn: "
			+ str(probe[0]) + " rank " + str(probe[1]))

	var hero_battle := _new_battle(620501)
	var reached_hero := false
	for _step in range(40):
		if hero_battle == null or hero_battle.is_over():
			break
		if hero_battle.current_side() == "hero":
			reached_hero = true
			break
		hero_battle.pass_turn()
	_check(reached_hero, "AC4: a real hero turn exists for the wrong-actor refusal")
	if not reached_hero:
		return
	var hero_state := hero_battle.state_snapshot()
	var hero_rng := hero_battle.rng_state()
	var hero_actor := hero_battle.current_actor_id()
	var wrong_turn := hero_battle.use_foe_ability(WING_DUST, 1)
	_check(not bool(wrong_turn.get("ok", true))
		and hero_state == hero_battle.state_snapshot()
		and hero_rng == hero_battle.rng_state()
		and hero_actor == hero_battle.current_actor_id(),
		"AC4: a foe ability on the wrong current actor spends no state, RNG or turn")
