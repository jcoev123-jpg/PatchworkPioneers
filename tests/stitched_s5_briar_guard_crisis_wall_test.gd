extends SceneTree
## S5 Needle Briar Guard: a wounded unprotected escort makes the elite raise its own
## authored Briar Wall before the ordinary round rotation.
##
## The source record, the canonical StitchedEnemyCatalog/StitchedParts normalization and
## the seeded StitchedRules battle are the only authorities. Legal-rank projection fixtures
## set HP explicitly; the live witness drives real hero passes/strikes and public foe turns,
## then commits the projected action through battle.use_foe_ability. Nothing here edits a
## receipt, invents a status or draws from an unseeded RNG.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const GUARD := "needle_briar_guard"
const ESCORT := "scissor_bailiff"
const THRUST := "briar_thrust"
const WALL := "briar_wall"
const THRUST_ACC := 86
const THORNS := 3
const RIPOSTE := 2
const BLEED := 2
const SEED_LIMIT := 96
const FOES := [GUARD, ESCORT, "zipper_hauler"]
const REAR_FOES := [ESCORT, "zipper_hauler", GUARD]
const INTENT_KEYS := [
	"foe_id", "foe_name", "ability_id", "ability_name", "ability_kind", "target_rank",
	"target_side", "affected_ranks", "multi", "pass", "stun", "base_acc", "base_damage",
	"base_crit", "base_mark_damage", "base_effects",
]
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
var recording := true
var _catalog: Dictionary = {}
var _preview: Dictionary = {}
var _hit_seed := -1
var _miss_seed := -1


func _initialize() -> void:
	var raw: Variant = _read_json(ELITES)
	_check(raw is Array, "AC1: the real elite source array parses")
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"AC1: the canonical enemy catalog loads: " + str(_catalog.get("error", "")))
	var parsed: Variant = _read_json(PREVIEW)
	_check(parsed is Dictionary, "the shipped four-doll preview parses")
	if not raw is Array or not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_check(_preview.get("heroes", []).size() == 4 and not _preview.get("parts", []).is_empty(),
		"the shipped S2 preview authors four dolls and their parts")
	_test_source(raw)
	_test_projection()
	_test_fallbacks()
	_test_live_wall()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_briar_guard_crisis_wall_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> bool:
	if recording:
		checks += 1
		if not condition:
			failures.append(message)
	return condition


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


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


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _edited(original: Dictionary, deltas: Dictionary) -> Dictionary:
	var copy := original.duplicate(true)
	for key in deltas:
		var value: Variant = deltas[key]
		copy[key] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return copy


func _ability_of(abilities: Array, ability_id: String) -> Dictionary:
	for ability in abilities:
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


# ---------------------------------------------------------------- AC1 authored Guard

