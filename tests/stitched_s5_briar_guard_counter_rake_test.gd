extends SceneTree
## S5 Needle Briar Guard: the two-rank bleeding Briar Thrust and the counterstriking Briar Wall.
##
## One authored elite change, proven against the real source data, the canonical
## StitchedEnemyCatalog/StitchedParts rules and a genuine seeded four-doll fight. Hero PASS and
## legal foe actions advance real initiative until the Guard's own turn; the rake receipts and
## snapshots prove independent rank 1/2 resolution, hit-only Bleed 2 and an untouched back line.
## A second legal Guard turn casts the multi-ally wall, and a genuine equipped hero strike answers
## a buffed ally with Thorns then Riposte in the shipped order, while a matched unbuffed control
## and a natural miss answer with nothing. No status, receipt or RNG state is injected by hand.

const ELITES := "res://data/enemies/m04_elites.json"
const POOLS := "res://data/encounters/m03_typed_battle_pools.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const GUARD := "needle_briar_guard"
const THRUST := "briar_thrust"
const WALL := "briar_wall"
const THRUST_ACC := 86
const THORNS := 3
const RIPOSTE := 2
const BLEED := 2
const SEED_LIMIT := 48
const LAUNCH_LIMIT := 20
## The real Guard beside one or two real catalog allies that never move or buff the foe line.
const THREE_FOES := [GUARD, "scissor_bailiff", "spool_leech"]
const REAR_GUARD := ["scissor_bailiff", "spool_leech", GUARD]
const TWO_FOES := [GUARD, "scissor_bailiff"]
## The supplied shipped abilities, before the two named deltas.
const ORIGINAL_THRUST := {
	"id": "briar_thrust", "name": "Briar Thrust", "kind": "melee", "launch": [1, 3],
	"target": [1], "target_side": "enemy", "multi": false, "acc": 86, "dmg": [4, 5],
	"crit": 0, "effects": {"bleed": 2}, "self_move": 0, "move": "attack2",
}
const ORIGINAL_WALL := {
	"id": "briar_wall", "name": "Briar Wall", "kind": "buff", "launch": [1, 3],
	"target": [1, 2, 3, 4], "target_side": "ally", "multi": true, "acc": 100, "dmg": [0, 0],
	"crit": 0, "effects": {"thorns": 3}, "self_move": 0, "move": "guard",
}
const LEGACY_INTENT := {
	"target": "front",
	"actions": [
		{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
		{"type": "block", "amount": 8, "weight": 2},
		{"type": "attack", "amount": 9, "weight": 3},
		{"type": "attack", "amount": 8, "hits": 2, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
	],
}

var failures: Array[String] = []
var checks := 0
var _catalog: Dictionary = {}
var _preview: Dictionary = {}
var _thrust_seed := -1
var _rear_thrust_seed := -1
var _wall_hit_seed := -1
var _wall_miss_seed := -1


func _initialize() -> void:
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"the canonical enemy catalog loads: " + str(_catalog.get("error", "")))
	var preview: Variant = _read_json(PREVIEW)
	_preview = preview if preview is Dictionary else {}
	_check(_preview.get("heroes", []).size() == 4 and not _preview.get("parts", []).is_empty(),
		"the shipped S2 preview authors four dolls and their parts")
	if bool(_catalog.get("ok", false)) and not _preview.is_empty():
		_test_source_record()
		_test_thrust()
		_test_wall()
		_test_refusals()
		_test_replay()
	if failures.is_empty():
		print("stitched_s5_briar_guard_counter_rake_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_briar_guard_counter_rake_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Deep value normalization: JSON numbers back to ints so authored literals and parsed source
## compare by content, not by the int/float distinction Godot's nested container equality keeps.
func _canonical(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_canonical(item))
		return items
	if value is Dictionary:
		var fields: Dictionary = {}
		for key in value:
			fields[key] = _canonical(value[key])
		return fields
	return value


func _same(left: Variant, right: Variant) -> bool:
	return _canonical(left) == _canonical(right)


## A copy of one authored ability with exactly the passed delta fields replaced.
func _edited(original: Dictionary, deltas: Dictionary) -> Dictionary:
	var copy := original.duplicate(true)
	for key in deltas:
		var value: Variant = deltas[key]
		copy[key] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return copy


## Field names whose value differs between the shipped original and the live record.
func _delta_keys(original: Dictionary, actual: Dictionary) -> Array:
	var keys: Array = []
	for key in original:
		if not actual.has(key) or not _same(actual[key], original[key]):
			keys.append(key)
	for key in actual:
		if not original.has(key):
			keys.append(key)
	return keys


func _ability_of(abilities: Array, ability_id: String) -> Dictionary:
	for ability in abilities:
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _result_for(results: Array, target_id: String) -> Dictionary:
	for result in results:
		if str(result.get("target", "")) == target_id:
			return result
	return {}


# ---------------------------------------------------------------- fixtures

func _config(seed_value: int, foe_ids: Array, heroes: Array = []) -> Dictionary:
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var party: Array = heroes.duplicate(true) if not heroes.is_empty() else _preview["heroes"].duplicate(true)
	var foes: Array = []
	for foe_id in foe_ids:
		foes.append(StitchedEnemyCatalog.foe_for(_catalog, str(foe_id)))
	return {
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": party, "parts": parts, "foes": foes,
	}


func _make_battle(seed_value: int, foe_ids: Array, heroes: Array = []) -> Dictionary:
	for foe_id in foe_ids:
		if StitchedEnemyCatalog.foe_for(_catalog, str(foe_id)).is_empty():
			return {"ok": false, "error": "a foe is missing from the catalog: " + str(foe_id), "battle": null}
	return StitchedRules.create(_config(seed_value, foe_ids, heroes))


## One real turn: a hero PASS, otherwise the foe's own authoritative next legal action.
func _step(battle: StitchedRules) -> Dictionary:
	if battle.is_over():
		return {"ok": false, "error": "the battle is over"}
	if battle.current_side() == "hero":
		return battle.pass_turn()
	var actor := battle.get_unit(battle.current_actor_id())
	var intent := StitchedFoeIntent.choose(battle, actor)
	if intent.is_empty() or bool(intent.get("pass", true)):
		return battle.pass_turn()
	return battle.use_foe_ability(str(intent["ability_id"]), int(intent["target_rank"]))


## Real initiative until the Guard itself holds its turn in the requested round.
func _reach_guard(battle: StitchedRules, round_value: int) -> bool:
	for step in range(96):
		if battle.is_over() or battle.round_number() > round_value:
			return false
		if battle.round_number() == round_value and battle.current_actor_id() == GUARD:
			return true
		if not bool(_step(battle).get("ok", false)):
			return false
	return false


func _hero_units(battle: StitchedRules) -> Dictionary:
	var units: Dictionary = {}
	for hero in battle.get_heroes():
		units[str(hero["id"])] = hero.duplicate(true)
	return units


func _unit_copies(units: Array) -> Array:
	var copies: Array = []
	for unit in units:
		copies.append(unit.duplicate(true))
	return copies


## Every living doll stands at its own rank with no carried status, so the rake's damage and
## hit-only Bleed 2 are exact rather than absorbed by an earlier debuff.
func _clean_line(battle: StitchedRules) -> bool:
	var ranks: Array = []
	for hero in battle.get_heroes():
		if bool(hero.get("lost", false)) or int(hero.get("hp", 0)) <= 8 \
				or not hero.get("statuses", {}).is_empty():
			return false
		ranks.append(int(hero.get("rank", 0)))
	ranks.sort()
	return ranks == [1, 2, 3, 4] and battle.get_unit(GUARD).get("statuses", {}).is_empty()


## A carried LOST doll: no parts, zero HP, never an occupied rank.
func _lost(entry: Dictionary) -> Dictionary:
	var lost_entry := entry.duplicate(true)
	lost_entry["parts"] = {}
	lost_entry["hp"] = 0
	lost_entry["lost"] = true
	lost_entry.erase("statuses")
	lost_entry.erase("fray")
	lost_entry.erase("resolve")
	return lost_entry


# ---------------------------------------------------------------- AC1 the one authored elite

func _test_source_record() -> void:
	var records: Variant = _read_json(ELITES)
	_check(records is Array, "AC1: the real elite source array parses")
	if not records is Array:
		return
	var matches: Array = records.filter(func(record: Variant) -> bool:
		return record is Dictionary and str(record.get("id", "")) == GUARD)
	_check(matches.size() == 1, "AC1: exactly one authored Needle Briar Guard record")
	if matches.size() != 1:
		return
	var raw: Dictionary = matches[0]
	var expected := {
		"id": GUARD,
		"name": "Needle Briar Guard",
		"max_hp": 42,
		"thorns": 3,
		"art_path": "res://assets/paper/enemies/needle_briar_guard.png",
		"intent": LEGACY_INTENT,
		"stitched": {
			"max_hp": 42, "speed": 3, "dodge": 4, "acc": 0, "prot": 10, "is_boss": false,
			"turns_per_round": 1, "trophy": "needle_briar_guard_briar",
			"abilities": [
				_edited(ORIGINAL_THRUST, {"target": [1, 2], "multi": true}),
				_edited(ORIGINAL_WALL, {"effects": {"thorns": THORNS, "riposte": RIPOSTE}}),
			],
		},
	}
	_check(_same(raw, expected),
		"AC1: the whole authored record is the shipped identity plus only the two named deltas")
	var abilities: Array = raw.get("stitched", {}).get("abilities", [])
	_check(abilities.size() == 2, "AC1: the Guard still authors exactly its two abilities")
	var thrust := _ability_of(abilities, THRUST)
	var wall := _ability_of(abilities, WALL)
	_check(not thrust.is_empty() and not wall.is_empty(), "AC1: both named abilities are still authored")
	if thrust.is_empty() or wall.is_empty():
		return
	var thrust_deltas := _delta_keys(ORIGINAL_THRUST, thrust)
	var wall_deltas := _delta_keys(ORIGINAL_WALL, wall)
	_check(thrust_deltas == ["target", "multi"],
		"AC1: Briar Thrust changes only its target ranks and multi flag: " + str(thrust_deltas))
	_check(wall_deltas == ["effects"],
		"AC1: Briar Wall changes only its effects: " + str(wall_deltas))
	_check(_same(thrust, _edited(ORIGINAL_THRUST, {"target": [1, 2], "multi": true})),
		"AC1: every other Briar Thrust field keeps its shipped value")
	_check(_same(wall, _edited(ORIGINAL_WALL, {"effects": {"thorns": THORNS, "riposte": RIPOSTE}})),
		"AC1: every other Briar Wall field keeps its shipped value")
	_check(_same(thrust.get("launch"), [1, 3]) and thrust.get("target_side") == "enemy"
		and int(thrust.get("acc", 0)) == THRUST_ACC and _same(thrust.get("dmg"), [4, 5])
		and int(thrust.get("crit", -1)) == 0 and _same(thrust.get("effects"), {"bleed": BLEED})
		and int(thrust.get("self_move", -1)) == 0 and str(thrust.get("move", "")) == "attack2",
		"AC1: the rake keeps its launch ranks, 86 ACC, [4,5] damage, Bleed 2 and pose")
	_check(_same(wall.get("launch"), [1, 3]) and wall.get("target_side") == "ally"
		and wall.get("multi") == true and _same(wall.get("target"), [1, 2, 3, 4])
		and int(wall.get("acc", 0)) == 100 and _same(wall.get("dmg"), [0, 0])
		and int(wall.get("self_move", -1)) == 0 and str(wall.get("move", "")) == "guard",
		"AC1: the wall keeps its launch, all-ally target line, 100 ACC, zero damage and pose")
	# Independent StitchedParts validation, not just the catalog's own normalization.
	var thrust_valid: Variant = StitchedParts.validate_ability(thrust)
	_check(bool(thrust_valid.get("ok", false)), "AC1: the edited rake validates through StitchedParts")
	var normalized_thrust: Dictionary = thrust_valid.get("ability", {})
	_check(int(normalized_thrust.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(normalized_thrust.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
		and bool(normalized_thrust.get("multi", false)),
		"AC1: the validated rake launches from 1/3 and reaches only ranks 1-2")
	var wall_valid: Variant = StitchedParts.validate_ability(wall)
	_check(bool(wall_valid.get("ok", false)), "AC1: the edited wall validates through StitchedParts")
	var normalized_wall: Dictionary = wall_valid.get("ability", {})
	_check(int(normalized_wall.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(normalized_wall.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4])
		and bool(normalized_wall.get("multi", false))
		and normalized_wall.get("effects") == {"thorns": THORNS, "riposte": RIPOSTE},
		"AC1: the validated wall covers every ally rank with Thorns 3 and Riposte 2")
	# The real loader must publish exactly those two validated abilities.
	var foe := StitchedEnemyCatalog.foe_for(_catalog, GUARD)
	_check(not foe.is_empty(), "AC1: the real loader resolves the Needle Briar Guard")
	if foe.is_empty():
		return
	_check(_same(foe.get("abilities", []), [normalized_thrust, normalized_wall]),
		"AC1: the loader publishes exactly the authored rake and wall")
	_check(str(foe.get("name", "")) == "Needle Briar Guard" and int(foe.get("max_hp", 0)) == 42
		and int(foe.get("speed", -1)) == 3 and int(foe.get("dodge", -1)) == 4
		and int(foe.get("acc", -1)) == 0 and int(foe.get("prot", -1)) == 10
		and not bool(foe.get("is_boss", true)) and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the Guard keeps its shipped stitched stats and single turn")
	_check(str(_catalog.get("enemies", {}).get(GUARD, {}).get("tier", "")) == "elite"
		and StitchedEnemyCatalog.trophy_for(_catalog, GUARD) == "needle_briar_guard_briar",
		"AC1: the Guard keeps its elite tier and own foreign trophy")
	# Every neighbouring authored elite still resolves a valid kit (no total or ordered-list check).
	var neighbours := 0
	for record in records:
		if not record is Dictionary:
			continue
		var enemy_id := str(record.get("id", ""))
		if enemy_id == GUARD:
			continue
		neighbours += 1
		var other := StitchedEnemyCatalog.foe_for(_catalog, enemy_id)
		_check(not other.is_empty() and str(other.get("name", "")) == str(record.get("name", "")),
			"AC1: untouched elite still resolves: " + enemy_id)
		var valid := true
		for ability in other.get("abilities", []):
			valid = valid and bool(StitchedParts.validate_ability(ability).get("ok", false))
		_check(valid, "AC1: untouched elite keeps a valid authored kit: " + enemy_id)
	_check(neighbours >= 2, "AC1: non-vacuous neighbouring elite coverage beside the Guard")
	# The named authored encounter is unchanged and still names this Guard.
	var pools: Variant = _read_json(POOLS)
	var elite_pool: Variant = (pools.get("Elite", {}) if pools is Dictionary else null)
	_check(elite_pool is Dictionary and (elite_pool as Dictionary).has("briar_snare_elite"),
		"AC1: the named briar_snare_elite encounter still exists")
	if elite_pool is Dictionary and (elite_pool as Dictionary).has("briar_snare_elite"):
		var entry: Dictionary = elite_pool["briar_snare_elite"]
		_check(entry.get("enemy_ids") == [GUARD, "spool_snarekeeper"],
			"AC1: the authored encounter still pairs the Guard with the Spool Snarekeeper")
		_check(FileAccess.file_exists(str(entry.get("schedule", ""))),
			"AC1: the encounter schedule file still exists")


# ---------------------------------------------------------------- AC2 the two-rank rake

func _test_thrust() -> void:
	var hits := 0
	var misses := 0
	for seed_value in range(1, SEED_LIMIT + 1):
		var sample := _thrust_script(seed_value, THREE_FOES)
		if sample.is_empty():
			continue
		hits += int(sample["hits"])
		misses += int(sample["misses"])
		if _thrust_seed < 0 and int(sample["hits"]) > 0 and int(sample["misses"]) > 0:
			_thrust_seed = seed_value
	_check(hits > 0 and misses > 0,
		"AC2: a bounded seed sweep naturally witnesses landed and missed rake ranks")
	_check(_thrust_seed > 0,
		"AC2: one unmodified seed rakes rank 1 and 2 with an independent hit and miss")
	print("briar_thrust mixed witness seed=", _thrust_seed, " (", hits, " landed / ", misses, " missed ranks)")
	for seed_value in range(1, LAUNCH_LIMIT + 1):
		var rear := _thrust_script(seed_value, REAR_GUARD)
		if rear.is_empty():
			continue
		_check(int(rear["actor_rank"]) == 3,
			"AC2: the rear formation rakes from its legal launch rank 3")
		_rear_thrust_seed = seed_value
		break
	_check(_rear_thrust_seed > 0, "AC2: a real rank-3 Guard does use the two-rank rake")
	if _rear_thrust_seed > 0:
		print("briar_thrust rank-3 witness seed=", _rear_thrust_seed)


func _thrust_script(seed_value: int, foe_ids: Array) -> Dictionary:
	var created := _make_battle(seed_value, foe_ids)
	if not bool(created.get("ok", false)):
		return {}
	var battle: StitchedRules = created["battle"]
	if battle.get_heroes().size() != 4 or battle.get_foes().size() != foe_ids.size():
		return {}
	if not _reach_guard(battle, 1):
		return {}
	var actor := battle.get_unit(GUARD)
	var actor_rank := int(actor.get("rank", 0))
	if not actor_rank in [1, 3] or not _clean_line(battle):
		return {}
	if str(StitchedFoeIntent.choose(battle, actor).get("ability_id", "")) != THRUST:
		return {}
	var pre_units := _hero_units(battle)
	if pre_units.size() != 4:
		return {}
	var pre_state := battle.state_snapshot()
	var pre_rng := battle.rng_state()
	# Every illegal command is refused before any roll, state or turn change.
	for illegal in [
		[THRUST, 0, "no legal target in rank 0"],
		[THRUST, 5, "no legal target in rank 5"],
		[THRUST, 3, "no legal target in rank 3"],
		["not_an_authored_ability", 1, "the foe has no ability not_an_authored_ability"],
	]:
		var refused := battle.use_foe_ability(str(illegal[0]), int(illegal[1]))
		var refusal := refused as Dictionary
		_check(not bool(refusal.get("ok", true)) and str(refusal.get("error", "")) == str(illegal[2]),
			"AC2: refused rake command: " + str(illegal[2]))
	var hero_call := battle.use_part("warden_head_iron_helm", 1)
	_check(not bool(hero_call.get("ok", true)) and str(hero_call.get("error", "")) == "it is not a hero turn",
		"AC2: the Guard's own turn refuses a hero part command")
	_check(pre_state == battle.state_snapshot() and pre_rng == battle.rng_state(),
		"AC2: every refusal preserves complete state, the turn and the seeded RNG")
	var actor_before := battle.get_unit(GUARD)
	var receipt := battle.use_foe_ability(THRUST, 1)
	_check(bool(receipt.get("ok", false)) and str(receipt.get("actor", "")) == GUARD
		and str(receipt.get("ability", "")) == THRUST and str(receipt.get("actor_side", "")) == "foe",
		"AC2: the real Guard turn commits Briar Thrust")
	if not bool(receipt.get("ok", false)):
		return {}
	var results: Array = receipt.get("results", [])
	_check(results.size() == 2,
		"AC2: the rake returns exactly two receipts, one per occupied front rank")
	var ranks: Array = []
	var seen: Dictionary = {}
	var hits := 0
	var misses := 0
	var streak := int(actor_before.get("miss_streak", 0))
	var accuracy := THRUST_ACC + int(actor_before.get("acc", 0)) \
		+ int(battle.candle_band().get("enemy_acc", 0))
	for result in results:
		var target_id := str(result.get("target", ""))
		ranks.append(int(result.get("target_rank", 0)))
		if seen.has(target_id):
			_check(false, "AC2: no rank receives a duplicate rake receipt")
		seen[target_id] = true
		var before: Dictionary = pre_units.get(target_id, {})
		_check(not before.is_empty() and str(result.get("target_side", "")) == "hero"
			and int(result.get("target_rank", 0)) == int(before.get("rank", -1)),
			"AC2: each receipt names the real living doll in its own rank")
		if before.is_empty():
			continue
		var chance := StitchedRules.hit_chance(accuracy, StitchedRules.effective_dodge(before), streak)
		_check(int(result.get("hit_chance", -1)) == chance,
			"AC2: rank %d rolls the canonical 86-base-ACC chance" % int(before["rank"]))
		_check(bool(result.get("hit", false)) == (int(result.get("roll", -1)) <= chance),
			"AC2: rank %d's hit comes from its own seeded roll" % int(before["rank"]))
		streak = 0 if bool(result.get("hit", false)) else streak + 1
		if bool(result.get("hit", false)):
			hits += 1
			_check(result.get("statuses", []) == [{"status": "bleed", "duration": BLEED}],
				"AC2: a landed rank applies exactly Bleed 2")
			var protection := int(before.get("prot", 0))
			var damage := int(result.get("damage", -1))
			if bool(result.get("crit", false)):
				_check(damage == StitchedRules.damage_after_modifiers(
						StitchedRules.crit_damage(int(ORIGINAL_THRUST["dmg"][1])), {}, {}, false, 0, protection),
					"AC2: a critical rank deals the authored 1.5x rake maximum")
			else:
				_check(damage == StitchedRules.damage_after_modifiers(4, {}, {}, false, 0, protection)
					or damage == StitchedRules.damage_after_modifiers(5, {}, {}, false, 0, protection),
					"AC2: a normal landed rank deals the authored [4,5] base damage")
			_check(int(result.get("target_hp", -1)) == int(before.get("hp", -2)) - damage,
				"AC2: the receipt HP confirms the direct rake damage")
		else:
			misses += 1
			_check(result.get("statuses", []).is_empty() and int(result.get("damage", -1)) == 0
				and int(result.get("target_hp", -1)) == int(before.get("hp", -2)),
				"AC2: a missed rank takes no damage and no Bleed")
	ranks.sort()
	_check(ranks == [1, 2], "AC2: the rake covers exactly the two occupied front ranks")
	for target_id in seen:
		var struck := _result_for(results, str(target_id))
		var after := battle.get_unit(str(target_id))
		var ticked := battle.current_actor_id() == str(target_id)
		var landed := bool(struck.get("hit", false))
		var expected_bleed := maxi(0, (BLEED if landed else 0) - (1 if ticked else 0))
		var expected_hp := int(pre_units[target_id]["hp"]) - int(struck.get("damage", 0)) \
			- (BLEED if landed and ticked else 0)
		_check(int(after.get("hp", -1)) == expected_hp
			and int(after.get("statuses", {}).get("bleed", 0)) == expected_bleed,
			"AC2: the live struck rank keeps only the landed damage and its Bleed clock")
	for hero_id in pre_units:
		if seen.has(str(hero_id)):
			continue
		var before: Dictionary = pre_units[hero_id]
		_check(int(before.get("rank", 0)) in [3, 4], "AC2: the untouched dolls are the back ranks 3 and 4")
		_check(battle.get_unit(str(hero_id)) == before,
			"AC2: a back-line doll keeps its HP, rank and statuses, never a phantom target")
	_check(battle.get_foes().size() == foe_ids.size() and not receipt.has("self_move")
		and int(battle.get_unit(GUARD).get("rank", 0)) == actor_rank,
		"AC2: no phantom foe, no phantom caster movement and an unchanged foe line")
	return {
		"seed": seed_value, "actor_rank": actor_rank, "hits": hits, "misses": misses,
		"receipt": receipt, "state": battle.state_snapshot(), "rng": battle.rng_state(),
	}


# ---------------------------------------------------------------- AC3 the counterstriking wall

func _test_wall() -> void:
	for count in [3, 2]:
		var foe_ids: Array = THREE_FOES if count == 3 else TWO_FOES
		var witnessed := false
		var exact_line := false
		for seed_value in range(1, 49):
			var sample := _wall_script(seed_value, foe_ids, true)
			if sample.is_empty():
				continue
			witnessed = true
			exact_line = exact_line or bool(sample.get("full_line", false))
			if exact_line:
				break
		_check(witnessed, "AC3: a real %d-foe fight reaches a legal Briar Wall turn" % count)
		_check(exact_line,
			"AC3: a real %d-foe cast leaves every ally at exactly Thorns 3 and Riposte 2" % count)
	for seed_value in range(1, 41):
		var sample := _wall_script(seed_value, TWO_FOES, true)
		if sample.is_empty():
			continue
		if bool(sample["hit"]) and _wall_hit_seed < 0:
			_wall_hit_seed = seed_value
		elif not bool(sample["hit"]) and _wall_miss_seed < 0:
			_wall_miss_seed = seed_value
		if _wall_hit_seed > 0 and _wall_miss_seed > 0:
			break
	_check(_wall_hit_seed > 0, "AC3: bounded search finds a landed hero hit on a walled ally")
	_check(_wall_miss_seed > 0, "AC3: bounded search finds a genuine natural miss on a walled ally")
	for seed_value in [_wall_hit_seed, _wall_miss_seed]:
		if seed_value < 0:
			continue
		var protected := _wall_script(seed_value, TWO_FOES, true)
		var control := _wall_script(seed_value, TWO_FOES, false)
		_check(not control.is_empty() and bool(protected.get("hit")) == bool(control.get("hit"))
			and int(control.get("thorns", -1)) == 0 and int(control.get("riposte", -1)) == 0,
			"AC3: the matched seeded unbuffed control keeps the hit outcome without retaliation")
		print("briar_wall ", "hit" if bool(protected.get("hit")) else "miss", " witness seed=", seed_value)


func _wall_script(seed_value: int, foe_ids: Array, cast_wall: bool) -> Dictionary:
	var created := _make_battle(seed_value, foe_ids)
	if not bool(created.get("ok", false)):
		return {}
	var battle: StitchedRules = created["battle"]
	if not _reach_guard(battle, 2):
		return {}
	var actor := battle.get_unit(GUARD)
	if int(actor.get("rank", 0)) != 1:
		return {}
	if str(StitchedFoeIntent.choose(battle, actor).get("ability_id", "")) != WALL:
		return {}
	var foes_before := _unit_copies(battle.get_foes())
	var heroes_before := _unit_copies(battle.get_heroes())
	if foes_before.size() != foe_ids.size():
		return {}
	for foe in foes_before:
		if bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0 \
				or not foe.get("statuses", {}).is_empty():
			return {}
	var pre_state := battle.state_snapshot()
	var pre_rng := battle.rng_state()
	for rank in [0, 5]:
		var refused := battle.use_foe_ability(WALL, rank)
		_check(not bool(refused.get("ok", true))
			and str(refused.get("error", "")) == "no legal target in rank %d" % rank,
			"AC3: an out-of-line wall rank is refused")
	var unknown := battle.use_foe_ability("not_an_authored_ability", 1)
	_check(not bool(unknown.get("ok", true))
		and str(unknown.get("error", "")) == "the foe has no ability not_an_authored_ability",
		"AC3: an unknown wall command is refused")
	var hero_call := battle.use_part("warden_head_iron_helm", 1)
	_check(not bool(hero_call.get("ok", true)) and str(hero_call.get("error", "")) == "it is not a hero turn",
		"AC3: the Guard's turn refuses a hero command")
	_check(pre_state == battle.state_snapshot() and pre_rng == battle.rng_state(),
		"AC3: refused wall commands preserve complete state and the seeded RNG")
	var wall_cast := battle.use_foe_ability(WALL, 4) if cast_wall else battle.pass_turn()
	_check(bool(wall_cast.get("ok", false)), "AC3: the real round-2 Guard action commits")
	var full_line := false
	if cast_wall:
		full_line = true
		var results: Array = wall_cast.get("results", [])
		_check(str(wall_cast.get("ability", "")) == WALL and str(wall_cast.get("actor", "")) == GUARD
			and results.size() == foes_before.size(),
			"AC3: the wall returns exactly one receipt per living occupied ally")
		var seen: Dictionary = {}
		for result in results:
			var target_id := str(result.get("target", ""))
			if seen.has(target_id):
				_check(false, "AC3: no ally receives a duplicate wall receipt")
			seen[target_id] = true
			_check(str(result.get("target_side", "")) == "foe"
				and int(result.get("target_rank", 0)) >= 1
				and int(result.get("target_rank", 0)) <= foes_before.size()
				and bool(result.get("hit", false)) and not bool(result.get("crit", true))
				and int(result.get("damage", -1)) == 0
				and result.get("statuses", []) == [
					{"status": "thorns", "duration": THORNS},
					{"status": "riposte", "duration": RIPOSTE}],
				"AC3: each ally receives a no-damage Thorns 3 and Riposte 2 receipt")
		for foe in foes_before:
			var foe_id := str(foe.get("id", ""))
			var now := battle.get_unit(foe_id)
			var tick := 1 if battle.current_actor_id() == foe_id else 0
			_check(seen.has(foe_id) and int(now.get("hp", -1)) == int(foe.get("hp", -2))
				and int(now.get("rank", 0)) == int(foe.get("rank", -1))
				and not bool(now.get("dead", true)),
				"AC3: the wall never damages or moves a named ally")
			_check(int(now.get("statuses", {}).get("thorns", 0)) == THORNS - tick
				and int(now.get("statuses", {}).get("riposte", 0)) == RIPOSTE - tick,
				"AC3: each ally keeps Thorns 3 and Riposte 2 less only its own turn tick")
			full_line = full_line and int(now.get("statuses", {}).get("thorns", 0)) == THORNS \
				and int(now.get("statuses", {}).get("riposte", 0)) == RIPOSTE
		_check(battle.get_foes().size() == foes_before.size() and battle.get_heroes().size() == 4,
			"AC3: the wall keeps exactly the living allied line and no phantom fourth foe")
		for hero in heroes_before:
			var hero_id := str(hero.get("id", ""))
			var now := battle.get_unit(hero_id)
			var ticked := battle.current_actor_id() == hero_id
			var bleed := int(hero.get("statuses", {}).get("bleed", 0))
			_check(int(now.get("rank", 0)) == int(hero.get("rank", -1))
				and bool(now.get("lost", true)) == bool(hero.get("lost", false))
				and int(now.get("hp", -1)) == int(hero.get("hp", -2)) - (bleed if ticked else 0),
				"AC3: the wall changes no hero rank or HP beyond a real Bleed tick")
			_check(int(now.get("statuses", {}).get("thorns", 0))
					== int(hero.get("statuses", {}).get("thorns", 0)),
				"AC3: the ally-side wall never leaks a counterstatus onto the hero line")
		_check(battle.get_foes().size() == foe_ids.size() and not wall_cast.has("self_move"),
			"AC3: no phantom fourth foe and no caster movement")
	# Real public turns reach the Warden's equipped strike.
	for step in range(24):
		if battle.current_actor_id() == "warden":
			break
		var passed := battle.pass_turn()
		_check(bool(passed.get("ok", false)), "AC3: public turns reach the real hero strike")
	if battle.current_actor_id() != "warden":
		return {}
	var attacker := battle.get_unit("warden")
	var target := battle.get_unit(GUARD)
	var thorns := int(target.get("statuses", {}).get("thorns", 0))
	var riposte := int(target.get("statuses", {}).get("riposte", 0))
	if cast_wall:
		_check(thorns > 0 and riposte > 0,
			"AC3: the struck walled ally still carries live Thorns and Riposte")
	else:
		_check(thorns == 0 and riposte == 0, "AC3: the matched control ally carries no reactions")
	_check(int(attacker.get("rank", 0)) == 1 and int(attacker.get("hp", 0)) > thorns + riposte
		and int(target.get("hp", 0)) > 0 and not bool(target.get("dead", true)),
		"AC3: a healthy armed attacker faces a living protected ally")
	var attack := battle.use_part("warden_head_iron_helm", 1)
	_check(bool(attack.get("ok", false)) and attack.get("results", []).size() == 1,
		"AC3: the genuine equipped hero strike resolves exactly one attack")
	if not bool(attack.get("ok", false)) or attack.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = attack.get("results", [])[0]
	var after := battle.get_unit("warden")
	var foe_after := battle.get_unit(GUARD)
	_check(str(hit.get("target", "")) == GUARD
		and bool(hit.get("hit", false)) == (int(hit.get("roll", -1)) <= int(hit.get("hit_chance", 0)))
		and int(foe_after.get("hp", 0)) > 0 and not bool(foe_after.get("dead", true)),
		"AC3: the seeded hero strike naturally hits or misses a surviving ally")
	if bool(hit.get("hit", false)):
		_check(int(hit.get("damage", 0)) > 0
			and int(foe_after.get("hp", -1)) == int(target.get("hp", -2)) - int(hit.get("damage", 0)),
			"AC3: a landed hero strike really damages the ally")
		if cast_wall:
			_check(int(hit.get("thorns", -1)) == thorns and int(hit.get("riposte", -1)) == riposte
				and hit.keys().find("thorns") < hit.keys().find("riposte")
				and int(after.get("hp", -1)) == int(attacker.get("hp", -2)) - thorns - riposte,
				"AC3: the confirmed hit answers with Thorns then Riposte in the shipped order")
		else:
			_check(not hit.has("thorns") and not hit.has("riposte")
				and int(after.get("hp", -1)) == int(attacker.get("hp", -1)),
				"AC3: the matched unbuffed control hit answers with nothing")
	else:
		_check(not hit.has("thorns") and not hit.has("riposte") and int(hit.get("damage", -1)) == 0
			and int(foe_after.get("hp", -1)) == int(target.get("hp", -2))
			and int(after.get("hp", -1)) == int(attacker.get("hp", -1)),
			"AC3: a natural miss answers with no reaction and no HP change")
	return {
		"seed": seed_value, "cast": cast_wall, "hit": bool(hit.get("hit", false)),
		"thorns": thorns, "riposte": riposte, "full_line": full_line,
		"wall": wall_cast, "attack": attack,
		"state": battle.state_snapshot(), "rng": battle.rng_state(),
	}


# ---------------------------------------------------------------- AC2/AC4 fail-closed cases

func _test_refusals() -> void:
	# A Guard standing in rank 2 cannot launch either authored ability.
	var created := _make_battle(3, ["scissor_bailiff", GUARD])
	_check(bool(created.get("ok", false)), "AC2: the rank-2 Guard fixture builds from the real catalog")
	if bool(created.get("ok", false)):
		var battle: StitchedRules = created["battle"]
		if _reach_guard(battle, 1):
			var guard := battle.get_unit(GUARD)
			_check(int(guard.get("rank", 0)) == 2,
				"AC2: the fixture really puts the Guard in the illegal launch rank 2")
			var before := battle.state_snapshot()
			var before_rng := battle.rng_state()
			var rake := battle.use_foe_ability(THRUST, 1)
			_check(not bool(rake.get("ok", true))
				and str(rake.get("error", "")) == "ability cannot launch from rank 2",
				"AC2: the rake refuses an illegal launch rank")
			var wall := battle.use_foe_ability(WALL, 1)
			_check(not bool(wall.get("ok", true))
				and str(wall.get("error", "")) == "ability cannot launch from rank 2",
				"AC3: the wall refuses the same illegal launch rank")
			_check(before == battle.state_snapshot() and before_rng == battle.rng_state(),
				"AC2/AC3: illegal launch refusals spend no state, turn or RNG")
		else:
			_check(false, "AC2: the rank-2 fixture reaches a real Guard turn")
	# An empty front line leaves the two-rank rake no legal target at all.
	var party: Array = _preview["heroes"].duplicate(true)
	party[0] = _lost(party[0])
	party[1] = _lost(party[1])
	var empty := _make_battle(5, TWO_FOES, party)
	_check(bool(empty.get("ok", false)), "AC2: the lost-front-line fixture builds from the real preview")
	if bool(empty.get("ok", false)):
		var battle: StitchedRules = empty["battle"]
		_check(bool(battle.get_unit(str(party[0]["id"])).get("lost", false))
			and bool(battle.get_unit(str(party[1]["id"])).get("lost", false)),
			"AC2: the two front dolls are really lost before the rake")
		if _reach_guard(battle, 1):
			var before := battle.state_snapshot()
			var before_rng := battle.rng_state()
			var front := battle.use_foe_ability(THRUST, 1)
			_check(not bool(front.get("ok", true))
				and str(front.get("error", "")) == "no legal target in rank 1",
				"AC2: an empty front rank is refused, never a phantom target")
			var second := battle.use_foe_ability(THRUST, 2)
			_check(not bool(second.get("ok", true))
				and str(second.get("error", "")) == "no legal target in rank 2",
				"AC2: an empty second rank is refused too")
			_check(before == battle.state_snapshot() and before_rng == battle.rng_state(),
				"AC2: empty-rank refusals spend no state, turn or RNG")
		else:
			_check(false, "AC2: the empty-front fixture reaches a real Guard turn")


# ---------------------------------------------------------------- AC2/AC3 seeded replay

func _test_replay() -> void:
	if _thrust_seed < 0:
		_check(false, "AC2: a rake witness seed exists for the replay")
	else:
		var first := _thrust_script(_thrust_seed, THREE_FOES)
		var again := _thrust_script(_thrust_seed, THREE_FOES)
		_check(not first.is_empty() and first == again,
			"AC2: the fixed rake seed replays identical receipts, snapshots, statuses and RNG")
	if _rear_thrust_seed < 0:
		_check(false, "AC2: a rear-rank rake witness seed exists for the replay")
	else:
		var first := _thrust_script(_rear_thrust_seed, REAR_GUARD)
		var again := _thrust_script(_rear_thrust_seed, REAR_GUARD)
		_check(not first.is_empty() and first == again,
			"AC2: the fixed rank-3 rake seed replays identically")
	for seed_value in [_wall_hit_seed, _wall_miss_seed]:
		if seed_value < 0:
			continue
		var first := _wall_script(seed_value, TWO_FOES, true)
		var again := _wall_script(seed_value, TWO_FOES, true)
		_check(not first.is_empty() and first == again,
			"AC3: the fixed wall seed replays identical receipts, snapshots and RNG")
