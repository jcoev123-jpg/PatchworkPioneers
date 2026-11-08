extends SceneTree
## S5 Moth Scribe ink-and-quill contract: the canonical run catalog authors one Marking debuff,
## and the following ranged Ink Flick adds exactly +3 direct base damage to a Marked doll.
##
## Checks are by required enemy ID against the real run_enemies.json and the pure
## StitchedEnemyCatalog/StitchedRules/StitchedFoeIntent stack. No catalog totals or ordered
## ID lists are asserted, so parallel catalog lanes can add enemies safely.
##
## Deterministic: one seeded RandomNumberGenerator per battle, public pass/ability turns only
## for positive witnesses, bounded seed searches for hit/miss witnesses, and paired battles
## with the same seed to prove Mark is the only difference in an otherwise identical hit.

const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const ENCOUNTER_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const SCRIBE := "moth_scribe"
const BULWARK := "felt_bulwark"
const TARGET_RANK := 2
const FRAY_ON_INK_HIT := 6
const MARK_BONUS := 3

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
	_check(not _base_config.is_empty(), "preview heroes and both canonical foes build a 4v2 setup")
	_test_source_contract()
	_test_mark_bonus_order()
	_test_catalog_contract()
	_test_encounter_pairing()
	_test_dust_scrawl_public_turn()
	_test_dust_scrawl_miss()
	_test_target_refusals()
	_test_marked_ink_flick()
	_test_ink_flick_miss()
	_test_seeded_replay()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_moth_scribe_ink_mark_test: ",
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


func _to_scribe(battle: StitchedRules, wanted_round: int) -> bool:
	for _step in range(240):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		if battle.round_number() == wanted_round and battle.current_actor_id() == SCRIBE:
			return true
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
	return false


func _single_result(receipt: Dictionary) -> Dictionary:
	if not bool(receipt.get("ok", false)):
		return {}
	var results: Array = receipt.get("results", [])
	if results.size() != 1:
		return {}
	return results[0]


func _single_hit(receipt: Dictionary) -> bool:
	var result := _single_result(receipt)
	return not result.is_empty() and bool(result.get("hit", false))


func _single_miss(receipt: Dictionary) -> bool:
	var result := _single_result(receipt)
	return not result.is_empty() and not bool(result.get("hit", true))


func _inspect_intent(battle: StitchedRules) -> Dictionary:
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor := battle.current_actor_id()
	var round_value := battle.round_number()
	var first := StitchedFoeIntent.choose(battle, battle.get_unit(SCRIBE))
	var second := StitchedFoeIntent.choose(battle, battle.get_unit(SCRIBE))
	return {
		"choice": first,
		"repeat_equal": first == second,
		"read_only": state == battle.state_snapshot()
			and rng == battle.rng_state()
			and actor == battle.current_actor_id()
			and round_value == battle.round_number(),
	}


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


# ---------------------------------------------------------------- AC1 source record

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


