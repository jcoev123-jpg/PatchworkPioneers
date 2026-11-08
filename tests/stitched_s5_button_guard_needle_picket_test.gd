extends SceneTree
## S5 Button Guard knitting-needle Mark setup and marked-rank spear follow-up.
##
## The shipped run roster's Button Guard keeps its three-hole button shield (Button Wall, Thorns 2),
## now reaches Seam Punch into hero ranks 1-2 with an authored +3 against a Marked doll, and gains
## Needle Picket (ACC 88, 2-3, Mark 3, single target, attack2) as its third Stitched action.
##
## Everything is exercised through the real StitchedEnemyCatalog, StitchedParts, StitchedFoeIntent and
## StitchedRules public turns on the real four-doll preview party plus a canonical normal escort.
## Per-ID source lookups only: no catalog total, absolute position or full ID order.
## Deterministic: one seeded RandomNumberGenerator per battle, bounded witness searches and a replay.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"

const GUARD := "button_guard"
const SCAV := "fray_scavenger"
const RAGLING := "ragling"
const SCRIBE := "moth_scribe"

const SEED_LIMIT := 24
const CHAIN_LIMIT := 32
const TURN_LIMIT := 240
const ROTATION_SEED := 5

const LEGACY_INTENT := {
	"target": "front",
	"actions": [
		{"type": "attack", "amount": 5, "weight": 1},
		{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
		{"type": "block", "amount": 2, "weight": 2},
		{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
		{"type": "shove", "amount": 0, "direction": 1, "weight": 1},
	],
}
const SEAM_PUNCH := {
	"id": "seam_punch", "name": "Seam Punch", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [3, 5], "crit": 0, "mark_damage": 3, "effects": {},
	"self_move": 0, "move": "attack",
}
const BUTTON_WALL := {
	"id": "button_wall", "name": "Button Wall", "kind": "buff",
	"launch": [1, 2], "target": [1], "target_side": "self", "multi": false,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"thorns": 2},
	"self_move": 0, "move": "skill",
}
const NEEDLE_PICKET := {
	"id": "needle_picket", "name": "Needle Picket", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [2, 3], "crit": 0, "effects": {"mark": 3},
	"self_move": 0, "move": "attack2",
}
const COMBOS := [[1, 1], [1, 2], [2, 1], [2, 2]]

var failures: Array[String] = []
var checks := 0
var _catalog: Dictionary = {}
var _preview: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	_test_loaded_loader()
	_test_refusals()
	var pickets := _scan_pickets()
	if int(pickets.get("hit", -1)) > 0 and int(pickets.get("miss", -1)) > 0 \
			and int(pickets.get("max", -1)) > 0:
		_test_picket_targets(pickets)
	var witnesses := _scan_chains()
	if int(witnesses.get("marked", -1)) > 0:
		_test_marked_punch(int(witnesses["marked"]))
		_test_expired_mark(int(witnesses["marked"]))
	if int(witnesses.get("no_mark", -1)) > 0:
		_test_no_mark_fallback(int(witnesses["no_mark"]))
	_test_standard_rotation()
	_test_replay(witnesses)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_button_guard_needle_picket_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


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


func _record_matches(records: Variant, enemy_id: String) -> Array:
	if not records is Array:
		return []
	return (records as Array).filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == enemy_id)


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

func _config(seed_value: int, foe_ids: Array = [GUARD, SCAV], heroes: Array = []) -> Dictionary:
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


func _make_battle(seed_value: int, foe_ids: Array = [GUARD, SCAV],
		heroes: Array = []) -> StitchedRules:
	var config := _config(seed_value, foe_ids, heroes)
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
		if int(hero["rank"]) == rank and not bool(hero.get("lost", false)):
			return hero
	return {}


func _marks_of(units: Dictionary) -> Dictionary:
	var marks: Dictionary = {}
	for unit_id in units:
		var mark := int(units[unit_id].get("statuses", {}).get("mark", 0))
		if mark > 0:
			marks[unit_id] = mark
	return marks