func _test_source(raw: Array) -> void:
	var matches: Array = raw.filter(func(record: Variant) -> bool:
		return record is Dictionary and str(record.get("id", "")) == GUARD)
	_check(matches.size() == 1, "AC1: exactly one authored Needle Briar Guard record")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
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
	_check(_same(record, expected),
		"AC1: the whole authored record is exactly the shipped identity with both named abilities")
	_check(ResourceLoader.exists("res://assets/paper/enemies/needle_briar_guard.png"),
		"AC1: the existing Guard art carries the wall (no new asset)")
	var abilities: Array = record.get("stitched", {}).get("abilities", [])
	var ids: Array = []
	for ability in abilities:
		ids.append(str(ability.get("id", "")))
	_check(ids == [THRUST, WALL], "AC1: both authored abilities keep their order")
	var thrust := _ability_of(abilities, THRUST)
	var wall := _ability_of(abilities, WALL)
	_check(not thrust.is_empty() and not wall.is_empty(),
		"AC1: the named rake and wall are still authored")
	if thrust.is_empty() or wall.is_empty():
		return
	_check(_same(thrust, _edited(ORIGINAL_THRUST, {"target": [1, 2], "multi": true})),
		"AC1: Briar Thrust keeps ACC 86, [4,5] damage, Bleed 2 and its two-rank multi target")
	_check(_same(wall, _edited(ORIGINAL_WALL, {"effects": {"thorns": THORNS, "riposte": RIPOSTE}})),
		"AC1: Briar Wall keeps ACC 100, zero damage, all-ally target and Thorns 3 / Riposte 2")
	var validated_thrust: Variant = StitchedParts.validate_ability(thrust)
	var validated_wall: Variant = StitchedParts.validate_ability(wall)
	_check(bool(validated_thrust.get("ok", false)) and bool(validated_wall.get("ok", false)),
		"AC1: both authored abilities validate through StitchedParts")
	if not bool(validated_thrust.get("ok", false)) or not bool(validated_wall.get("ok", false)):
		return
	var normalized_thrust: Dictionary = validated_thrust["ability"]
	var normalized_wall: Dictionary = validated_wall["ability"]
	_check(int(normalized_thrust.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(normalized_thrust.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
		and bool(normalized_thrust.get("multi", false)),
		"AC1: the rake launches from 1/3 and reaches only ranks 1-2")
	_check(int(normalized_wall.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(normalized_wall.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4])
		and bool(normalized_wall.get("multi", false))
		and normalized_wall.get("effects") == {"thorns": THORNS, "riposte": RIPOSTE},
		"AC1: the wall launches from 1/3, covers every ally rank and carries Thorns 3 / Riposte 2")
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
		"AC1: the Guard keeps its shipped 42-HP SPEED-3 DODGE-4 PROT-10 single-turn profile")
	_check(str(_catalog.get("enemies", {}).get(GUARD, {}).get("tier", "")) == "elite"
		and StitchedEnemyCatalog.trophy_for(_catalog, GUARD) == "needle_briar_guard_briar",
		"AC1: the Guard keeps its elite tier and own foreign trophy")
	# Shared catalog growth must not break this lane: named IDs only, never a total.
	for required in [GUARD, ESCORT, "zipper_hauler", "spool_hexer", "needle_marshal",
			"spool_snarekeeper", "scissor_crab", "pincushion_matriarch", "spool_leech"]:
		_check(_catalog.get("foes", {}).has(required),
			"AC1: named canonical foe still resolves: " + required)


# ---------------------------------------------------------------- fixtures

func _fixture(ids: Array, seed_value: int) -> StitchedRules:
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id))
		if foe.is_empty():
			_check(false, "fixture: canonical foe exists: " + str(enemy_id))
			return null
		foes.append(foe)
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": _preview["heroes"].duplicate(true), "parts": parts, "foes": foes,
	})
	_check(bool(built.get("ok", false)),
		"fixture: the real seeded battle builds: " + str(built.get("error", "")))
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size(),
		"fixture: four dolls face the %d real catalog foes" % ids.size())
	return battle


func _set_hp(battle: StitchedRules, unit_id: String, hp: int) -> void:
	battle._units[unit_id]["hp"] = hp


func _set_statuses(battle: StitchedRules, unit_id: String, statuses: Dictionary) -> void:
	battle._units[unit_id]["statuses"] = statuses.duplicate(true)


## The ordinary round-rotated first legal authored ability, computed independently from the
## canonical live kit and the same public legality authority the chooser uses.
func _rotation_id(battle: StitchedRules, actor: Dictionary) -> String:
	var authored: Array = actor.get("abilities", [])
	if authored.is_empty():
		return ""
	var offset := (battle.round_number() - 1) % authored.size()
	for step in range(authored.size()):
		var ability: Dictionary = authored[(offset + step) % authored.size()]
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor.get("rank", 0))):
			continue
		if not battle._self_move_gate(actor, ability).is_empty():
			continue
		for rank in range(1, 5):
			if not battle._legal_targets(actor, ability, rank).is_empty():
				return str(ability.get("id", ""))
	return ""


func _assert_rotation(battle: StitchedRules, expected: String, note: String) -> Dictionary:
	var actor := battle.get_unit(GUARD)
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, actor)
	_check(_rotation_id(battle, actor) == expected,
		note + ": the independent rotation really selects " + expected)
	_check(str(intent.get("ability_id", "")) == expected,
		note + ": the chooser keeps the ordinary rotation")
	_check(snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		note + ": the projection spends no state, turn or RNG")
	return intent