func _test_source_contract() -> void:
	var raw: Variant = _read_json(RUN_ENEMIES_PATH)
	_check(raw is Array and not (raw as Array).is_empty(),
		"AC1: the real run enemy catalog parses")
	if not raw is Array:
		return
	var record := _raw_record(raw, SCRIBE)
	_check(not record.is_empty(), "AC1: the run catalog still authors moth_scribe by ID")
	if record.is_empty():
		return

	# The untouched legacy card record and identity stay exactly as authored.
	_check(str(record.get("name", "")) == "Moth Scribe"
		and int(record.get("max_hp", 0)) == 14
		and record.get("chew_block_on_attack") == true
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/moth_scribe.png",
		"AC1: Moth Scribe keeps its name, legacy 14 HP, chew trait and moth art")
	var expected_intent := {
		"target": "exposed",
		"actions": [
			{"type": "attack", "amount": 5, "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 2},
			{"type": "block", "amount": 2, "weight": 1},
		],
	}
	_check(_norm(record.get("intent", {})) == _norm(expected_intent),
		"AC1: the legacy card intent is byte-for-byte unchanged")

	var stitched: Dictionary = record.get("stitched", {})
	_check(int(stitched.get("max_hp", 0)) == 19
		and int(stitched.get("speed", -1)) == 3
		and int(stitched.get("dodge", -1)) == 12
		and int(stitched.get("acc", -1)) == 0
		and int(stitched.get("prot", -1)) == 0
		and stitched.get("is_boss") == false
		and int(stitched.get("turns_per_round", 0)) == 1
		and str(stitched.get("trophy", "")) == "moth_scribe_inkbrush_arm",
		"AC1: the Stitched profile keeps 19 HP, SPEED 3, DODGE 12, ACC 0, PROT 0, one turn and trophy")
	var abilities: Array = stitched.get("abilities", [])
	_check(abilities.size() == 2,
		"AC1: Moth Scribe authors exactly its two existing Stitched abilities")

	var expected_ink := {
		"id": "ink_flick",
		"name": "Ink Flick",
		"kind": "ranged",
		"launch": [2, 3, 4],
		"target": [2, 3, 4],
		"target_side": "enemy",
		"multi": false,
		"acc": 88,
		"dmg": [3, 5],
		"crit": 0,
		"mark_damage": 3,
		"effects": {"fray": 6},
		"self_move": 0,
		"move": "attack2",
	}
	var expected_dust := {
		"id": "dust_scrawl",
		"name": "Dust Scrawl",
		"kind": "debuff",
		"launch": [2, 3, 4],
		"target": [2, 3, 4],
		"target_side": "enemy",
		"multi": false,
		"acc": 88,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"weak": 1, "mark": 3},
		"self_move": 0,
		"move": "skill",
	}
	var ink := _raw_ability(record, "ink_flick")
	var dust := _raw_ability(record, "dust_scrawl")
	_check(_norm(ink) == _norm(expected_ink),
		"AC1: Ink Flick gains only mark_damage 3; every other authored field and attack2 pose is unchanged")
	_check(_norm(dust) == _norm(expected_dust),
		"AC1: Dust Scrawl changes only its rear target ranks and Weak 1 + Mark 3 effects")

	# StitchedParts must accept both corrected records as real enemy abilities.
	var ink_valid := StitchedParts.validate_ability(ink, "test Moth Scribe ink_flick")
	var dust_valid := StitchedParts.validate_ability(dust, "test Moth Scribe dust_scrawl")
	_check(bool(ink_valid.get("ok", false)) and bool(dust_valid.get("ok", false)),
		"AC1: StitchedParts.validate_ability accepts both corrected Moth Scribe moves")
	if bool(ink_valid.get("ok", false)) and bool(dust_valid.get("ok", false)):
		var ink_checked: Dictionary = ink_valid["ability"]
		var dust_checked: Dictionary = dust_valid["ability"]
		_check(int(ink_checked.get("mark_damage", 0)) == 3
			and ink_checked.get("effects") == {"fray": 6}
			and ink_checked.get("launch") == [2, 3, 4]
			and ink_checked.get("target") == [2, 3, 4],
			"AC1: validated Ink Flick keeps rear ranks, Fray 6 and a 3-point Mark bonus")
		_check(dust_checked.get("effects") == {"weak": 1, "mark": 3}
			and dust_checked.get("target") == [2, 3, 4]
			and int(dust_checked.get("mark_damage", -1)) == 0,
			"AC1: validated Dust Scrawl marks and weakens a rear rank without direct damage")

	# Named neighbour: the intended pressure partner keeps its whole authored kit.
	var bulwark := _raw_record(raw, BULWARK)
	_check(not bulwark.is_empty()
		and str(bulwark.get("name", "")) == "Felt Bulwark"
		and int(bulwark.get("max_hp", 0)) == 18
		and int(bulwark.get("stitched", {}).get("max_hp", 0)) == 18
		and int(bulwark.get("stitched", {}).get("speed", -1)) == 2
		and int(bulwark.get("stitched", {}).get("dodge", -1)) == 2
		and int(bulwark.get("stitched", {}).get("prot", -1)) == 10
		and str(bulwark.get("stitched", {}).get("trophy", ""))
			== "felt_bulwark_button_shield",
		"AC1: the felt_moth_pressure partner Felt Bulwark keeps its identity and Stitched stats")
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
	# Check the partner's kit by authored ID: its two existing moves stay exactly as they were
	# and the one added Button Shelter record is the authored ally guard. No ordered full-kit
	# list or ability total is asserted, so parallel catalog lanes stay merge-safe.
	_check(_norm(_raw_ability(bulwark, "felt_slam")) == _norm(expected_slam),
		"AC1: Felt Bulwark's Felt Slam is untouched next to the edited Moth Scribe")
	_check(_norm(_raw_ability(bulwark, "bulwark_pad")) == _norm(expected_pad),
		"AC1: Felt Bulwark's self Thorns-2 Bulwark Pad is untouched")
	_check(_norm(_raw_ability(bulwark, "button_shelter")) == _norm(expected_shelter),
		"AC1: Felt Bulwark gains exactly the authored Button Shelter guard record")

	# Two more authored neighbours stay present with their own kits, not Moth Scribe's numbers.
	var swarm := _raw_record(raw, "moth_swarm")
	var skitter := _raw_record(raw, "pin_skitter")
	_check(str(swarm.get("stitched", {}).get("abilities", [{}])[0].get("id", "")) == "wing_dust"
		and int(swarm.get("stitched", {}).get("max_hp", 0)) == 21
		and str(skitter.get("stitched", {}).get("abilities", [{}])[0].get("id", "")) == "pin_prick"
		and int(skitter.get("stitched", {}).get("max_hp", 0)) == 13,
		"AC1: named neighbouring enemy kits remain their own authored records")