## Plays the genuine rotation to the requested actor's turn in the requested round. Hero turns
## pass; foe turns commit the real projected choice. Every committed event is recorded for replay
## and rotation checks.
func _drive(battle: StitchedRules, wanted_round: int, actor_id: String,
		history: Array = []) -> bool:
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
	var matches := _record_matches(raw, GUARD)
	_check(matches.size() == 1, "AC1: the shipped roster authors exactly one Button Guard by ID")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(str(record.get("name", "")) == "Button Guard" and int(record.get("max_hp", 0)) == 16
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/button_guard.png",
		"AC1: Button Guard keeps its legacy name, 16 HP and button-guard sprite")
	_check(_norm(record.get("intent", {})) == _norm(LEGACY_INTENT),
		"AC1: the entire original weighted legacy intent stays exact")
	var profile: Dictionary = record.get("stitched", {})
	_check(int(profile.get("max_hp", 0)) == 16 and int(profile.get("speed", -1)) == 3
		and int(profile.get("dodge", -1)) == 4 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 6 and not bool(profile.get("is_boss", true))
		and int(profile.get("turns_per_round", 0)) == 1
		and str(profile.get("trophy", "")) == "button_guard_button_buckler",
		"AC1: the unchanged profile keeps HP 16, SPEED 3, DODGE 4, ACC 0, PROT 6 and its trophy")

	var seam_raw := _raw_ability(record, "seam_punch")
	var wall_raw := _raw_ability(record, "button_wall")
	var picket_raw := _raw_ability(record, "needle_picket")
	_check(_norm(seam_raw) == _norm(SEAM_PUNCH),
		"AC1: Seam Punch changes only reach to [1,2] and gains mark_damage 3")
	_check(_norm(wall_raw) == _norm(BUTTON_WALL),
		"AC1: Button Wall stays byte-exact, including its Thorns 2 shield")
	_check(_norm(picket_raw) == _norm(NEEDLE_PICKET),
		"AC1: Needle Picket is appended as the exact authored third action")
	var authored: Array = profile.get("abilities", [])
	_check(authored.size() == 3 and str(authored[0].get("id", "")) == "seam_punch"
		and str(authored[1].get("id", "")) == "button_wall"
		and str(authored[2].get("id", "")) == "needle_picket",
		"AC1: the three actions sit in the order Seam Punch, Button Wall, Needle Picket")

	var seam := StitchedParts.validate_ability(seam_raw, "test Seam Punch")
	var wall := StitchedParts.validate_ability(wall_raw, "test Button Wall")
	var picket := StitchedParts.validate_ability(picket_raw, "test Needle Picket")
	_check(bool(seam.get("ok", false)) and bool(wall.get("ok", false))
		and bool(picket.get("ok", false)),
		"AC1: StitchedParts validates all three Button Guard actions")
	if bool(seam.get("ok", false)):
		var ability: Dictionary = seam["ability"]
		_check(ability.get("target") == [1, 2]
			and int(ability.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(ability.get("mark_damage", -1)) == 3
			and int(ability.get("acc", -1)) == 86 and ability.get("dmg") == [3, 5]
			and not bool(ability.get("multi", true))
			and _norm(ability.get("effects")) == _norm({})
			and str(ability.get("move", "")) == "attack",
			"AC1: normalized Seam Punch reaches ranks 1-2 for 3-5 at ACC 86 with +3 on a Mark")
	if bool(wall.get("ok", false)):
		var ability: Dictionary = wall["ability"]
		_check(ability.get("launch") == [1, 2]
			and int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and ability.get("target") == [1] and str(ability.get("target_side", "")) == "self"
			and int(ability.get("acc", -1)) == 100 and ability.get("dmg") == [0, 0]
			and _norm(ability.get("effects")) == _norm({"thorns": 2})
			and str(ability.get("move", "")) == "skill",
			"AC1: normalized Button Wall is the unchanged self Thorns 2 buff")
	if bool(picket.get("ok", false)):
		var ability: Dictionary = picket["ability"]
		_check(str(ability.get("kind", "")) == "melee"
			and ability.get("launch") == [1, 2] and ability.get("target") == [1, 2]
			and int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(ability.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and str(ability.get("target_side", "")) == "enemy"
			and not bool(ability.get("multi", false))
			and int(ability.get("acc", -1)) == 88 and ability.get("dmg") == [2, 3]
			and int(ability.get("crit", -1)) == 0
			and int(ability.get("mark_damage", -1)) == 0
			and _norm(ability.get("effects")) == _norm({"mark": 3})
			and int(ability.get("self_move", -1)) == 0
			and str(ability.get("move", "")) == "attack2",
			"AC1: normalized Needle Picket is the single-target ACC-88 2-3 Mark 3 attack2")

	# A malformed copy of the new action still fails closed.
	var broken := picket_raw.duplicate(true)
	broken["effects"] = {"mark": 0}
	_check(not bool(StitchedParts.validate_ability(broken, "broken picket").get("ok", true)),
		"AC1: a Mark 0 Needle Picket copy is refused")
	broken = picket_raw.duplicate(true)
	broken["target"] = [1, 5]
	_check(not bool(StitchedParts.validate_ability(broken, "broken picket").get("ok", true)),
		"AC1: an illegal Needle Picket target rank is refused")


func _test_loaded_loader() -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, GUARD)
	_check(not foe.is_empty() and str(foe.get("name", "")) == "Button Guard"
		and int(foe.get("max_hp", 0)) == 16 and int(foe.get("speed", -1)) == 3
		and int(foe.get("dodge", -1)) == 4 and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 6 and not bool(foe.get("is_boss", true))
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the real loader keeps Button Guard's stats and one turn per round")
	_check(StitchedEnemyCatalog.trophy_for(_catalog, GUARD) == "button_guard_button_buckler",
		"AC1: the real loader still awards the button buckler trophy")
	var seam := StitchedParts.validate_ability(SEAM_PUNCH, "loaded Seam Punch")
	var wall := StitchedParts.validate_ability(BUTTON_WALL, "loaded Button Wall")
	var picket := StitchedParts.validate_ability(NEEDLE_PICKET, "loaded Needle Picket")
	if not foe.is_empty() and bool(seam.get("ok", false)) and bool(wall.get("ok", false)) \
			and bool(picket.get("ok", false)):
		_check(foe.get("abilities") == [seam["ability"], wall["ability"], picket["ability"]],
			"AC1: foe_for publishes exactly the validated three-action kit in authored order")
		var loaded := _loaded_ability(foe, "seam_punch")
		_check(loaded.get("target") == [1, 2]
			and int(loaded.get("mark_damage", 0)) == 3
			and _norm(loaded.get("effects")) == _norm({}),
			"AC1: the loaded Seam Punch reaches ranks 1-2 with its Mark bonus")
		var picked := _loaded_ability(foe, "needle_picket")
		_check(picked.get("launch") == [1, 2] and picked.get("target") == [1, 2]
			and not bool(picked.get("multi", true))
			and int(picked.get("acc", -1)) == 88 and picked.get("dmg") == [2, 3]
			and _norm(picked.get("effects")) == _norm({"mark": 3}),
			"AC1: the loaded Needle Picket is the single-target Mark 3 needle")
	_check(str(_catalog.get("enemies", {}).get(GUARD, {}).get("tier", "")) == "normal",
		"AC1: Button Guard remains a normal-tier canonical foe")
	# Named neighbours still resolve; no catalog total or full ID order is asserted.
	for neighbour in [SCAV, SCRIBE, RAGLING]:
		_check(not StitchedEnemyCatalog.foe_for(_catalog, neighbour).is_empty(),
			"AC1: the neighbouring normal " + neighbour + " still resolves unchanged")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	_check(not _raw_record(raw, SCRIBE).is_empty() and not _raw_record(raw, SCAV).is_empty(),
		"AC1: the neighbouring source records are still authored in the roster")


# ---------------------------------------------------------------- AC4 refusals

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
	# Legal rank 1: unknown action, out-of-reach target ranks and a wrong self target.
	var legal := _make_battle(3)
	if legal == null:
		return
	if not _drive(legal, 1, GUARD):
		_check(false, "AC4: the refusal fixture reaches Button Guard's rank-1 turn")
		return
	_check(int(legal.get_unit(GUARD).get("rank", 0)) == 1,
		"AC4: the two-foe line really places Button Guard in rank 1")
	_check_refusal(legal, "needle_picket", 3, "no legal target in rank 3",
		"AC4: Needle Picket refuses an out-of-reach rank 3 without spending anything")
	_check_refusal(legal, "needle_picket", 4, "no legal target in rank 4",
		"AC4: Needle Picket refuses an out-of-reach rank 4 without spending anything")
	_check_refusal(legal, "seam_punch", 3, "no legal target in rank 3",
		"AC4: Seam Punch refuses rank 3 because its authored reach stops at rank 2")
	_check_refusal(legal, "button_wall", 2, "no legal target in rank 2",
		"AC4: Button Wall refuses a self target that is not its occupied rank")
	_check_refusal(legal, "picket_extra", 1, "the foe has no ability picket_extra",
		"AC4: an unauthored Button Guard action is refused atomically")
	# The refused probes leave the genuine actions available on the same turn.
	var wall := legal.use_foe_ability("button_wall", 1)
	_check(bool(wall.get("ok", false)) and wall.get("results", []).size() == 1
		and int(legal.get_unit(GUARD).get("statuses", {}).get("thorns", 0)) == 2,
		"AC4: the same real turn still resolves Button Wall's self Thorns 2")

	# A rank-2 Button Guard legally launches both reworked attacks.
	var wrong_rank := _make_battle(5, [SCAV, GUARD])
	if wrong_rank == null:
		return
	if not _drive(wrong_rank, 1, GUARD):
		_check(false, "AC4: the rank-2 fixture reaches the rank-2 Button Guard's turn")
		return
	_check(int(wrong_rank.get_unit(GUARD).get("rank", 0)) == 2,
		"AC4: the two-foe line really places Button Guard in rank 2")
	# The unchanged self-target [1] can only shield the guard's own occupied rank: from rank 2 its
	# launch is legal but neither rank 1 nor rank 2 is a legal self target.
	_check_refusal(wrong_rank, "button_wall", 2, "no legal target in rank 2",
		"AC4: the rank-2 Button Wall self target is refused without spending anything")
	_check_refusal(wrong_rank, "button_wall", 1, "no legal target in rank 1",
		"AC4: Button Wall never shields a different rank on the guard's own side")
	var launched := wrong_rank.use_foe_ability("needle_picket", 2)
	_check(bool(launched.get("ok", false)) and launched.get("results", []).size() == 1
		and int(launched["results"][0].get("target_rank", 0)) == 2,
		"AC4: Needle Picket legally launches from Button Guard rank 2 at hero rank 2")

	# A rank-3 Button Guard cannot launch either reworked attack.
	var rank_three := _make_battle(5, [SCAV, RAGLING, GUARD])
	if rank_three == null:
		return
	if not _drive(rank_three, 1, GUARD):
		_check(false, "AC4: the rank-3 fixture reaches Button Guard's turn")
		return
	_check(int(rank_three.get_unit(GUARD).get("rank", 0)) == 3,
		"AC4: the three-foe line really places Button Guard in rank 3")
	_check_refusal(rank_three, "needle_picket", 1, "ability cannot launch from rank 3",
		"AC4: Needle Picket refuses an illegal rank-3 launch without spending anything")
	_check_refusal(rank_three, "seam_punch", 1, "ability cannot launch from rank 3",
		"AC4: Seam Punch refuses an illegal rank-3 launch without spending anything")

	# A foe action on a hero turn is refused without spending the hero's turn.
	var hero_turn := _make_battle(7)
	if hero_turn == null:
		return
	for _step in range(20):
		if hero_turn.is_over() or hero_turn.current_side() == "hero":
			break
		hero_turn.pass_turn()
	_check(hero_turn.current_side() == "hero", "AC4: a real hero turn precedes the actor probe")
	_check_refusal(hero_turn, "needle_picket", 1, "it is not a foe turn",
		"AC4: a Button Guard action on a hero turn spends no state, journal, turn or RNG")

	# An absent (LOST) rank is not a legal Needle Picket target.
	var party: Array = _preview["heroes"].duplicate(true)
	party[1].merge({"hp": 0, "lost": true, "parts": {}}, true)
	var absent := _make_battle(5, [GUARD, SCAV], party)
	if absent == null:
		return
	if not _drive(absent, 1, GUARD):
		_check(false, "AC4: the absent-rank fixture reaches Button Guard's turn")
		return
	_check(bool(absent.get_unit(str(party[1]["id"])).get("lost", false)),
		"AC4: the rank-2 doll really is LOST before the refusal probe")
	_check_refusal(absent, "needle_picket", 2, "no legal target in rank 2",
		"AC4: Needle Picket refuses a rank whose doll is LOST")
	var other := absent.use_foe_ability("needle_picket", 1)
	_check(bool(other.get("ok", false)) and other.get("results", []).size() == 1
		and int(other["results"][0].get("target_rank", 0)) == 1,
		"AC4: the living rank 1 stays a legal Needle Picket target")


# ---------------------------------------------------------------- AC2 the needle

## Damage outcomes of one Needle Picket, computed with the shipped pipeline for both authored base
## rolls. The picket's own Mark is not yet on the doll and its mark_damage is nil.
func _picket_damages(battle: StitchedRules, actor: Dictionary, target: Dictionary) -> Array:
	var damages: Array = []
	for base in range(2, 4):
		var scaled := base
		if str(actor.get("side", "")) == "foe":
			scaled = StitchedS1BEffects.enemy_damage(base, battle.candle())
		var value := StitchedRules.damage_after_modifiers(
			scaled,
			actor.get("statuses", {}),
			target.get("statuses", {}),
			false,
			0,
			int(target.get("prot", 0))
		)
		if not damages.has(value):
			damages.append(value)
	damages.sort()
	return damages


## One real Needle Picket from Button Guard's genuine first turn. `launch_rank` chooses its foe
## rank through the real authored line, `target_rank` the hero rank it spears.
func _picket_trace(seed_value: int, launch_rank: int, target_rank: int) -> Dictionary:
	var foe_ids: Array = [GUARD, SCAV] if launch_rank == 1 else [SCAV, GUARD]
	var battle := _make_battle(seed_value, foe_ids)
	if battle == null:
		return {}
	if not _drive(battle, 1, GUARD):
		return {}
	if int(battle.get_unit(GUARD).get("rank", 0)) != launch_rank:
		return {}
	var actor := battle.get_unit(GUARD)
	var heroes_before := _hero_map(battle)
	var foes_before := _foe_map(battle)
	var receipt := battle.use_foe_ability("needle_picket", target_rank)
	return {
		"battle": battle,
		"actor": actor,
		"heroes_before": heroes_before,
		"foes_before": foes_before,
		"heroes_after": _hero_map(battle),
		"foes_after": _foe_map(battle),
		"receipt": receipt,
	}


## Bounded natural witnesses: one landed and one missed picket per launch/target combo, plus an
## uncritical 3-damage hit proving the authored upper bound.
func _scan_pickets() -> Dictionary:
	var found := {"hit": -1, "miss": -1, "max": -1}
	for combo in COMBOS:
		var combo_hit := -1
		var combo_miss := -1
		var combo_max := -1
		for seed_value in range(1, SEED_LIMIT + 1):
			var trace := _picket_trace(seed_value, int(combo[0]), int(combo[1]))
			if trace.is_empty():
				continue
			var results: Array = trace["receipt"].get("results", [])
			if results.size() != 1:
				continue
			var result: Dictionary = results[0]
			if bool(result.get("hit", false)) and not bool(result.get("crit", false)):
				var target_id := str(result.get("target", ""))
				if int(trace["heroes_after"].get(target_id, {}).get("statuses", {}).get("mark", 0)) == 3:
					if combo_hit < 0:
						combo_hit = seed_value
					if int(result.get("damage", 0)) == 3 and combo_max < 0:
						combo_max = seed_value
			elif not bool(result.get("hit", true)) and combo_miss < 0:
				combo_miss = seed_value
			if combo_hit > 0 and combo_miss > 0 and combo_max > 0:
				break
		_check(combo_hit > 0 and combo_miss > 0 and combo_max > 0,
			"AC2: bounded seeds witness launch %d against hero rank %d as a Mark 3 hit, a miss and a 3-damage hit"
				% [int(combo[0]), int(combo[1])])
		if int(found["hit"]) < 0:
			found["hit"] = combo_hit
		if int(found["miss"]) < 0:
			found["miss"] = combo_miss
		if int(found["max"]) < 0:
			found["max"] = combo_max
	return found


func _test_picket_targets(witnesses: Dictionary) -> void:
	for combo in COMBOS:
		_test_picket_hit(int(witnesses["hit"]), int(combo[0]), int(combo[1]))
		_test_picket_miss(int(witnesses["miss"]), int(combo[0]), int(combo[1]))
	_test_picket_max_damage(int(witnesses["max"]))


func _test_picket_hit(seed_value: int, launch_rank: int, target_rank: int) -> void:
	var trace := _picket_trace(seed_value, launch_rank, target_rank)
	if trace.is_empty():
		_check(false, "AC2: the hit witness reaches Button Guard's turn")
		return
	var battle: StitchedRules = trace["battle"]
	var receipt: Dictionary = trace["receipt"]
	var results: Array = receipt.get("results", [])
	_check(bool(receipt.get("ok", false)) and str(receipt.get("actor", "")) == GUARD
		and str(receipt.get("ability", "")) == "needle_picket" and results.size() == 1,
		"AC2: Needle Picket commits exactly one result from launch rank %d" % launch_rank)
	if results.size() != 1:
		return
	var result: Dictionary = results[0]
	var target := _hero_at(battle, target_rank)
	var target_id := str(target.get("id", ""))
	var before: Dictionary = trace["heroes_before"].get(target_id, {})
	var after: Dictionary = trace["heroes_after"].get(target_id, {})
	_check(str(result.get("target", "")) == target_id
		and int(result.get("target_rank", 0)) == target_rank
		and str(result.get("target_side", "")) == "hero",
		"AC2: the single receipt names the living hero in rank %d" % target_rank)
	var chance := _expected_chance(battle, trace["actor"], before,
		int(trace["actor"].get("miss_streak", 0)), 88)
	_check(int(result.get("hit_chance", -1)) == chance and result.has("roll")
		and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
		"AC2: the needle rolls its authored ACC 88 against that doll's real DODGE")
	_check(bool(result.get("hit", false)) and not bool(result.get("crit", true)),
		"AC2: the witness seed lands an uncritical needle hit")
	var picket_damages := _picket_damages(battle, trace["actor"], before)
	_check(picket_damages == [2, 3] and picket_damages.has(int(result.get("damage", -1))),
		"AC2: the landed needle deals its authored 2-3 before every modifier")
	_check(result.get("statuses", []) == [{"status": "mark", "duration": 3}],
		"AC2: only a confirmed needle hit applies exactly Mark 3")
	_check(int(after.get("statuses", {}).get("mark", 0)) == 3,
		"AC2: the struck doll's real status ledger carries Mark 3")
	_check(int(after.get("hp", -1)) == int(before.get("hp", -2)) - int(result.get("damage", 0)),
		"AC2: the struck doll's HP drops by exactly the rolled damage")
	for other_rank in [1, 2, 3, 4]:
		if other_rank == target_rank:
			continue
		var other := _hero_at(battle, other_rank)
		var other_id := str(other.get("id", ""))
		_check(trace["heroes_after"].get(other_id) == trace["heroes_before"].get(other_id),
			"AC2: hero rank %d is never a needle victim and keeps its entire state" % other_rank)
	for foe_id in trace["foes_before"]:
		_check(trace["foes_after"].get(foe_id) == trace["foes_before"].get(foe_id),
			"AC2: foe %s keeps its entire state through the needle" % foe_id)


func _test_picket_miss(seed_value: int, launch_rank: int, target_rank: int) -> void:
	var trace := _picket_trace(seed_value, launch_rank, target_rank)
	if trace.is_empty():
		_check(false, "AC2: the miss witness reaches Button Guard's turn")
		return
	var battle: StitchedRules = trace["battle"]
	var receipt: Dictionary = trace["receipt"]
	var results: Array = receipt.get("results", [])
	if results.size() != 1:
		_check(false, "AC2: the miss witness resolves one needle receipt")
		return
	var result: Dictionary = results[0]
	var target := _hero_at(battle, target_rank)
	var target_id := str(target.get("id", ""))
	var before: Dictionary = trace["heroes_before"].get(target_id, {})
	var after: Dictionary = trace["heroes_after"].get(target_id, {})
	var chance := _expected_chance(battle, trace["actor"], before,
		int(trace["actor"].get("miss_streak", 0)), 88)
	_check(int(result.get("hit_chance", -1)) == chance and result.has("roll")
		and not bool(result.get("hit", true))
		and int(result.get("roll", 0)) > chance,
		"AC2: the miss witness really rolls above the authored ACC 88 chance")
	_check(int(result.get("damage", -1)) == 0 and not bool(result.get("crit", true))
		and result.get("statuses", []).is_empty()
		and int(after.get("statuses", {}).get("mark", 0)) == 0
		and int(after.get("hp", -1)) == int(before.get("hp", -2)),
		"AC2: a missed needle deals no damage and Marks nobody")
	_check(after == before and _marks_of(trace["heroes_after"]).is_empty(),
		"AC2: no doll gains any status from a missed needle")


func _test_picket_max_damage(seed_value: int) -> void:
	for combo in COMBOS:
		var trace := _picket_trace(seed_value, int(combo[0]), int(combo[1]))
		if trace.is_empty():
			_check(false, "AC2: the upper-bound witness reaches Button Guard's turn")
			return
		var results: Array = trace["receipt"].get("results", [])
		if results.size() != 1:
			_check(false, "AC2: the upper-bound witness resolves one needle receipt")
			return
		_check(bool(results[0].get("hit", false)) and not bool(results[0].get("crit", true))
			and int(results[0].get("damage", -1)) == 3,
			"AC2: launch %d vs rank %d naturally witnesses the authored 3 damage bound"
				% [int(combo[0]), int(combo[1])])


# ---------------------------------------------------------------- AC3 the marked spear

## The genuine Button Guard rotation in rounds 1-2, an explicit round-3 Needle Picket at hero
## rank 2, then the round-4 Seam Punch projection and dispatch. With `extended`, the guard also
## spends rounds 4-6 without attacking and spears again in round 7 after the Mark has expired.
func _chain(seed_value: int, extended: bool = false) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	var history: Array = []
	if not _drive(battle, 3, GUARD, history):
		return {}
	var r3_intent := StitchedFoeIntent.choose(battle, battle.get_unit(GUARD))
	var picket := battle.use_foe_ability("needle_picket", 2)
	var picket_results: Array = picket.get("results", [])
	if picket_results.size() != 1:
		return {"battle": battle, "history": history, "picket": picket, "picket_results": picket_results}
	var mark_target := str(picket_results[0].get("target", ""))
	var mark_after_picket := int(battle.get_unit(mark_target).get("statuses", {}).get("mark", 0))
	if not _drive(battle, 4, GUARD, history):
		return {"battle": battle, "history": history, "picket": picket,
			"picket_results": picket_results, "mark_target": mark_target}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(GUARD))
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var journal := battle.turn_events()
	var again := StitchedFoeIntent.choose(battle, battle.get_unit(GUARD))
	var quiet := state == battle.state_snapshot() and rng == battle.rng_state() \
		and order == battle.turn_order() and journal == battle.turn_events() \
		and intent == again
	var actor := battle.get_unit(GUARD)
	var heroes_before := _hero_map(battle)
	var foes_before := _foe_map(battle)
	var mark_at_intent := int(battle.get_unit(mark_target).get("statuses", {}).get("mark", 0))
	var mark_ledger := _marks_of(heroes_before)
	var punch: Dictionary = {}
	var punch_rank := int(intent.get("target_rank", 0))
	var expired := {}
	if extended:
		# Spend the guard's rounds 4-6 without attacking, so the genuine round-3 Mark ticks out
		# and the authored rotation comes back to Seam Punch in round 7.
		for _round in [4, 5, 6]:
			if not _drive(battle, _round, GUARD, history):
				return {"battle": battle, "history": history, "picket": picket,
					"picket_results": picket_results, "mark_target": mark_target,
					"intent": intent, "quiet": quiet, "rounded": true}
			battle.pass_turn()
		if not _drive(battle, 7, GUARD, history):
			return {"battle": battle, "history": history, "picket": picket,
				"picket_results": picket_results, "mark_target": mark_target,
				"intent": intent, "quiet": quiet, "rounded": true}
		heroes_before = _hero_map(battle)
		foes_before = _foe_map(battle)
		actor = battle.get_unit(GUARD)
		mark_at_intent = int(battle.get_unit(mark_target).get("statuses", {}).get("mark", 0))
		mark_ledger = _marks_of(heroes_before)
		var later := StitchedFoeIntent.choose(battle, battle.get_unit(GUARD))
		punch_rank = int(later.get("target_rank", 0))
		expired = {
			"round": battle.round_number(),
			"ability_id": str(later.get("ability_id", "")),
			"target_rank": punch_rank,
			"seen": _norm(later),
		}
	punch = battle.use_foe_ability("seam_punch", punch_rank)
	return {
		"battle": battle,
		"history": history,
		"r3_intent": r3_intent,
		"picket": picket,
		"picket_results": picket_results,
		"mark_target": mark_target,
		"mark_after_picket": mark_after_picket,
		"intent": intent,
		"quiet": quiet,
		"mark_at_intent": mark_at_intent,
		"mark_ledger": mark_ledger,
		"actor": actor,
		"heroes_before": heroes_before,
		"foes_before": foes_before,
		"heroes_after": _hero_map(battle),
		"foes_after": _foe_map(battle),
		"punch": punch,
		"punch_rank": punch_rank,
		"expired": expired,
	}


func _scan_chains() -> Dictionary:
	var found := {"marked": -1, "no_mark": -1}
	for seed_value in range(1, CHAIN_LIMIT + 1):
		var chain := _chain(seed_value)
		if chain.is_empty() or not chain.has("punch"):
			continue
		var picket_results: Array = chain.get("picket_results", [])
		var results: Array = chain["punch"].get("results", [])
		if picket_results.size() != 1 or results.size() != 1:
			continue
		var picket_hit := bool(picket_results[0].get("hit", false))
		var result: Dictionary = results[0]
		if not bool(chain["punch"].get("ok", false)) or not bool(result.get("hit", false)) \
				or bool(result.get("crit", false)):
			continue
		var intent_id := str(chain["intent"].get("ability_id", ""))
		var intent_rank := int(chain["intent"].get("target_rank", 0))
		if picket_hit and int(chain["mark_at_intent"]) > 0 \
				and intent_id == "seam_punch" and intent_rank == 2 \
				and int(result.get("target_rank", 0)) == 2 and found["marked"] < 0:
			found["marked"] = seed_value
		if not picket_hit and intent_id == "seam_punch" and intent_rank == 1 \
				and int(result.get("target_rank", 0)) == 1 and found["no_mark"] < 0:
			found["no_mark"] = seed_value
		if int(found["marked"]) > 0 and int(found["no_mark"]) > 0:
			break
	_check(int(found["marked"]) > 0,
		"AC3: a seeded battle naturally witnesses a round-3 rank-2 Mark and a round-4 marked spear")
	_check(int(found["no_mark"]) > 0,
		"AC3: a seeded battle naturally witnesses an unmarked nearest-target fallback spear")
	return found


## The actual damage outcomes of one Seam Punch, computed with the shipped pipeline for every
## possible authored base roll. No hand-copied arithmetic.
func _punch_damages(battle: StitchedRules, actor: Dictionary, target: Dictionary,
		marked: bool) -> Array:
	var damages: Array = []
	for base in range(3, 6):
		var scaled := base
		if str(actor.get("side", "")) == "foe":
			scaled = StitchedS1BEffects.enemy_damage(base, battle.candle())
		var value := StitchedRules.damage_after_modifiers(
			scaled,
			actor.get("statuses", {}),
			target.get("statuses", {}),
			marked,
			int(_loaded_ability(battle.get_unit(GUARD), "seam_punch").get("mark_damage", 0)),
			int(target.get("prot", 0))
		)
		if not damages.has(value):
			damages.append(value)
	damages.sort()
	return damages


func _test_marked_punch(seed_value: int) -> void:
	var chain := _chain(seed_value)
	if chain.is_empty() or not chain.has("punch"):
		_check(false, "AC3: the marked witness reaches Button Guard's round-4 turn")
		return
	var battle: StitchedRules = chain["battle"]
	var picket_results: Array = chain["picket_results"]
	var target_id := str(chain["mark_target"])
	var target := _hero_at(battle, 2)
	_check(picket_results.size() == 1 and bool(picket_results[0].get("hit", false))
		and str(picket_results[0].get("target", "")) == str(target.get("id", ""))
		and picket_results[0].get("statuses", []) == [{"status": "mark", "duration": 3}]
		and int(chain["mark_after_picket"]) >= 1,
		"AC3: the round-3 Needle Picket really lands Mark 3 on the rank-2 doll")
	_check(str(chain["r3_intent"].get("ability_id", "")) == "needle_picket",
		"AC3: the genuine round-3 rotation announces Needle Picket before the chosen rank")
	_check(bool(chain["quiet"]),
		"AC3: repeated round-4 intent projection spends no state, turn, journal or RNG")
	var intent: Dictionary = chain["intent"]
	_check(str(intent.get("ability_id", "")) == "seam_punch"
		and str(intent.get("ability_name", "")) == "Seam Punch"
		and int(intent.get("target_rank", 0)) == 2
		and intent.get("affected_ranks", []) == [2]
		and int(intent.get("base_acc", -1)) == 86
		and intent.get("base_damage") == [3, 5]
		and int(intent.get("base_mark_damage", -1)) == 3
		and not bool(intent.get("pass", true)),
		"AC3: the live chooser aims the ACC-86 3-5 spear at the Marked rank 2 with +3")
	_check(int(chain["mark_at_intent"]) > 0 and int(chain["mark_at_intent"]) <= 3,
		"AC3: the Mark is still live at the guard's round-4 turn (clock ticks already applied)")
	var marks: Dictionary = chain["mark_ledger"]
	_check(marks.has(target_id) and not marks.has(str(_hero_at(battle, 1).get("id", ""))),
		"AC3: only the picketed rank 2 carries a Mark while rank 1 is unmarked")
	var results: Array = chain["punch"].get("results", [])
	if results.size() != 1:
		_check(false, "AC3: the marked spear resolves one target receipt")
		return
	var result: Dictionary = results[0]
	var before: Dictionary = chain["heroes_before"].get(target_id, {})
	var after: Dictionary = chain["heroes_after"].get(target_id, {})
	_check(str(chain["punch"].get("ability", "")) == "seam_punch"
		and int(result.get("target_rank", 0)) == 2 and str(result.get("target", "")) == target_id,
		"AC3: the dispatched spear bites the Marked rank-2 doll, not unmarked rank 1")
	var chance := _expected_chance(battle, chain["actor"], before,
		int(chain["actor"].get("miss_streak", 0)), 86)
	_check(int(result.get("hit_chance", -1)) == chance and result.has("roll")
		and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
		"AC3: the spear keeps its authored ACC 86 against that doll's real DODGE")
	_check(bool(result.get("hit", false)) and not bool(result.get("crit", true)),
		"AC3: the witness seed lands an uncritical marked spear")
	var marked_damages := _punch_damages(battle, chain["actor"], before, true)
	var unmarked_damages := _punch_damages(battle, chain["actor"], before, false)
	_check(marked_damages == [6, 7, 8] and unmarked_damages == [3, 4, 5],
		"AC3: the shipped pipeline adds +3 before PROT for the authored 3-5 base")
	_check(int(result.get("damage", -1)) >= 6 and int(result.get("damage", -1)) <= 8
		and marked_damages.has(int(result.get("damage", -1)))
		and not unmarked_damages.has(int(result.get("damage", -1))),
		"AC3: the rolled damage really includes the +3 Mark bonus")
	_check(int(after.get("hp", -1)) == int(before.get("hp", -2)) - int(result.get("damage", 0)),
		"AC3: the Marked doll's HP drops by exactly the bonused damage")
	var front := _hero_at(battle, 1)
	_check(chain["heroes_after"].get(str(front.get("id", "")))
		== chain["heroes_before"].get(str(front.get("id", ""))),
		"AC3: unmarked rank 1 is never struck by the marked spear")
	# The +3 is added before PROT, Weak/Exposed and Tangled, expressed through the real function.
	_check(StitchedRules.damage_after_modifiers(5, {}, {}, true, 3, 50) == 4
		and StitchedRules.damage_after_modifiers(5, {}, {}, false, 3, 50) == 3,
		"AC3: the Mark bonus is added before the attacker's PROT cut")
	_check(StitchedRules.damage_after_modifiers(3, {}, {"exposed": 1}, true, 3, 0) == 9
		and StitchedRules.damage_after_modifiers(3, {}, {"exposed": 1}, false, 3, 0) == 4,
		"AC3: the Mark bonus lands before Exposed's three-halves cut")
	_check(StitchedRules.damage_after_modifiers(3, {}, {"tangled": 1}, true, 3, 0) == 8,
		"AC3: the Mark bonus lands before Tangled's flat +2")


func _test_no_mark_fallback(seed_value: int) -> void:
	var chain := _chain(seed_value)
	if chain.is_empty() or not chain.has("punch"):
		_check(false, "AC3: the unmarked control reaches Button Guard's round-4 turn")
		return
	var battle: StitchedRules = chain["battle"]
	var picket_results: Array = chain["picket_results"]
	_check(picket_results.size() == 1 and not bool(picket_results[0].get("hit", true)),
		"AC3: the control's round-3 Needle Picket genuinely misses")
	_check(_marks_of(chain["heroes_before"]).is_empty(),
		"AC3: no doll carries a Mark in the unmarked control")
	var intent: Dictionary = chain["intent"]
	_check(str(intent.get("ability_id", "")) == "seam_punch"
		and int(intent.get("target_rank", 0)) == 1
		and intent.get("affected_ranks", []) == [1],
		"AC3: without a live Mark the spear falls back to the nearest legal rank 1")
	var results: Array = chain["punch"].get("results", [])
	if results.size() != 1:
		_check(false, "AC3: the unmarked control resolves one spear receipt")
		return
	var result: Dictionary = results[0]
	var front := _hero_at(battle, 1)
	var front_id := str(front.get("id", ""))
	var before: Dictionary = chain["heroes_before"].get(front_id, {})
	var unmarked_damages := _punch_damages(battle, chain["actor"], before, false)
	_check(int(result.get("target_rank", 0)) == 1 and str(result.get("target", "")) == front_id,
		"AC3: the fallback spear really strikes unmarked rank 1")
	_check(bool(result.get("hit", false)) and not bool(result.get("crit", true))
		and unmarked_damages.has(int(result.get("damage", -1))),
		"AC3: the unmarked spear deals only its authored 3-5, with no phantom +3")
	_check(int(chain["heroes_after"].get(front_id, {}).get("hp", -1))
		== int(before.get("hp", -2)) - int(result.get("damage", 0)),
		"AC3: the fallback doll's HP drops by exactly the unbonused damage")


func _test_expired_mark(seed_value: int) -> void:
	var chain := _chain(seed_value, true)
	if chain.is_empty() or not chain.has("punch") or not chain.has("expired"):
		_check(false, "AC3: the expired-Mark control reaches the later Button Guard turn")
		return
	var battle: StitchedRules = chain["battle"]
	var target_id := str(chain["mark_target"])
	_check(int(chain["mark_after_picket"]) >= 1 and int(chain["mark_at_intent"]) == 0,
		"AC3: the same genuine Mark has ticked out by the later spear turn")
	_check(_marks_of(chain["heroes_before"]).is_empty()
		and int(battle.get_unit(target_id).get("statuses", {}).get("mark", 0)) == 0,
		"AC3: no doll still carries the expired Mark")
	var expired: Dictionary = chain["expired"]
	_check(int(expired.get("round", 0)) == 7
		and str(expired.get("ability_id", "")) == "seam_punch"
		and int(expired.get("target_rank", 0)) == 1,
		"AC3: after expiry the live chooser falls back to the nearest legal rank 1 spear")
	var results: Array = chain["punch"].get("results", [])
	if results.size() != 1:
		_check(false, "AC3: the expired-Mark spear resolves one receipt")
		return
	var result: Dictionary = results[0]
	var before: Dictionary = chain["heroes_before"].get(str(result.get("target", "")), {})
	var unmarked_damages := _punch_damages(battle, chain["actor"], before, false)
	_check(bool(result.get("hit", false)) and not bool(result.get("crit", true))
		and int(result.get("damage", -1)) >= 3 and int(result.get("damage", -1)) <= 5
		and unmarked_damages.has(int(result.get("damage", -1))),
		"AC3: an expired Mark grants no phantom bonus on the real spear")


# ---------------------------------------------------------------- AC3 standard rotation

func _test_standard_rotation() -> void:
	var battle := _make_battle(ROTATION_SEED)
	if battle == null:
		return
	var actions: Array = []
	var thorns: Array = []
	for round_value in range(1, 5):
		if not _drive(battle, round_value, GUARD):
			_check(false, "AC3: the rotation battle reaches Button Guard's round %d turn"
				% round_value)
			return
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit(GUARD))
		actions.append(str(intent.get("ability_id", "")))
		var receipt := battle.use_foe_ability(str(intent.get("ability_id", "")),
			int(intent.get("target_rank", 0)))
		_check(bool(receipt.get("ok", false)),
			"AC3: round %d commits the projected Button Guard action" % round_value)
		if round_value == 2:
			var results: Array = receipt.get("results", [])
			_check(results.size() == 1 and bool(results[0].get("hit", false))
				and str(results[0].get("target", "")) == GUARD
				and results[0].get("statuses", []) == [{"status": "thorns", "duration": 2}],
				"AC3: round 2's Button Wall really shields the guard itself with Thorns 2")
		thorns.append(int(battle.get_unit(GUARD).get("statuses", {}).get("thorns", 0)))
	_check(actions == ["seam_punch", "button_wall", "needle_picket", "seam_punch"],
		"AC3: the authored three-action array rotates Seam Punch, Button Wall, Needle Picket, Seam Punch")
	_check(thorns.size() == 4 and thorns[0] == 0 and thorns[1] == 2 and thorns[2] == 1
		and thorns[3] == 0,
		"AC3: Button Wall's real self Thorns 2 applies and then ticks down one turn at a time")