func _assert_wall(battle: StitchedRules, note: String) -> Dictionary:
	var actor := battle.get_unit(GUARD)
	_check(int(actor.get("rank", 0)) in [1, 3],
		note + ": the authoritative Guard stands in a legal launch rank")
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, actor)
	_check(snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		note + ": the emergency projection never mutates the battle or draws RNG")
	_check(str(intent.get("ability_id", "")) == WALL
		and str(intent.get("ability_name", "")) == "Briar Wall"
		and str(intent.get("ability_kind", "")) == "buff"
		and str(intent.get("target_side", "")) == "foe"
		and bool(intent.get("multi", false))
		and not bool(intent.get("pass", true)),
		note + ": the chooser preempts the rotation with the authored allied Briar Wall")
	_check(int(intent.get("target_rank", 0)) == 1
		and intent.get("affected_ranks") == [1, 2, 3],
		note + ": the wall casts from the lowest legal rank over every living ally rank")
	_check(int(intent.get("base_acc", -1)) == 100
		and intent.get("base_damage") == [0, 0]
		and int(intent.get("base_crit", -1)) == 0
		and int(intent.get("base_mark_damage", -1)) == 0
		and _same(intent.get("base_effects"), {"thorns": THORNS, "riposte": RIPOSTE}),
		note + ": the projection exposes only the authored zero-damage Thorns 3 / Riposte 2 numbers")
	var shape := intent.keys().size() == INTENT_KEYS.size()
	for key in INTENT_KEYS:
		shape = shape and intent.has(key)
	_check(shape, note + ": the intent keeps the exact existing schema and adds no priority field")
	var detached := intent.duplicate(true)
	detached["base_effects"]["thorns"] = 99
	detached["affected_ranks"].append(4)
	_check(StitchedFoeIntent.choose(battle, battle.get_unit(GUARD)) == intent
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		note + ": editing a detached projection cannot edit the live kit or battle")
	return intent


# ---------------------------------------------------------------- AC2 emergency projection

func _test_projection() -> void:
	# Rank 1: exactly half and just below half both qualify.
	var half := _fixture(FOES, 11)
	if half != null:
		half._round = 1
		_set_hp(half, ESCORT, 18)
		_check(2 * 18 == int(half.get_unit(ESCORT)["max_hp"]),
			"AC2 fixture: the rank-1 escort is at exactly half of its maximum")
		_assert_wall(half, "AC2: a rank-1 Guard walls an escort at exactly half HP")
	var below := _fixture(FOES, 12)
	if below != null:
		below._round = 1
		_set_hp(below, ESCORT, 17)
		_check(2 * 17 < int(below.get_unit(ESCORT)["max_hp"]),
			"AC2 fixture: the rank-1 escort is just below half")
		_assert_wall(below, "AC2: a rank-1 Guard walls an escort just below half HP")
	# Rank 3: the other authored launch rank still preempts round-one Briar Thrust.
	var rear_half := _fixture(REAR_FOES, 13)
	if rear_half != null:
		rear_half._round = 1
		_set_hp(rear_half, ESCORT, 18)
		_check(int(rear_half.get_unit(GUARD)["rank"]) == 3,
			"AC2 fixture: the rear formation really puts the Guard in rank 3")
		_assert_wall(rear_half, "AC2: a rank-3 Guard walls an escort at exactly half HP")
	var rear_below := _fixture(REAR_FOES, 14)
	if rear_below != null:
		rear_below._round = 1
		_set_hp(rear_below, ESCORT, 17)
		_assert_wall(rear_below, "AC2: a rank-3 Guard walls an escort just below half HP")
	# One missing temporary counterstatus still qualifies; both present do not.
	var thorns_only := _fixture(FOES, 15)
	if thorns_only != null:
		thorns_only._round = 1
		_set_hp(thorns_only, ESCORT, 18)
		_set_statuses(thorns_only, ESCORT, {"thorns": 2})
		_check(StitchedFoeIntent._is_unprotected_wounded_escort(
			thorns_only.get_unit(ESCORT)), "AC2 fixture: temporary Thorns alone still lacks Riposte")
		_assert_wall(thorns_only, "AC2: a wounded escort with only temporary Thorns still triggers")
	var riposte_only := _fixture(FOES, 16)
	if riposte_only != null:
		riposte_only._round = 1
		_set_hp(riposte_only, ESCORT, 18)
		_set_statuses(riposte_only, ESCORT, {"riposte": 1})
		_check(StitchedFoeIntent._is_unprotected_wounded_escort(
			riposte_only.get_unit(ESCORT)), "AC2 fixture: temporary Riposte alone still lacks Thorns")
		_assert_wall(riposte_only, "AC2: a wounded escort with only temporary Riposte still triggers")
	var protected := _fixture(FOES, 17)
	if protected != null:
		protected._round = 1
		_set_hp(protected, ESCORT, 18)
		_set_statuses(protected, ESCORT, {"thorns": 1, "riposte": 1})
		_check(not StitchedFoeIntent._is_unprotected_wounded_escort(
			protected.get_unit(ESCORT)), "AC2 fixture: both temporary counterstatuses are active")
		_assert_rotation(protected, THRUST,
			"AC2: an already fully wall-protected wounded escort restores the ordinary rotation")
	# The half-HP comparator itself: one point above half never triggers.
	var above := _fixture(FOES, 18)
	if above != null:
		above._round = 1
		_set_hp(above, ESCORT, 19)
		_check(not StitchedFoeIntent._is_unprotected_wounded_escort(
			above.get_unit(ESCORT)), "AC2 fixture: 19 HP is one point above half of 36")
		_assert_rotation(above, THRUST,
			"AC2: an escort just above half HP never triggers the emergency wall")