# ---------------------------------------------------------------- AC3 modifier order

func _test_mark_bonus_order() -> void:
	# The flat Mark bonus is added to the direct base first; the authored modifiers then apply.
	# (3 + 3) * 3/4 = 4, whereas a late +3 after Weak would give 3 * 3/4 + 3 = 5.
	_check(StitchedRules.damage_after_modifiers(
		3, {"weak": 1}, {"mark": 1}, true, MARK_BONUS, 0) == 4,
		"AC3: Mark +3 is added before Weak's 3/4 modifier")
	# (3 + 3) * 3/2 = 9, whereas a late +3 after Exposed would give 3 * 3/2 + 3 = 7.
	_check(StitchedRules.damage_after_modifiers(
		3, {}, {"mark": 1, "exposed": 1}, true, MARK_BONUS, 0) == 9,
		"AC3: Mark +3 is added before Exposed's 3/2 modifier")
	# ((3 + 3) * 3/4) + 2 = 6, whereas a late +3 after Weak and Tangled would give 7.
	_check(StitchedRules.damage_after_modifiers(
		3, {"weak": 1}, {"mark": 1, "tangled": 1}, true, MARK_BONUS, 0) == 6,
		"AC3: Mark +3 is added before Weak and Tangled's flat +2")
	# 22 reduced by 5% PROT is 21; a late +3 after PROT would leave 22.
	_check(StitchedRules.damage_after_modifiers(
		19, {}, {}, true, MARK_BONUS, 5) == 21,
		"AC3: Mark +3 raises the total that PROT then cuts")


# ---------------------------------------------------------------- AC1 normalized catalog