# ---------------------------------------------------------------- AC4 seeded replay

func _test_replay(witnesses: Dictionary) -> void:
	var marked_seed := int(witnesses.get("marked", -1))
	if marked_seed <= 0:
		return
	var first := _chain(marked_seed)
	var second := _chain(marked_seed)
	_check(not first.is_empty() and first.has("punch") and second.has("punch"),
		"AC4: the marked chain reproduces on the same seed")
	if not first.has("punch") or not second.has("punch"):
		return
	_check(_norm(first["picket"]) == _norm(second["picket"])
		and _norm(first["punch"]) == _norm(second["punch"])
		and _norm(first["intent"]) == _norm(second["intent"])
		and first["battle"].state_snapshot() == second["battle"].state_snapshot()
		and first["battle"].rng_state() == second["battle"].rng_state()
		and first["battle"].turn_order() == second["battle"].turn_order(),
		"AC4: the same seed replays identical Needle Picket, spear receipts, state and RNG")
	var replay_seed := int(witnesses.get("hit", 2))
	var picket_first := _picket_trace(replay_seed, 1, 1)
	var picket_second := _picket_trace(replay_seed, 1, 1)
	_check(not picket_first.is_empty() and _norm(picket_first["receipt"])
		== _norm(picket_second["receipt"])
		and picket_first["battle"].state_snapshot() == picket_second["battle"].state_snapshot()
		and picket_first["battle"].rng_state() == picket_second["battle"].rng_state(),
		"AC4: a standalone needle trace replays identically on the same seed")