# ---------------------------------------------------------------- AC4 fail-closed negatives

func _test_fallbacks() -> void:
	# Healthy escorts and only the Guard itself hurt keep round one on Briar Thrust.
	var healthy := _fixture(FOES, 21)
	if healthy != null:
		healthy._round = 1
		_assert_rotation(healthy, THRUST,
			"AC4: every escort healthy keeps the ordinary first-round Briar Thrust")
		var self_hurt := _fixture(FOES, 22)
		if self_hurt != null:
			self_hurt._round = 1
			_set_hp(self_hurt, GUARD, 5)
			_check(int(self_hurt.get_unit(GUARD)["hp"]) * 2 <= int(self_hurt.get_unit(GUARD)["max_hp"]),
				"AC4 fixture: the Guard itself is critically wounded")
			_assert_rotation(self_hurt, THRUST,
				"AC4: only the Guard being hurt never triggers its own protective wall")
	# Healthy first rotation, wall second rotation: no cooldown is invented.
	var rotation := _fixture(FOES, 23)
	if rotation != null:
		rotation._round = 1
		_assert_rotation(rotation, THRUST, "AC4: round one still rotates to Briar Thrust")
		rotation._round = 2
		_assert_rotation(rotation, WALL, "AC4: round two still rotates to Briar Wall")
	# Dead, zero-HP, LOST and scrap-heap escorts are never candidates.
	var dead := _fixture(FOES, 24)
	if dead != null:
		dead._round = 1
		_set_hp(dead, ESCORT, 0)
		dead._units[ESCORT]["dead"] = true
		dead._heaps.append({"id": "heap:test", "side": "heap", "rank": 2,
			"hp": 5, "max_hp": 5, "foe_id": ESCORT})
		var actor := dead.get_unit(GUARD)
		var wall := _ability_of(actor["abilities"], WALL)
		var legal: Array = dead._legal_targets(actor, wall, 1)
		var heap_seen := false
		for target in legal:
			heap_seen = heap_seen or str(target.get("side", "")) == "heap"
		_check(heap_seen, "AC4 fixture: the scrap heap is returned by ordinary ally legality")
		_assert_rotation(dead, THRUST,
			"AC4: a scrap heap never satisfies the emergency escort rule")
	var zero := _fixture(FOES, 25)
	if zero != null:
		zero._round = 1
		_set_hp(zero, ESCORT, 0)
		_assert_rotation(zero, THRUST,
			"AC4: a zero-HP non-dead/absent foe never satisfies the emergency")
	var absent := _fixture(FOES, 34)
	if absent != null:
		absent._round = 1
		absent._units.erase(ESCORT)
		_check(absent.get_foes().size() == 2,
			"AC4 fixture: the absent foe really leaves the ally line")
		_assert_rotation(absent, THRUST,
			"AC4: an absent foe never satisfies the emergency")
	var lost := _fixture(FOES, 26)
	if lost != null:
		lost._round = 1
		_set_hp(lost, ESCORT, 18)
		lost._units[ESCORT]["lost"] = true
		var lost_legal: Array = lost._legal_targets(lost.get_unit(GUARD),
			_ability_of(lost.get_unit(GUARD)["abilities"], WALL), 1)
		var lost_escort_seen := false
		for target in lost_legal:
			lost_escort_seen = lost_escort_seen or str(target.get("id", "")) == ESCORT
		_check(lost_escort_seen, "AC4 fixture: the LOST foe is still returned by ordinary legality")
		_assert_rotation(lost, THRUST,
			"AC4: a LOST escort never satisfies the emergency")
	var hero_side := _fixture(FOES, 27)
	if hero_side != null:
		hero_side._round = 1
		var front: Dictionary = hero_side.get_heroes()[0]
		hero_side._units[str(front["id"])]["hp"] = 1
		_check(not StitchedFoeIntent._is_unprotected_wounded_escort(front),
			"AC4 fixture: the wounded hero record is not an escort")
		_assert_rotation(hero_side, THRUST,
			"AC4: a wounded hero never satisfies the foe-side escort rule")
	# Ranks outside the authored launch mask never gain a sudden wall.
	var rank_two := _fixture([ESCORT, GUARD, "zipper_hauler"], 28)
	if rank_two != null:
		rank_two._round = 1
		_set_hp(rank_two, ESCORT, 18)
		_check(int(rank_two.get_unit(GUARD)["rank"]) == 2,
			"AC4 fixture: the authentic rank-2 Guard formation is real")
		var snapshot := rank_two.state_snapshot()
		var rng := rank_two.rng_state()
		var intent := StitchedFoeIntent.choose(rank_two, rank_two.get_unit(GUARD))
		_check(str(intent.get("ability_id", "")) != WALL and bool(intent.get("pass", false))
			and snapshot == rank_two.state_snapshot() and rng == rank_two.rng_state(),
			"AC4: a rank-2 Guard can never suddenly use the wall")
		var reached := false
		for step in range(160):
			if rank_two.is_over():
				break
			if rank_two.current_actor_id() == GUARD:
				reached = true
				break
			if not bool(rank_two.pass_turn().get("ok", false)):
				break
		_check(reached, "AC4 fixture: the authentic rank-2 Guard reaches its own turn")
		if reached:
			var before_cast := rank_two.state_snapshot()
			var before_rng := rank_two.rng_state()
			var refused := rank_two.use_foe_ability(WALL, 1)
			_check(not bool(refused.get("ok", true))
				and str(refused.get("error", "")) == "ability cannot launch from rank 2"
				and before_cast == rank_two.state_snapshot() and before_rng == rank_two.rng_state(),
				"AC4: the direct rank-2 wall is refused without state or RNG spend")
	var rank_four := _fixture(FOES, 29)
	if rank_four != null:
		rank_four._round = 1
		_set_hp(rank_four, ESCORT, 18)
		rank_four._units[GUARD]["rank"] = 4
		_check(StitchedParts.ranks_allowed(
			int(_ability_of(rank_four.get_unit(GUARD)["abilities"], WALL)["launch_mask"]), 4) == false,
			"AC4 fixture: rank 4 is outside the wall's authored launch ranks")
		_assert_rotation(rank_four, "",
			"AC4: a rank-4 Guard passes instead of fabricating a wall")
	# Stun, detached actors and a finished battle propose nothing at all.
	var stunned := _fixture(FOES, 30)
	if stunned != null:
		stunned._round = 1
		_set_hp(stunned, ESCORT, 18)
		_set_statuses(stunned, GUARD, {"stun": 1})
		var snapshot := stunned.state_snapshot()
		var rng := stunned.rng_state()
		var intent := StitchedFoeIntent.choose(stunned, stunned.get_unit(GUARD))
		_check(bool(intent.get("stun", false)) and str(intent.get("ability_id", "")) == ""
			and int(intent.get("target_rank", -1)) == 0
			and not intent.has("base_damage") and not intent.has("base_effects")
			and snapshot == stunned.state_snapshot() and rng == stunned.rng_state(),
			"AC4: a stunned Guard reports STUN with no fabricated wall")
	var invalid := _fixture(FOES, 31)
	if invalid != null:
		invalid._round = 1
		_set_hp(invalid, ESCORT, 18)
		var snapshot := invalid.state_snapshot()
		var rng := invalid.rng_state()
		_check(StitchedFoeIntent.choose(invalid, {}).is_empty()
			and StitchedFoeIntent.choose(invalid, {"id": "not_a_real_foe"}).is_empty()
			and StitchedFoeIntent.choose(invalid, invalid.get_unit("warden")).is_empty()
			and snapshot == invalid.state_snapshot() and rng == invalid.rng_state(),
			"AC4: empty, unknown and hero-side actors get no fabricated wall")
	var ended := _fixture(FOES, 32)
	if ended != null:
		ended._round = 1
		_set_hp(ended, ESCORT, 18)
		ended._outcome = "victory"
		var snapshot := ended.state_snapshot()
		var rng := ended.rng_state()
		_check(ended.is_over() and StitchedFoeIntent.choose(ended, ended.get_unit(GUARD)).is_empty()
			and snapshot == ended.state_snapshot() and rng == ended.rng_state(),
			"AC4: an ended battle proposes no emergency wall")
	# Another foe keeps its exact intent beside the Guard's emergency.
	var mixed := _fixture([GUARD, ESCORT, "spool_hexer"], 33)
	var control := _fixture([GUARD, ESCORT, "spool_hexer"], 33)
	if mixed != null and control != null:
		mixed._round = 1
		control._round = 1
		_set_hp(mixed, ESCORT, 18)
		var guard_intent := StitchedFoeIntent.choose(mixed, mixed.get_unit(GUARD))
		var hexer := StitchedFoeIntent.choose(mixed, mixed.get_unit("spool_hexer"))
		var unchanged := StitchedFoeIntent.choose(control, control.get_unit("spool_hexer"))
		_check(str(guard_intent.get("ability_id", "")) == WALL,
			"AC4: the Guard still raises its emergency wall in mixed company")
		_check(hexer == unchanged and str(hexer.get("ability_id", "")) == "thread_tag"
			and int(hexer.get("target_rank", 0)) == 1,
			"AC4: the Spool Hexer keeps its own unchanged authored intent")