func _test_catalog_contract() -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, SCRIBE)
	_check(not foe.is_empty(), "AC1: foe_for resolves the canonical moth_scribe kit")
	if foe.is_empty():
		return
	_check(str(foe.get("id", "")) == SCRIBE and str(foe.get("name", "")) == "Moth Scribe"
		and int(foe.get("max_hp", 0)) == 19
		and int(foe.get("speed", -1)) == 3
		and int(foe.get("dodge", -1)) == 12
		and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 0
		and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the normalized foe keeps its 19 HP, SPEED 3, DODGE 12, ACC 0, PROT 0 and one turn")
	_check(str(StitchedEnemyCatalog.trophy_for(_catalog, SCRIBE)) == "moth_scribe_inkbrush_arm",
		"AC1: the normalized foe still drops the inkbrush arm trophy")
	var abilities: Array = foe.get("abilities", [])
	_check(abilities.size() == 2, "AC1: the normalized foe keeps exactly two moves")
	var ink: Dictionary = {}
	var dust: Dictionary = {}
	for ability in abilities:
		if str(ability.get("id", "")) == "ink_flick":
			ink = ability
		elif str(ability.get("id", "")) == "dust_scrawl":
			dust = ability
	var rear_mask := StitchedParts.rank_mask([2, 3, 4])
	_check(not ink.is_empty()
		and ink.get("launch") == [2, 3, 4] and ink.get("target") == [2, 3, 4]
		and int(ink.get("launch_mask", 0)) == rear_mask
		and int(ink.get("target_mask", 0)) == rear_mask
		and int(ink.get("acc", 0)) == 88 and ink.get("dmg") == [3, 5]
		and int(ink.get("crit", -1)) == 0
		and int(ink.get("mark_damage", 0)) == 3
		and ink.get("effects") == {"fray": 6}
		and str(ink.get("move", "")) == "attack2",
		"AC1: normalized Ink Flick carries the rear-rank masks, ACC 88, 3-5 damage, Fray 6 and mark_damage 3")
	_check(not dust.is_empty()
		and dust.get("launch") == [2, 3, 4] and dust.get("target") == [2, 3, 4]
		and int(dust.get("launch_mask", 0)) == rear_mask
		and int(dust.get("target_mask", 0)) == rear_mask
		and int(dust.get("acc", 0)) == 88 and dust.get("dmg") == [0, 0]
		and int(dust.get("crit", -1)) == 0
		and int(dust.get("mark_damage", 0)) == 0
		and dust.get("effects") == {"weak": 1, "mark": 3}
		and str(dust.get("move", "")) == "skill",
		"AC1: normalized Dust Scrawl targets only ranks 2-4, deals 0 and applies Weak 1 + Mark 3")


func _test_encounter_pairing() -> void:
	var parsed: Variant = _read_json(ENCOUNTER_PATH)
	var fight: Dictionary = {}
	if parsed is Dictionary:
		fight = parsed.get("Fight", {})
	var pressure: Dictionary = fight.get("felt_moth_pressure", {})
	_check(pressure.get("enemy_ids") == [BULWARK, SCRIBE],
		"AC1: the authored felt_moth_pressure fight still pairs Felt Bulwark and Moth Scribe")


# ---------------------------------------------------------------- AC2 public Dust Scrawl

func _test_dust_scrawl_public_turn() -> void:
	var seed_value := _find_dust_seed(true)
	_check(seed_value > 0, "AC2: bounded seed witness for a landed public Dust Scrawl")
	if seed_value <= 0:
		return
	var battle := _new_battle(seed_value)
	_check(battle != null and _to_scribe(battle, 2),
		"AC2: seeded 4v2 battle reaches a genuine round-two Moth Scribe turn")
	if battle == null or not _to_scribe(battle, 2):
		return
	var target_id := _hero_id_at(battle, TARGET_RANK)
	_check(not target_id.is_empty(), "AC2: a living rank-2 hero exists for the rear-line scrawl")

	# Rank 1 is no longer authored as a legal Dust Scrawl target; refusal spends nothing.
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var rank_one_refusal := battle.use_foe_ability("dust_scrawl", 1)
	_check(not bool(rank_one_refusal.get("ok", true))
		and str(rank_one_refusal.get("error", "")).contains("no legal target in rank 1")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC2: Dust Scrawl refuses rank 1 with identical state and RNG")

	var before := battle.get_unit(target_id)
	var cast := battle.use_foe_ability("dust_scrawl", TARGET_RANK)
	var result := _single_result(cast)
	var after := battle.get_unit(target_id)
	_check(not result.is_empty() and bool(result.get("hit", false)),
		"AC2: the witnessed Dust Scrawl is a confirmed single-target hit")
	if result.is_empty():
		return
	_check(str(cast.get("ability", "")) == "dust_scrawl"
		and str(cast.get("target", "")) == target_id
		and int(result.get("damage", -1)) == 0
		and int(after.get("hp", -1)) == int(before.get("hp", -1))
		and int(after.get("statuses", {}).get("weak", 0)) == 1
		and int(after.get("statuses", {}).get("mark", 0)) == 3,
		"AC2: a landed Dust Scrawl deals zero HP damage and applies Weak 1 + Mark 3")
	var statuses := {}
	for entry in result.get("statuses", []):
		statuses[str(entry.get("status", ""))] = int(entry.get("duration", 0))
	_check(int(statuses.get("weak", 0)) == 1 and int(statuses.get("mark", 0)) == 3,
		"AC2: the receipt itself records the Weak 1 and Mark 3 effects")
	for hero in battle.get_heroes():
		if str(hero["id"]) == target_id:
			continue
		_check(int(hero.get("statuses", {}).get("weak", 0)) == 0
			and int(hero.get("statuses", {}).get("mark", 0)) == 0,
			"AC2: only the targeted doll receives Weak and Mark")


func _test_dust_scrawl_miss() -> void:
	var seed_value := _find_dust_seed(false)
	_check(seed_value > 0, "AC2: bounded seed witness for a missed public Dust Scrawl")
	if seed_value <= 0:
		return
	var battle := _new_battle(seed_value)
	if battle == null or not _to_scribe(battle, 2):
		_check(false, "AC2: miss witness reaches a genuine Moth Scribe turn")
		return
	var target_id := _hero_id_at(battle, TARGET_RANK)
	var before := battle.get_unit(target_id)
	var cast := battle.use_foe_ability("dust_scrawl", TARGET_RANK)
	var result := _single_result(cast)
	var after := battle.get_unit(target_id)
	_check(not result.is_empty() and not bool(result.get("hit", true))
		and int(result.get("damage", -1)) == 0
		and int(after.get("hp", -1)) == int(before.get("hp", -1))
		and int(after.get("statuses", {}).get("weak", 0)) == 0
		and int(after.get("statuses", {}).get("mark", 0)) == 0
		and result.get("statuses", []).is_empty(),
		"AC2: a missed Dust Scrawl applies neither Weak nor Mark and deals no damage")


func _test_target_refusals() -> void:
	var seed_value := _find_dust_seed(true)
	if seed_value <= 0:
		_check(false, "AC2: refusal witness seed exists")
		return
	var battle := _new_battle(seed_value)
	if battle == null or not _to_scribe(battle, 1):
		_check(false, "AC2: refusal witness reaches a genuine Moth Scribe turn")
		return
	# Model a real back-line wipe without advancing turns: ranks 2-4 are no longer occupied.
	for rank in [2, 3, 4]:
		var hero_id := _hero_id_at(battle, rank)
		battle._units[hero_id]["lost"] = true
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var dust_ghost := battle.use_foe_ability("dust_scrawl", 4)
	var ink_ghost := battle.use_foe_ability("ink_flick", 3)
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(SCRIBE))
	_check(not bool(dust_ghost.get("ok", true))
		and not bool(ink_ghost.get("ok", true))
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC2: a vacant/lost rear rank cannot be invented and refuses without state or RNG")
	_check(bool(choice.get("pass", false)) and int(choice.get("target_rank", 0)) == 0
		and choice.get("affected_ranks", [1]).is_empty(),
		"AC2: the read-only intent falls back to PASS when ranks 2-4 are gone, never a phantom target")


# ---------------------------------------------------------------- AC3 marked Ink Flick

func _find_dust_seed(require_hit: bool) -> int:
	for seed_value in range(520100, 520700):
		var battle := _new_battle(seed_value)
		if battle == null or not _to_scribe(battle, 2):
			continue
		var cast := battle.use_foe_ability("dust_scrawl", TARGET_RANK)
		if bool(_single_hit(cast)) == require_hit:
			return seed_value
	return -1


func _find_marked_sequence_seed() -> int:
	for seed_value in range(521100, 521700):
		if bool(_probe_marked_sequence(seed_value).get("ok", false)):
			return seed_value
	return -1


func _probe_marked_sequence(seed_value: int) -> Dictionary:
	var battle := _new_battle(seed_value)
	if battle == null or not _to_scribe(battle, 1):
		return {}
	if not bool(battle.use_foe_ability("ink_flick", TARGET_RANK).get("ok", false)):
		return {}
	if not _to_scribe(battle, 2):
		return {}
	if not _single_hit(battle.use_foe_ability("dust_scrawl", TARGET_RANK)):
		return {}
	var target_id := _hero_id_at(battle, TARGET_RANK)
	if int(battle.get_unit(target_id)["statuses"].get("mark", 0)) != 3:
		return {}
	if not _to_scribe(battle, 3):
		return {}
	if int(battle.get_unit(target_id)["statuses"].get("mark", 0)) <= 0:
		return {}
	if not _single_hit(battle.use_foe_ability("ink_flick", TARGET_RANK)):
		return {}
	return {"ok": true}


## Plays the genuine public sequence up to the round-three Moth Scribe turn. When erase_mark
## is true the only difference from its twin is that the already-landed Mark is removed.
func _play_to_round3(seed_value: int, erase_mark: bool) -> Dictionary:
	var battle := _new_battle(seed_value)
	if battle == null or not _to_scribe(battle, 1):
		return {}
	var data := {"battle": battle}
	data["inspect1"] = _inspect_intent(battle)
	data["first"] = battle.use_foe_ability("ink_flick", TARGET_RANK)
	if not bool(data["first"].get("ok", false)):
		return {}
	if not _to_scribe(battle, 2):
		return {}
	data["inspect2"] = _inspect_intent(battle)
	var target_id := _hero_id_at(battle, TARGET_RANK)
	data["target_id"] = target_id
	data["before_dust"] = battle.get_unit(target_id)
	data["dust"] = battle.use_foe_ability("dust_scrawl", TARGET_RANK)
	if not _single_hit(data["dust"]):
		return {}
	data["after_dust"] = battle.get_unit(target_id)
	if erase_mark:
		battle._units[target_id]["statuses"].erase("mark")
	if not _to_scribe(battle, 3):
		return {}
	data["mark_before_round3"] = int(
		battle.get_unit(target_id)["statuses"].get("mark", 0))
	data["inspect3"] = _inspect_intent(battle)
	data["before_ink"] = battle.get_unit(target_id)
	data["rng_before_ink"] = battle.rng_state()
	return data


func _verify_intent(inspect: Dictionary, label: String, ability_id: String,
		ability_name: String, kind: String, acc: int, damage: Array,
		effects: Dictionary, mark_damage: int) -> void:
	var choice: Dictionary = inspect.get("choice", {})
	_check(bool(inspect.get("repeat_equal", false)) and bool(inspect.get("read_only", false)),
		"%s: repeated intent projection spends no state, RNG or turn" % label)
	_check(not bool(choice.get("pass", true))
		and str(choice.get("ability_id", "")) == ability_id
		and str(choice.get("ability_name", "")) == ability_name
		and str(choice.get("ability_kind", "")) == kind
		and str(choice.get("target_side", "")) == "hero"
		and int(choice.get("target_rank", 0)) == TARGET_RANK
		and choice.get("affected_ranks", []) == [TARGET_RANK]
		and choice.get("multi") == false,
		"%s: intent announces %s against the living rank-2 hero" % [label, ability_name])
	_check(int(choice.get("base_acc", -1)) == acc
		and choice.get("base_damage", []) == damage
		and int(choice.get("base_crit", -1)) == 0
		and choice.get("base_effects", {}) == effects
		and int(choice.get("base_mark_damage", -1)) == mark_damage,
		"%s: intent discloses the exact authored ACC, base damage, crit, effects and Mark bonus" % label)


func _test_marked_ink_flick() -> void:
	var seed_value := _find_marked_sequence_seed()
	_check(seed_value > 0,
		"AC3/AC4: bounded seed witness for Ink Flick -> Dust Scrawl -> Ink Flick with Mark surviving")
	if seed_value <= 0:
		return
	var marked := _play_to_round3(seed_value, false)
	var unmarked := _play_to_round3(seed_value, true)
	_check(not marked.is_empty() and not unmarked.is_empty(),
		"AC3: paired identical-seed battles both reach the round-three Moth Scribe turn")
	if marked.is_empty() or unmarked.is_empty():
		return
	var marked_battle: StitchedRules = marked["battle"]
	var unmarked_battle: StitchedRules = unmarked["battle"]
	var target_id := str(marked["target_id"])
	_check(target_id == str(unmarked["target_id"]) and not target_id.is_empty(),
		"AC3: both twins target the same living rank-2 doll")

	# AC4: the authored two-move round rotation and its announced numbers.
	_verify_intent(marked["inspect1"], "AC4 round 1", "ink_flick", "Ink Flick",
		"ranged", 88, [3, 5], {"fray": 6}, MARK_BONUS)
	_verify_intent(marked["inspect2"], "AC4 round 2", "dust_scrawl", "Dust Scrawl",
		"debuff", 88, [0, 0], {"weak": 1, "mark": 3}, 0)
	_verify_intent(marked["inspect3"], "AC4 round 3", "ink_flick", "Ink Flick",
		"ranged", 88, [3, 5], {"fray": 6}, MARK_BONUS)
	_check(_norm(marked["inspect1"]) == _norm(unmarked["inspect1"])
		and _norm(marked["inspect2"]) == _norm(unmarked["inspect2"])
		and _norm(marked["inspect3"]) == _norm(unmarked["inspect3"]),
		"AC3/AC4: both twins read identical intents before their identical public actions")

	# The announced moves are the moves actually used.
	_check(str(marked["first"].get("ability", "")) == "ink_flick"
		and str(marked["dust"].get("ability", "")) == "dust_scrawl"
		and _norm(marked["first"]) == _norm(unmarked["first"])
		and _norm(marked["dust"]) == _norm(unmarked["dust"]),
		"AC4: round-one Ink Flick and round-two Dust Scrawl receipts match the announced IDs")
	_check(int(marked["mark_before_round3"]) > 0
		and int(marked["mark_before_round3"]) <= 3,
		"AC4: Mark 3 survives the intervening ordinary hero turn(s) into round 3")
	_check(int(unmarked["mark_before_round3"]) == 0,
		"AC3: the unmarked twin really has no Mark before its otherwise identical strike")

	var marked_before: Dictionary = marked["before_ink"]
	var unmarked_before: Dictionary = unmarked["before_ink"]
	_check(marked_battle.rng_state() == unmarked_battle.rng_state()
		and int(marked_battle.current_actor_id().length()) > 0
		and marked_battle.current_actor_id() == unmarked_battle.current_actor_id(),
		"AC3: both twins stand at the same genuine turn with identical RNG")
	var marked_ink := marked_battle.use_foe_ability("ink_flick", TARGET_RANK)
	var unmarked_ink := unmarked_battle.use_foe_ability("ink_flick", TARGET_RANK)
	var marked_result := _single_result(marked_ink)
	var unmarked_result := _single_result(unmarked_ink)
	_check(not marked_result.is_empty() and not unmarked_result.is_empty()
		and bool(marked_result.get("hit", false)) and bool(unmarked_result.get("hit", false)),
		"AC3: both same-seed Ink Flicks land on their rank-2 target")
	if marked_result.is_empty() or unmarked_result.is_empty():
		return
	_check(int(marked_result.get("roll", -1)) == int(unmarked_result.get("roll", -2))
		and bool(marked_result.get("crit", false)) == bool(unmarked_result.get("crit", false))
		and int(marked_result.get("hit_chance", -1)) == int(unmarked_result.get("hit_chance", -2))
		and marked_battle.rng_state() == unmarked_battle.rng_state(),
		"AC3: preserving the same seed preserves the hit, crit and damage RNG rolls")

	var after_marked := marked_battle.get_unit(target_id)
	var after_unmarked := unmarked_battle.get_unit(target_id)
	var prot := int(marked_before.get("prot", 0))
	var unmarked_damage := int(unmarked_result.get("damage", 0))
	var base := -1
	if bool(unmarked_result.get("crit", false)):
		base = StitchedRules.crit_damage(5)
	else:
		for candidate in [3, 4, 5]:
			if int(StitchedRules.damage_after_modifiers(
					candidate, {}, unmarked_before["statuses"], false, 0, prot)) == unmarked_damage:
				base = candidate
				break
	_check(base > 0 and unmarked_damage == base,
		"AC3: the unmarked Ink Flick reveals its rolled base damage before any Mark")
	if base <= 0:
		return
	var pre_prot_bonus := int(StitchedRules.damage_after_modifiers(
		base, {}, unmarked_before["statuses"], true, MARK_BONUS, 0))
	var expected_final := StitchedRules.apply_protection(pre_prot_bonus, prot)
	_check(pre_prot_bonus == base + MARK_BONUS,
		"AC3: Mark adds exactly +3 direct base damage before Weak/Exposed/Tangled/PROT")
	_check(int(marked_result.get("damage", 0)) == expected_final
		and int(marked_result.get("damage", 0)) > unmarked_damage,
		"AC3: the Marked hit's final damage is the independently computed pre-PROT +3 after PROT")
	_check(int(marked_before.get("hp", 0)) - int(after_marked.get("hp", 0))
		== int(marked_result.get("damage", 0))
		and int(unmarked_before.get("hp", 0)) - int(after_unmarked.get("hp", 0))
		== unmarked_damage,
		"AC3: real HP loss matches each public receipt's final damage")

	var marked_fray_delta := int(after_marked.get("fray", 0)) - int(marked_before.get("fray", 0))
	var unmarked_fray_delta := int(after_unmarked.get("fray", 0)) \
		- int(unmarked_before.get("fray", 0))
	_check(marked_fray_delta == FRAY_ON_INK_HIT and unmarked_fray_delta == FRAY_ON_INK_HIT,
		"AC3: a confirmed Ink Flick still adds its independent +6 Fray with or without Mark")


func _find_ink_miss_seed() -> int:
	for seed_value in range(522100, 522700):
		var battle := _new_battle(seed_value)
		if battle == null or not _to_scribe(battle, 1):
			continue
		if not bool(battle.use_foe_ability("ink_flick", TARGET_RANK).get("ok", false)):
			continue
		if not _to_scribe(battle, 2):
			continue
		if not _single_hit(battle.use_foe_ability("dust_scrawl", TARGET_RANK)):
			continue
		var target_id := _hero_id_at(battle, TARGET_RANK)
		if int(battle.get_unit(target_id)["statuses"].get("mark", 0)) != 3:
			continue
		if not _to_scribe(battle, 3):
			continue
		if int(battle.get_unit(target_id)["statuses"].get("mark", 0)) <= 0:
			continue
		if _single_miss(battle.use_foe_ability("ink_flick", TARGET_RANK)):
			return seed_value
	return -1


func _test_ink_flick_miss() -> void:
	var seed_value := _find_ink_miss_seed()
	_check(seed_value > 0, "AC3: bounded seed witness for a missed Ink Flick on a Marked doll")
	if seed_value <= 0:
		return
	var battle := _new_battle(seed_value)
	if battle == null or not _to_scribe(battle, 1):
		_check(false, "AC3: Ink Flick miss witness reaches a genuine turn")
		return
	battle.use_foe_ability("ink_flick", TARGET_RANK)
	if not _to_scribe(battle, 2):
		return
	battle.use_foe_ability("dust_scrawl", TARGET_RANK)
	if not _to_scribe(battle, 3):
		return
	var target_id := _hero_id_at(battle, TARGET_RANK)
	var before := battle.get_unit(target_id)
	var mark_before := int(before.get("statuses", {}).get("mark", 0))
	var cast := battle.use_foe_ability("ink_flick", TARGET_RANK)
	var result := _single_result(cast)
	var after := battle.get_unit(target_id)
	_check(mark_before > 0 and not result.is_empty() and not bool(result.get("hit", true))
		and int(result.get("damage", -1)) == 0
		and int(result.get("statuses", []).size()) == 0
		and int(after.get("hp", -1)) == int(before.get("hp", -1))
		and int(after.get("fray", -1)) == int(before.get("fray", -1))
		and int(after.get("statuses", {}).get("mark", 0)) == mark_before,
		"AC3: a Marked target's missed Ink Flick adds neither +3 damage nor Fray and applies no status")


# ---------------------------------------------------------------- AC5 seeded replay

func _scripted_trace(seed_value: int) -> Array:
	var battle := _new_battle(seed_value)
	if battle == null:
		return []
	var trace: Array = []
	for wanted_round in [1, 2, 3]:
		if not _to_scribe(battle, wanted_round):
			return []
		var ability_id := "dust_scrawl" if wanted_round == 2 else "ink_flick"
		var receipt := battle.use_foe_ability(ability_id, TARGET_RANK)
		trace.append({
			"round": wanted_round,
			"ability": ability_id,
			"receipt": receipt,
			"snapshot": battle.state_snapshot(),
			"rng": battle.rng_state(),
			"next_actor": battle.current_actor_id(),
		})
	return trace


func _test_seeded_replay() -> void:
	var seed_value := _find_marked_sequence_seed()
	_check(seed_value > 0, "AC5: bounded replay seed witness exists")
	if seed_value <= 0:
		return
	var first := _scripted_trace(seed_value)
	var second := _scripted_trace(seed_value)
	_check(first.size() == 3 and second.size() == 3 and _norm(first) == _norm(second),
		"AC5: the identical seed and legal action script replay receipts, HP/fray, order and RNG exactly")
	_check(first.size() == 3
		and str(first[0]["ability"]) == "ink_flick"
		and str(first[1]["ability"]) == "dust_scrawl"
		and str(first[2]["ability"]) == "ink_flick",
		"AC5: the replayed script really performs Ink Flick, Dust Scrawl, then Ink Flick")