# ---------------------------------------------------------------- AC3 live seeded wall

func _test_live_wall() -> void:
	recording = false
	for seed_value in range(1, SEED_LIMIT + 1):
		var sample := _live_script(seed_value)
		if sample.is_empty():
			continue
		if bool(sample.get("hit", false)) and _hit_seed < 0:
			_hit_seed = seed_value
		elif not bool(sample.get("hit", false)) and _miss_seed < 0:
			_miss_seed = seed_value
		if _hit_seed > 0 and _miss_seed > 0:
			break
	recording = true
	_check(_hit_seed > 0, "AC3: a bounded seed search finds a confirmed hit on a walled ally")
	_check(_miss_seed > 0, "AC3: a bounded seed search finds a genuine natural miss on a walled ally")
	for seed_value in [_hit_seed, _miss_seed]:
		if seed_value < 0:
			continue
		var first := _live_script(seed_value)
		_check(not first.is_empty(), "AC3: the recorded seeded wall script completes")
		if first.is_empty():
			continue
		recording = false
		var replay := _live_script(seed_value)
		recording = true
		_check(not replay.is_empty() and _json(first) == _json(replay),
			"AC3: the same seed and legal action script replay receipts, HP, snapshots and RNG")
		print("briar_wall ", "hit" if bool(first.get("hit", false)) else "miss",
			" witness seed=", seed_value)


## One real hero part attack on a named foe at its own rank. {} when no worn part can
## legally fire.
func _strike_foe(battle: StitchedRules, hero: Dictionary, foe_id: String) -> Dictionary:
	var foe := battle.get_unit(foe_id)
	if foe.is_empty() or bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0:
		return {}
	var foe_rank := int(foe.get("rank", 0))
	for slot in StitchedParts.SLOTS:
		var equipped: Dictionary = hero.get("parts", {}).get(slot, {})
		if equipped.is_empty() or bool(equipped.get("torn", false)):
			continue
		if not battle._parts.has(str(equipped.get("id", ""))):
			continue
		var ability := StitchedParts.ability_at_tier(
			battle._parts[str(equipped["id"])], int(equipped.get("tier", 1)))
		if ability.is_empty() or str(ability.get("target_side", "")) != "enemy" \
				or int(ability.get("dmg", [0, 0])[1]) <= 0:
			continue
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(hero.get("rank", 0))):
			continue
		if not StitchedParts.ranks_allowed(int(ability["target_mask"]), foe_rank):
			continue
		if not battle._self_move_gate(hero, ability).is_empty():
			continue
		var receipt := battle.use_part(str(equipped["id"]), foe_rank)
		if bool(receipt.get("ok", false)):
			return receipt
	return {}


## The current hero's genuine equipped strike on one named foe, if a worn part can legally
## reach its real rank.
func _strike_guard(battle: StitchedRules, target_id: String) -> Dictionary:
	var hero := battle.get_unit(battle.current_actor_id())
	if str(hero.get("side", "")) != "hero":
		return {}
	return _strike_foe(battle, hero, target_id)


func _is_wounded(unit: Dictionary) -> bool:
	if unit.is_empty() or str(unit.get("side", "")) != "foe":
		return false
	if bool(unit.get("dead", false)) or bool(unit.get("lost", false)):
		return false
	var hp := int(unit.get("hp", 0))
	var maximum := int(unit.get("max_hp", 0))
	return hp > 0 and maximum > 0 and 2 * hp <= maximum


## Real passes until the Guard's own round-one turn. {} when the first round is already past.
func _to_guard_round_one(battle: StitchedRules, receipts: Array) -> bool:
	for step in range(160):
		if battle.is_over() or battle.round_number() > 1:
			return false
		if battle.current_actor_id() == GUARD:
			return battle.round_number() == 1
		var passed := battle.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			return false
	return false


## One complete seeded script: an explicit half-HP escort, the real round-one Guard turn,
## the emergency projection, the committed wall receipt and then a genuine hero strike that
## witnesses either the live Thorns/Riposte answers or a natural miss with none.
func _live_script(seed_value: int) -> Dictionary:
	var battle := _fixture(REAR_FOES, seed_value)
	if battle == null:
		return {}
	var opening := battle.get_foes()
	if opening.size() != 3 or int(battle.get_unit(GUARD).get("rank", 0)) != 3:
		return {}
	for foe in opening:
		if str(foe.get("id", "")) == GUARD:
			continue
		_check(int(foe.get("hp", 0)) == int(foe.get("max_hp", 0))
			and not bool(foe.get("dead", true)),
			"AC3 precondition: the escort line starts alive at full health")
	var escort_max := int(battle.get_unit(ESCORT).get("max_hp", 0))
	_set_hp(battle, ESCORT, escort_max / 2)
	_check(2 * int(battle.get_unit(ESCORT).get("hp", 0)) == escort_max,
		"AC3 precondition: the live escort fixture stands exactly at half HP")
	var receipts: Array = []
	if not _to_guard_round_one(battle, receipts):
		return {}
	var guard := battle.get_unit(GUARD)
	var escort := battle.get_unit(ESCORT)
	if not _is_wounded(escort) or int(guard.get("rank", 0)) != 3:
		return {}
	if _rotation_id(battle, guard) != THRUST:
		return {}
	var foes_before := battle.get_foes().duplicate(true)
	for foe in foes_before:
		if bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0 \
				or not foe.get("statuses", {}).is_empty():
			return {}
	var heroes_before := battle.get_heroes().duplicate(true)
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, guard)
	_check(snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: the live emergency projection consumes no state, turn or RNG")
	_check(str(intent.get("ability_id", "")) == WALL
		and str(intent.get("ability_name", "")) == "Briar Wall"
		and str(intent.get("ability_kind", "")) == "buff"
		and str(intent.get("target_side", "")) == "foe"
		and bool(intent.get("multi", false)) and not bool(intent.get("pass", true))
		and intent.get("affected_ranks") == [1, 2, 3]
		and int(intent.get("target_rank", 0)) == 1
		and int(intent.get("base_acc", -1)) == 100
		and intent.get("base_damage") == [0, 0]
		and _same(intent.get("base_effects"), {"thorns": THORNS, "riposte": RIPOSTE}),
		"AC3: the authentic wounded escort preempts the thrust with the real Briar Wall")
	if str(intent.get("ability_id", "")) != WALL:
		return {}
	var wall_cast := battle.use_foe_ability(str(intent["ability_id"]), int(intent["target_rank"]))
	receipts.append(wall_cast)
	if not _check(bool(wall_cast.get("ok", false)) and str(wall_cast.get("actor", "")) == GUARD
		and str(wall_cast.get("ability", "")) == WALL
		and wall_cast.get("results", []).size() == 3,
		"AC3: the selected real foe action commits the wall once for every living ally"):
		return {}
	_check(battle.is_over() or battle.current_actor_id() != GUARD,
		"AC3: the emergency wall spends exactly the Guard's one turn")
	var seen: Dictionary = {}
	for result in wall_cast.get("results", []):
		var target_id := str(result.get("target", ""))
		if seen.has(target_id):
			_check(false, "AC3: no ally receives a duplicate wall receipt")
		seen[target_id] = true
		_check(str(result.get("target_side", "")) == "foe"
			and bool(result.get("hit", false)) and not bool(result.get("crit", true))
			and int(result.get("damage", -1)) == 0
			and result.get("statuses", []) == [
				{"status": "thorns", "duration": THORNS},
				{"status": "riposte", "duration": RIPOSTE}],
			"AC3: each living ally receives a confirmed zero-damage Thorns 3 / Riposte 2 receipt")
	for old in foes_before:
		var foe_id := str(old.get("id", ""))
		var now := battle.get_unit(foe_id)
		var tick := 1 if battle.current_actor_id() == foe_id else 0
		_check(seen.has(foe_id) and int(now.get("hp", -1)) == int(old.get("hp", -2))
			and int(now.get("rank", 0)) == int(old.get("rank", -1))
			and not bool(now.get("dead", true)),
			"AC3: the wall never damages or moves " + foe_id)
		_check(int(now.get("statuses", {}).get("thorns", 0)) == THORNS - tick
			and int(now.get("statuses", {}).get("riposte", 0)) == RIPOSTE - tick,
			"AC3: " + foe_id + " keeps real Thorns/Riposte less only its own turn tick")
	var heroes_after := battle.get_heroes()
	_check(heroes_after == heroes_before,
		"AC3: the allied wall never changes a hero's HP, rank or statuses")
	for hero in heroes_after:
		_check(int(hero.get("statuses", {}).get("thorns", 0)) == 0
			and int(hero.get("statuses", {}).get("riposte", 0)) == 0
			and hero.get("dodge_buff", {}).is_empty(),
			"AC3: no hero receives the wall's counterstatuses: " + str(hero.get("id", "")))
	_check(battle.get_foes().size() == 3 and not wall_cast.has("self_move"),
		"AC3: no phantom foe and no caster movement")
	# A genuine equipped hero strike on the walled Guard, from whichever living hero and
	# worn part can legally reach its real rank.
	var attacker: Dictionary = {}
	var target: Dictionary = {}
	var thorns := 0
	var riposte := 0
	var attack: Dictionary = {}
	for step in range(96):
		if battle.is_over():
			return {}
		if battle.current_side() == "hero":
			var candidate := battle.get_unit(battle.current_actor_id())
			var guarded := battle.get_unit(GUARD)
			if int(guarded.get("statuses", {}).get("thorns", 0)) > 0 \
					and int(guarded.get("statuses", {}).get("riposte", 0)) > 0 \
					and int(guarded.get("hp", 0)) > 0 and not bool(guarded.get("dead", true)):
				var attempt := _strike_guard(battle, GUARD)
				if not attempt.is_empty():
					attacker = candidate
					target = guarded
					thorns = int(guarded.get("statuses", {}).get("thorns", 0))
					riposte = int(guarded.get("statuses", {}).get("riposte", 0))
					attack = attempt
					break
		var passed := battle.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			return {}
	if attack.is_empty() or attacker.is_empty() or target.is_empty():
		return {}
	receipts.append(attack)
	if not _check(bool(attack.get("ok", false)) and attack.get("results", []).size() == 1,
		"AC3: the genuine equipped hero strike resolves exactly once"):
		return {}
	var hit: Dictionary = attack.get("results", [])[0]
	var after := battle.get_unit(str(attack.get("actor", "")))
	var foe_after := battle.get_unit(GUARD)
	if not _check(str(hit.get("target", "")) == GUARD
		and bool(hit.get("hit", false)) == (int(hit.get("roll", -1)) <= int(hit.get("hit_chance", 0)))
		and int(foe_after.get("hp", 0)) > 0 and not bool(foe_after.get("dead", true)),
		"AC3: the seeded hero strike naturally hits or misses a surviving Guard"):
		return {}
	if bool(hit.get("hit", false)):
		_check(int(hit.get("damage", 0)) > 0
			and int(foe_after.get("hp", -1)) == int(target.get("hp", -2)) - int(hit.get("damage", 0)),
			"AC3: a landed hero strike really damages the walled Guard")
		_check(int(hit.get("thorns", -1)) == thorns and int(hit.get("riposte", -1)) == riposte
			and hit.keys().find("thorns") < hit.keys().find("riposte")
			and int(after.get("hp", -1)) == int(attacker.get("hp", -2)) - thorns - riposte,
			"AC3: the confirmed hit answers with the pre-existing Thorns then Riposte")
	else:
		_check(not hit.has("thorns") and not hit.has("riposte")
			and int(hit.get("damage", -1)) == 0
			and int(foe_after.get("hp", -1)) == int(target.get("hp", -2))
			and int(after.get("hp", -1)) == int(attacker.get("hp", -1)),
			"AC3: a natural miss answers with no reaction and no HP change")
	return {
		"seed": seed_value,
		"round": battle.round_number(),
		"intent": intent,
		"wall": wall_cast,
		"attack": attack,
		"hit": bool(hit.get("hit", false)),
		"thorns": thorns,
		"riposte": riposte,
		"receipts": receipts.duplicate(true),
		"state": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"heroes": battle.get_heroes().duplicate(true),
		"foes": battle.get_foes().duplicate(true),
	}
