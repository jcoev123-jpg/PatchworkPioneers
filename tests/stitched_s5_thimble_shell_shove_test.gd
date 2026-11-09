extends SceneTree
## S5 Thimble Beetle: a wounded beetle shelters behind its heavy shell, then hurls its
## protected bulk into a legal doll and shoves that doll one rank along the thread.
##
## The shipped record, the canonical StitchedEnemyCatalog/StitchedParts normalisation and
## the seeded StitchedRules battle are the only authorities. Fixtures set HP on the live
## unit dictionary (never on a detached get_unit copy). The live witness reaches a real
## beetle turn, commits the projected Shell Up and Shell Shove through the public
## battle.use_foe_ability, and the mounted witness drives the actual battle screen path.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const POSES := "res://data/art/move_poses.json"
const BEETLE := "thimble_beetle"
const HEDGEHOG := "pincushion_hedgehog"
const CRAB := "scissor_crab"
const RAM := "thimble_ram"
const SHELL_UP := "shell_up"
const SHOVE := "shell_shove"
const THORNS := 3
const FRAY := 3
const SEED_LIMIT := 48
const FOES := [BEETLE, HEDGEHOG]
const SHELTER_RANK := 1
const LEGACY_INTENT := {
	"target": "front",
	"actions": [
		{"type": "block", "amount": 9, "weight": 3},
		{"type": "attack", "amount": 5, "weight": 2},
		{"type": "attack", "amount": 7, "move": "attack2", "weight": 1},
	],
}
const ORIGINAL_RAM := {
	"id": "thimble_ram", "name": "Thimble Ram", "kind": "melee", "launch": [1, 2],
	"target": [1], "target_side": "enemy", "multi": false, "acc": 84, "dmg": [3, 4],
	"crit": 0, "effects": {}, "self_move": 0, "move": "attack2",
}
const ORIGINAL_SHELL_UP := {
	"id": "shell_up", "name": "Shell Up", "kind": "buff", "launch": [1, 2],
	"target": [1], "target_side": "self", "multi": false, "acc": 100, "dmg": [0, 0],
	"crit": 0, "effects": {"thorns": THORNS}, "self_move": 0, "move": "skill",
}
const SHELL_SHOVE := {
	"id": "shell_shove", "name": "Shell Shove", "kind": "melee", "launch": [1, 2],
	"target": [1, 2], "target_side": "enemy", "multi": false, "acc": 85, "dmg": [4, 6],
	"crit": 0, "effects": {"push": 1, "fray": FRAY}, "self_move": 0, "move": "attack2",
}

var failures: Array[String] = []
var checks := 0
var recording := true
var _catalog: Dictionary = {}
var _preview: Dictionary = {}
var _hit_seed := -1
var _miss_seed := -1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var raw: Variant = _read_json(RUN)
	_check(raw is Array, "AC1: the real run_enemies source array parses")
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"AC1: the canonical enemy catalog loads: " + str(_catalog.get("error", "")))
	var parsed: Variant = _read_json(PREVIEW)
	_check(parsed is Dictionary, "AC1: the shipped four-doll preview parses")
	if not raw is Array or not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_check(_preview.get("heroes", []).size() == 4 and not _preview.get("parts", []).is_empty(),
		"AC1: the S2 preview authors four dolls and their parts")
	_test_source(raw)
	_test_poses()
	_test_projection()
	_test_fallbacks()
	_test_refusals()
	_test_live()
	await _test_live_screen()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_thimble_shell_shove_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
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


## JSON parses every number as a float; normalise an authored literal the same way.
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


func _record(raw: Array, enemy_id: String) -> Dictionary:
	var matches: Array = raw.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == enemy_id)
	_check(matches.size() == 1, "AC1: exactly one canonical record for " + enemy_id)
	return matches[0] if matches.size() == 1 else {}


func _ability(record: Dictionary, ability_id: String) -> Dictionary:
	var abilities: Array = record.get("stitched", {}).get("abilities", [])
	var matches: Array = abilities.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == ability_id)
	_check(matches.size() == 1, "AC1: exactly one authored action " + ability_id)
	return matches[0] if matches.size() == 1 else {}


## The ordinary round-rotated first legal authored ability, computed independently from
## the canonical live kit and the same public legality authority the chooser uses.
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


# ---------------------------------------------------------------- AC1 authored record

func _test_source(raw: Array) -> void:
	var record := _record(raw, BEETLE)
	if record.is_empty():
		return
	_check(str(record.get("name", "")) == "Thimble Beetle"
		and int(record.get("max_hp", 0)) == 29
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/thimble_beetle.png",
		"AC1: the canonical beetle keeps its name, 29 legacy HP and existing art")
	var legacy: Dictionary = record.get("intent", {})
	_check(str(legacy.get("target", "")) == "front"
		and _same(legacy.get("actions"), LEGACY_INTENT["actions"]),
		"AC1: the original weighted front intent is unchanged")
	var profile: Dictionary = record.get("stitched", {})
	_check(int(profile.get("max_hp", 0)) == 29 and int(profile.get("speed", -1)) == 2
		and int(profile.get("dodge", -1)) == 2 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 10 and profile.get("is_boss") == false
		and int(profile.get("turns_per_round", 0)) == 1
		and profile.get("trophy") == "thimble_beetle_shell",
		"AC1: the S5 profile keeps 29 HP, SPEED 2, DODGE 2, ACC 0, PROT 10, one turn and its trophy")
	var ids: Array = []
	for ability in profile.get("abilities", []):
		ids.append(str(ability.get("id", "")))
	_check(ids == [RAM, SHELL_UP, SHOVE],
		"AC1: the first two actions keep their original order and Shell Shove is appended third")
	_check(_same(_ability(record, RAM), ORIGINAL_RAM),
		"AC1: Thimble Ram keeps ACC 84, [3,4] damage, target rank 1 and its attack2 pose")
	_check(_same(_ability(record, SHELL_UP), ORIGINAL_SHELL_UP),
		"AC1: Shell Up keeps ACC 100, zero damage, self target and Thorns 3")
	_check(_same(_ability(record, SHOVE), SHELL_SHOVE),
		"AC1: Shell Shove is the exact authored melee [1,2]->[1,2] move with Push 1 and Fray 3")
	for pair in [[RAM, ORIGINAL_RAM], [SHELL_UP, ORIGINAL_SHELL_UP], [SHOVE, SHELL_SHOVE]]:
		var validated := StitchedParts.validate_ability(pair[1])
		_check(bool(validated.get("ok", false)),
			"AC1: " + str(pair[0]) + " validates through StitchedParts")
	var normalized := StitchedParts.validate_ability(SHELL_SHOVE)
	if bool(normalized.get("ok", false)):
		var shove: Dictionary = normalized["ability"]
		_check(int(shove.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(shove.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and str(shove.get("kind", "")) == "melee"
			and int(shove.get("acc", -1)) == 85
			and shove.get("dmg") == [4, 6]
			and int(shove.get("crit", -1)) == 0
			and shove.get("effects") == {"push": 1, "fray": FRAY}
			and int(shove.get("self_move", -1)) == 0
			and str(shove.get("move", "")) == "attack2"
			and not bool(shove.get("multi", true)),
			"AC1: the normalised Shell Shove owns its exact ranks, numbers, effects and pose")
	# Malformed samples must refuse rather than become a live action.
	var bad_rank := SHELL_SHOVE.duplicate(true)
	bad_rank["launch"] = [0]
	_check(not bool(StitchedParts.validate_ability(bad_rank).get("ok", true)),
		"AC1: an off-grid launch rank fails closed")
	var bad_target := SHELL_SHOVE.duplicate(true)
	bad_target["target"] = [1, 5]
	_check(not bool(StitchedParts.validate_ability(bad_target).get("ok", true)),
		"AC1: an off-grid target rank fails closed")
	var bad_push := SHELL_SHOVE.duplicate(true)
	bad_push["effects"] = {"push": 2, "fray": FRAY}
	_check(not bool(StitchedParts.validate_ability(bad_push).get("ok", true)),
		"AC1: a two-step Push effect fails closed")
	var bad_fray := SHELL_SHOVE.duplicate(true)
	bad_fray["effects"] = {"push": 1, "fray": 0}
	_check(not bool(StitchedParts.validate_ability(bad_fray).get("ok", true)),
		"AC1: a zero Fray effect fails closed")
	var bad_key := SHELL_SHOVE.duplicate(true)
	bad_key["effects"] = {"push": 1, "fray": FRAY, "shelter": 1}
	_check(not bool(StitchedParts.validate_ability(bad_key).get("ok", true)),
		"AC1: an unknown effect key fails closed")
	# The real loader publishes the same three normalised actions for the named foe.
	var foe := StitchedEnemyCatalog.foe_for(_catalog, BEETLE)
	_check(not foe.is_empty() and str(foe.get("name", "")) == "Thimble Beetle"
		and int(foe.get("max_hp", 0)) == 29 and int(foe.get("speed", -1)) == 2
		and int(foe.get("dodge", -1)) == 2 and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 10 and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the real loader resolves the unchanged beetle profile")
	_check(str(_catalog.get("enemies", {}).get(BEETLE, {}).get("tier", "")) == "normal"
		and StitchedEnemyCatalog.trophy_for(_catalog, BEETLE) == "thimble_beetle_shell",
		"AC1: the beetle stays a normal foe with its own trophy")
	var kit: Array = foe.get("abilities", [])
	_check(kit.size() == 3, "AC1: the loader publishes exactly the Ram, Shell Up and Shell Shove")
	for pair in [[RAM, ORIGINAL_RAM], [SHELL_UP, ORIGINAL_SHELL_UP], [SHOVE, SHELL_SHOVE]]:
		var validated := StitchedParts.validate_ability(pair[1])
		var matches: Array = kit.filter(func(ability: Dictionary) -> bool:
			return str(ability.get("id", "")) == str(pair[0]))
		_check(bool(validated.get("ok", false)) and matches.size() == 1
			and matches[0] == validated.get("ability", {}),
			"AC1: the loader publishes the normalised canonical " + str(pair[0]))
	# Named neighbouring records keep their prior values (checked by id, never by total).
	var crab := _record(raw, CRAB)
	var pinch := _ability(crab, "pinch")
	_check(_same(pinch.get("effects"), {"bleed": 2}) and pinch.get("move") == "attack2"
		and int(crab.get("stitched", {}).get("max_hp", 0)) == 22,
		"AC1: the Scissor Crab's authored Pinch is untouched")
	var hedgehog := _record(raw, HEDGEHOG)
	var burst := _ability(hedgehog, "quill_burst")
	_check(_same(burst.get("dmg"), [2, 3]) and _same(burst.get("effects"), {})
		and int(hedgehog.get("stitched", {}).get("max_hp", 0)) == 25,
		"AC1: the Pincushion Hedgehog's authored Quill Burst is untouched")


func _test_poses() -> void:
	var manifest: Variant = _read_json(POSES)
	_check(manifest is Dictionary, "AC1: the live move-pose manifest loads")
	if not manifest is Dictionary:
		return
	var poses: Dictionary = manifest.get("enemies", {}).get(BEETLE, {})
	_check(poses.has("skill") and poses.has("attack2")
		and str(poses.get("skill", {}).get("art", "")).ends_with("thimble_beetle_skill.png")
		and str(poses.get("attack2", {}).get("art", "")).ends_with("thimble_beetle_attack2.png"),
		"AC1: the beetle's existing skill and attack2 pose art are authored")
	_check(poses.has(str(ORIGINAL_SHELL_UP["move"])) and poses.has(str(SHELL_SHOVE["move"])),
		"AC1: Shell Up and Shell Shove select existing pose entries (no new art)")


# ---------------------------------------------------------------- fixtures and projections

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


func _hero_id_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero.get("rank", 0)) == rank and not bool(hero.get("lost", false)) \
				and int(hero.get("hp", 0)) > 0:
			return str(hero.get("id", ""))
	return ""


## Two read-only projections must agree and leave the authoritative battle untouched.
func _projection(battle: StitchedRules, actor_id: String, note: String) -> Dictionary:
	var actor := battle.get_unit(actor_id)
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var first := StitchedFoeIntent.choose(battle, actor)
	var second := StitchedFoeIntent.choose(battle, actor)
	_check(first == second, note + ": repeated projections are identical")
	_check(snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		note + ": choosing spends no state, turn or RNG")
	return first


func _assert_shelter(intent: Dictionary, note: String) -> void:
	_check(str(intent.get("ability_id", "")) == SHELL_UP
		and str(intent.get("ability_name", "")) == "Shell Up"
		and str(intent.get("ability_kind", "")) == "buff"
		and str(intent.get("target_side", "")) == "foe"
		and int(intent.get("target_rank", 0)) == SHELTER_RANK
		and intent.get("affected_ranks", []) == [SHELTER_RANK]
		and not bool(intent.get("multi", true)) and not bool(intent.get("pass", true))
		and int(intent.get("base_acc", -1)) == 100
		and intent.get("base_damage") == [0, 0]
		and int(intent.get("base_crit", -1)) == 0
		and _same(intent.get("base_effects"), {"thorns": THORNS}),
		note)


func _assert_shove(intent: Dictionary, note: String, rank: int = 1) -> void:
	_check(str(intent.get("ability_id", "")) == SHOVE
		and str(intent.get("ability_name", "")) == "Shell Shove"
		and str(intent.get("ability_kind", "")) == "melee"
		and str(intent.get("target_side", "")) == "hero"
		and int(intent.get("target_rank", 0)) == rank
		and intent.get("affected_ranks", []) == [rank]
		and not bool(intent.get("multi", true)) and not bool(intent.get("pass", true))
		and int(intent.get("base_acc", -1)) == 85
		and intent.get("base_damage") == [4, 6]
		and int(intent.get("base_crit", -1)) == 0
		and _same(intent.get("base_effects"), {"push": 1, "fray": FRAY}),
		note)


func _assert_rotation(battle: StitchedRules, actor_id: String, note: String) -> Dictionary:
	var expected := _rotation_id(battle, battle.get_unit(actor_id))
	var intent := _projection(battle, actor_id, note)
	_check(str(intent.get("ability_id", "")) == expected,
		note + ": keeps the original round rotation (%s)" % expected)
	return intent


# ---------------------------------------------------------------- AC2 wounded priority

func _test_projection() -> void:
	var battle := _fixture(FOES, 11)
	if battle == null:
		return
	var max_hp := int(battle.get_unit(BEETLE).get("max_hp", 0))
	_check(max_hp == 29 and int(battle.get_unit(BEETLE).get("rank", 0)) == 1
		and int(battle.get_unit(BEETLE).get("hp", 0)) == max_hp,
		"AC2 fixture: the beetle really starts at full 29 HP in rank 1")
	var quiet_state := battle.state_snapshot()
	var quiet_rng := battle.rng_state()
	_check(_rotation_id(battle, battle.get_unit(BEETLE)) == RAM,
		"AC2 fixture: round one's ordinary rotation is Thimble Ram")
	var full := _projection(battle, BEETLE, "AC2 high HP")
	_check(str(full.get("ability_id", "")) == RAM and _same(full.get("base_effects"), {}),
		"AC2: a healthy beetle keeps the ordinary rotation instead of sheltering")
	_check(quiet_state == battle.state_snapshot() and quiet_rng == battle.rng_state(),
		"AC2: the high-HP projection is genuinely read-only")
	# Exactly half and just below half both qualify.
	_set_hp(battle, BEETLE, max_hp / 2)
	_check(2 * int(battle.get_unit(BEETLE)["hp"]) <= max_hp
		and 2 * (int(battle.get_unit(BEETLE)["hp"]) + 1) > max_hp,
		"AC2 fixture: the beetle stands at the highest HP still at or below half of its 29 maximum")
	_assert_shelter(_projection(battle, BEETLE, "AC2 at the half-HP threshold"),
		"AC2: at the half-HP threshold a thorns-free beetle chooses its authored Shell Up")
	_set_hp(battle, BEETLE, max_hp / 2 - 1)
	_assert_shelter(_projection(battle, BEETLE, "AC2 just below half"),
		"AC2: just below half HP the beetle still shelters")
	# One point above half never triggers it.
	_set_hp(battle, BEETLE, max_hp / 2 + 1)
	var above := _assert_rotation(battle, BEETLE, "AC2 just above half")
	_check(str(above.get("ability_id", "")) == RAM,
		"AC2: one point above half HP never preempts the rotation")
	# Genuinely active temporary Thorns switch the priority to Shell Shove.
	_set_hp(battle, BEETLE, max_hp / 2)
	_set_statuses(battle, BEETLE, {"thorns": 1})
	var shove := _projection(battle, BEETLE, "AC2 temporary Thorns")
	_assert_shove(shove, "AC2: active temporary Thorns make the wounded beetle choose Shell Shove")
	_check(shove.keys().size() == 16 and shove.has("base_effects") and shove.has("foe_id")
		and shove.has("ability_name") and shove.has("affected_ranks"),
		"AC2: the priority keeps the exact existing intent schema and adds no field")
	# The nearest actually legal living doll is chosen rank by rank.
	battle._units["warden"]["lost"] = true
	var rear := _projection(battle, BEETLE, "AC2 lost rank one")
	_assert_shove(rear, "AC2: a lost front doll makes the shove take the next legal living rank 2", 2)
	battle._units["warden"]["lost"] = false
	# Another foe keeps its own authored rotation beside the beetle's priority.
	var control := _fixture([HEDGEHOG, BEETLE], 12)
	if control != null:
		_set_hp(control, HEDGEHOG, 12)
		_set_statuses(control, HEDGEHOG, {"thorns": 1})
		var other := _assert_rotation(control, HEDGEHOG, "AC2 non-beetle control")
		_check(str(other.get("ability_id", "")) == "quill_burst"
			and str(other.get("ability_id", "")) != SHELL_UP
			and str(other.get("ability_id", "")) != SHOVE,
			"AC2: another wounded thorns-carrying foe id never gains the beetle's shell priority")


# ---------------------------------------------------------------- AC2/AC4 fallbacks

func _test_fallbacks() -> void:
	# Missing Shell Up falls back to the untouched round rotation.
	var missing := _fixture(FOES, 21)
	if missing != null:
		var max_hp := int(missing.get_unit(BEETLE).get("max_hp", 0))
		_set_hp(missing, BEETLE, max_hp / 2)
		missing._units[BEETLE]["abilities"] = missing._units[BEETLE]["abilities"].filter(
			func(ability: Dictionary) -> bool: return str(ability.get("id", "")) != SHELL_UP)
		var intent := _assert_rotation(missing, BEETLE, "AC2 missing Shell Up")
		_check(str(intent.get("ability_id", "")) == RAM,
			"AC2: a wounded beetle without Shell Up keeps the Thimble Ram rotation")
	# Missing Shell Shove with active Thorns falls back the same way.
	var no_shove := _fixture(FOES, 22)
	if no_shove != null:
		var max_hp := int(no_shove.get_unit(BEETLE).get("max_hp", 0))
		_set_hp(no_shove, BEETLE, max_hp / 2)
		_set_statuses(no_shove, BEETLE, {"thorns": 2})
		no_shove._units[BEETLE]["abilities"] = no_shove._units[BEETLE]["abilities"].filter(
			func(ability: Dictionary) -> bool: return str(ability.get("id", "")) != SHOVE)
		var intent := _assert_rotation(no_shove, BEETLE, "AC2 missing Shell Shove")
		_check(str(intent.get("ability_id", "")) == RAM,
			"AC2: a wounded thorns-carrying beetle without Shell Shove keeps the rotation")
	# A beetle in rank 2 cannot self-cast Shell Up (its authored self target is rank 1).
	var rear := _fixture([CRAB, BEETLE], 23)
	if rear != null:
		var max_hp := int(rear.get_unit(BEETLE).get("max_hp", 0))
		_check(int(rear.get_unit(BEETLE).get("rank", 0)) == 2,
			"AC2 fixture: the authentic rear formation really places the beetle in rank 2")
		_set_hp(rear, BEETLE, max_hp / 2)
		var intent := _assert_rotation(rear, BEETLE, "AC2 illegal self target")
		_check(str(intent.get("ability_id", "")) == RAM and str(intent.get("target_side", "")) == "hero",
			"AC2: without a legal self target the wounded beetle keeps the ordinary Ram")
	# No living rank 1/2 doll leaves no legal shove; the rotation still decides.
	var empty := _fixture(FOES, 24)
	if empty != null:
		var max_hp := int(empty.get_unit(BEETLE).get("max_hp", 0))
		_set_hp(empty, BEETLE, max_hp / 2)
		_set_statuses(empty, BEETLE, {"thorns": 1})
		empty._units["warden"]["lost"] = true
		empty._units["seamstress"]["lost"] = true
		var intent := _assert_rotation(empty, BEETLE, "AC2 no legal shove target")
		_check(str(intent.get("ability_id", "")) == SHELL_UP,
			"AC2: with no legal living shove target the unmodified rotation shelters instead")
	# A wounded beetle outside its authored launch ranks passes instead of fabricating.
	var off_rank := _fixture(FOES, 25)
	if off_rank != null:
		var max_hp := int(off_rank.get_unit(BEETLE).get("max_hp", 0))
		_set_hp(off_rank, BEETLE, max_hp / 2)
		off_rank._units[BEETLE]["rank"] = 3
		var intent := _assert_rotation(off_rank, BEETLE, "AC2 illegal launch rank")
		_check(str(intent.get("ability_id", "")) == "" and bool(intent.get("pass", false))
			and not intent.has("base_damage") and not intent.has("base_effects"),
			"AC2: a rank-3 wounded beetle passes instead of launching an illegal shell move")
	# Dead, LOST and detached actors never project a priority action.
	var dead := _fixture(FOES, 26)
	if dead != null:
		var max_hp := int(dead.get_unit(BEETLE).get("max_hp", 0))
		_set_hp(dead, BEETLE, 0)
		dead._units[BEETLE]["dead"] = true
		var snapshot := dead.state_snapshot()
		var rng := dead.rng_state()
		_check(StitchedFoeIntent.choose(dead, dead.get_unit(BEETLE)).is_empty()
			and snapshot == dead.state_snapshot() and rng == dead.rng_state(),
			"AC4: a dead beetle has no intent and spends nothing")
	var lost := _fixture(FOES, 27)
	if lost != null:
		var max_hp := int(lost.get_unit(BEETLE).get("max_hp", 0))
		_set_hp(lost, BEETLE, max_hp / 2)
		_set_statuses(lost, BEETLE, {"thorns": 1})
		lost._units[BEETLE]["lost"] = true
		var snapshot := lost.state_snapshot()
		var rng := lost.rng_state()
		_check(StitchedFoeIntent.choose(lost, lost.get_unit(BEETLE)).is_empty()
			and snapshot == lost.state_snapshot() and rng == lost.rng_state(),
			"AC4: a LOST beetle has no intent and spends nothing")
	var detached := _fixture(FOES, 28)
	if detached != null:
		var snapshot := detached.state_snapshot()
		var rng := detached.rng_state()
		_check(StitchedFoeIntent.choose(detached, {}).is_empty()
			and StitchedFoeIntent.choose(detached, {"id": "not_a_real_foe"}).is_empty()
			and StitchedFoeIntent.choose(detached, detached.get_unit("warden")).is_empty()
			and snapshot == detached.state_snapshot() and rng == detached.rng_state(),
			"AC4: empty, unknown and hero-side actors never gain a fabricated shell action")


# ---------------------------------------------------------------- AC4 refusals

func _reach(battle: StitchedRules, actor_id: String, receipts: Array) -> bool:
	for step in range(160):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id:
			return true
		var passed := battle.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			return false
	return false


func _test_refusals() -> void:
	var battle := _fixture(FOES, 31)
	if battle == null:
		return
	var max_hp := int(battle.get_unit(BEETLE).get("max_hp", 0))
	_set_hp(battle, BEETLE, max_hp / 2)
	_set_statuses(battle, BEETLE, {"thorns": 3})
	var receipts: Array = []
	if not _reach(battle, BEETLE, receipts):
		_check(false, "AC4 fixture: the real beetle reaches its thorns turn")
		return
	_check(int(battle.get_unit(BEETLE)["statuses"].get("thorns", 0)) == 2,
		"AC4 fixture: the beetle's own turn ticks its temporary Thorns to 2")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var off_rank := battle.use_foe_ability(SHOVE, 3)
	_check(not bool(off_rank.get("ok", true)) and str(off_rank.get("error", "")) == "no legal target in rank 3",
		"AC4: an off-reach Shove rank is refused")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: the off-reach refusal spends no state, turn or RNG")
	var missing := battle.use_foe_ability("shell_hurl", 1)
	_check(not bool(missing.get("ok", true))
		and str(missing.get("error", "")) == "the foe has no ability shell_hurl",
		"AC4: a missing ability id is refused")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: the missing ability refusal spends no state, turn or RNG")
	var wrong_rank := battle.use_foe_ability(RAM, 2)
	_check(not bool(wrong_rank.get("ok", true))
		and str(wrong_rank.get("error", "")) == "no legal target in rank 2",
		"AC4: Thimble Ram still refuses its unauthored rank 2 target")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: the wrong-rank refusal spends no state, turn or RNG")
	var still := StitchedFoeIntent.choose(battle, battle.get_unit(BEETLE))
	_check(str(still.get("ability_id", "")) == SHOVE and before == battle.state_snapshot()
		and rng == battle.rng_state(),
		"AC4: refused casts leave the same legal Shell Shove intent available")
	receipts.append(battle.pass_turn())
	for step in range(64):
		if battle.is_over() or battle.current_side() == "hero":
			break
		receipts.append(battle.pass_turn())
	_check(battle.current_side() == "hero", "AC4 fixture: a genuine hero turn follows")
	var hero_state := battle.state_snapshot()
	var hero_rng := battle.rng_state()
	var wrong_side := battle.use_foe_ability(SHOVE, 1)
	_check(not bool(wrong_side.get("ok", true))
		and str(wrong_side.get("error", "")) == "it is not a foe turn"
		and hero_state == battle.state_snapshot() and hero_rng == battle.rng_state(),
		"AC4: a foe action on a hero turn is refused without any spend")


# ---------------------------------------------------------------- AC3 live seeded shove

func _test_live() -> void:
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
	_check(_hit_seed > 0, "AC3: a bounded seed search finds a natural landed Shell Shove")
	_check(_miss_seed > 0, "AC3: a bounded seed search finds a genuine natural Shell Shove miss")
	for seed_value in [_hit_seed, _miss_seed]:
		if seed_value < 0:
			continue
		var first := _live_script(seed_value)
		_check(not first.is_empty(), "AC3: the recorded seeded shell script completes")
		if first.is_empty():
			continue
		recording = false
		var replay := _live_script(seed_value)
		recording = true
		_check(not replay.is_empty() and _json(first) == _json(replay),
			"AC3: the same seed and action sequence replays receipts, ranks, statuses and RNG")
		print("thimble_shell_shove ",
			"hit" if bool(first.get("hit", false)) else "miss", " witness seed=", seed_value)
		if bool(first.get("hit", false)):
			_assert_blocked_shifts(seed_value)


## One complete seeded script: explicit half HP, the real round-one Shell Up, then the
## next real turn's Shell Shove with its genuine seeded roll, damage, Fray and Push.
func _live_script(seed_value: int) -> Dictionary:
	var battle := _fixture(FOES, seed_value)
	if battle == null:
		return {}
	var maximum := int(battle.get_unit(BEETLE).get("max_hp", 0))
	if maximum != 29 or int(battle.get_unit(BEETLE).get("rank", 0)) != SHELTER_RANK:
		return {}
	_set_hp(battle, BEETLE, maximum / 2)
	var receipts: Array = []
	if not _reach(battle, BEETLE, receipts):
		return {}
	var opening := battle.get_unit(BEETLE)
	if battle.round_number() != 1 or battle.current_side() != "foe" \
			or int(opening.get("statuses", {}).get("thorns", 0)) != 0:
		return {}
	if _rotation_id(battle, opening) != RAM:
		return {}
	var shelter := StitchedFoeIntent.choose(battle, opening)
	if not _check(str(shelter.get("ability_id", "")) == SHELL_UP,
		"AC2/AC3: a real wounded turn projects Shell Up ahead of the rotation"):
		return {}
	_assert_shelter(shelter, "AC3: the live wounded projection is the authored self Shell Up")
	var up := battle.use_foe_ability(SHELL_UP, int(shelter.get("target_rank", 0)))
	receipts.append(up)
	if not _check(bool(up.get("ok", false)) and str(up.get("actor", "")) == BEETLE
		and str(up.get("ability", "")) == SHELL_UP and up.get("results", []).size() == 1,
		"AC3: the real foe turn commits one authored Shell Up"):
		return {}
	var up_hit: Dictionary = up["results"][0]
	if not _check(str(up_hit.get("target", "")) == BEETLE and bool(up_hit.get("hit", false))
		and int(up_hit.get("damage", -1)) == 0
		and up_hit.get("statuses", []) == [{"status": "thorns", "duration": THORNS}],
		"AC3: Shell Up grants the beetle itself Thorns 3 and zero damage"):
		return {}
	var after_up := battle.get_unit(BEETLE)
	if not _check(int(after_up.get("statuses", {}).get("thorns", 0)) == THORNS
		and int(after_up.get("hp", -1)) == int(opening.get("hp", -2)),
		"AC3: the applied temporary Thorns really sits on the living beetle"):
		return {}
	if not _reach(battle, BEETLE, receipts):
		return {}
	var next_actor := battle.get_unit(BEETLE)
	if not _check(battle.round_number() >= 2
		and int(next_actor.get("statuses", {}).get("thorns", 0)) == THORNS - 1,
		"AC3: its next real turn keeps the temporary Thorns less one start-of-turn tick"):
		return {}
	if not _check(_rotation_id(battle, next_actor) == SHELL_UP,
		"AC3: the ordinary round-two rotation would shelter again, so the shove really preempts it"):
		return {}
	var shove := StitchedFoeIntent.choose(battle, next_actor)
	if not _check(str(shove.get("ability_id", "")) == SHOVE,
		"AC2/AC3: with active Thorns the next real turn projects Shell Shove"):
		return {}
	var rank := int(shove.get("target_rank", 0))
	var target_id := _hero_id_at(battle, rank)
	if not _check(rank in [1, 2] and not target_id.is_empty(),
		"AC3: the shove names an actually legal living rank 1-2 doll"):
		return {}
	_assert_shove(shove, "AC3: the live Shove keeps ACC 85, 4-6 damage, Push 1 and Fray 3", rank)
	var target_before := battle.get_unit(target_id)
	if not _check(int(target_before.get("rank", 0)) == rank
		and not bool(target_before.get("dead", true))
		and not bool(target_before.get("lost", true)) and int(target_before.get("hp", 0)) > 0,
		"AC3: the projected target is the really living doll in that rank"):
		return {}
	var again := StitchedFoeIntent.choose(battle, battle.get_unit(BEETLE))
	_check(again == shove, "AC2: the shove projection repeats identically and read-only")
	var cast := battle.use_foe_ability(SHOVE, rank)
	receipts.append(cast)
	if not _check(bool(cast.get("ok", false)) and str(cast.get("actor", "")) == BEETLE
		and str(cast.get("ability", "")) == SHOVE and cast.get("results", []).size() == 1,
		"AC3: the real foe turn commits one authored Shell Shove"):
		return {}
	var hit: Dictionary = cast["results"][0]
	var expected_chance := StitchedRules.hit_chance(
		85 + int(next_actor.get("acc", 0)) + int(battle.candle_band()["enemy_acc"]),
		battle.effective_dodge(target_before), int(next_actor.get("miss_streak", 0)))
	if not _check(str(hit.get("target", "")) == target_id and int(hit.get("target_rank", 0)) == rank
		and int(hit.get("hit_chance", 0)) == expected_chance and expected_chance == 80
		and bool(hit.get("hit", true)) == (int(hit.get("roll", 101)) <= expected_chance),
		"AC3: Shell Shove rolls authored ACC 85 against the target's real DODGE"):
		return {}
	var target_after := battle.get_unit(target_id)
	var damaged := bool(hit.get("hit", false))
	if damaged:
		var damage := int(hit.get("damage", -1))
		if not _check(damage >= 4 and damage <= 6
			and int(target_after.get("hp", -1)) == int(target_before.get("hp", -2)) - damage,
			"AC3: a landed Shell Shove deals its authored 4-6 damage to the real doll"):
			return {}
		var fray_event: Dictionary = hit.get("fray_event", {})
		if not _check(int(fray_event.get("change", 0)) == FRAY
			and int(fray_event.get("before", -1)) == int(target_before.get("fray", 0))
			and int(fray_event.get("after", -1)) == int(target_before.get("fray", 0)) + FRAY
			and int(target_after.get("fray", -1)) == int(target_before.get("fray", 0)) + FRAY,
			"AC3: the confirmed hit applies authored Fray 3 to the real doll"):
			return {}
		var shift: Dictionary = hit.get("shift", {})
		if not _check(bool(shift.get("ok", false)) and int(shift.get("from", 0)) == rank
			and int(shift.get("to", 0)) == rank + 1
			and int(target_after.get("rank", 0)) == rank + 1,
			"AC3: the legal one-step Push really moves the doll one rank along the thread"):
			return {}
		var swapped := str(shift.get("swapped", ""))
		if not swapped.is_empty():
			_check(int(battle.get_unit(swapped).get("rank", 0)) == rank,
				"AC3: the doll in the way really trades ranks with the pushed doll")
	else:
		_check(int(hit.get("damage", -1)) == 0
			and int(target_after.get("hp", -1)) == int(target_before.get("hp", 0))
			and int(target_after.get("rank", 0)) == rank
			and int(target_after.get("fray", -1)) == int(target_before.get("fray", 0))
			and not hit.has("shift") and not hit.has("fray_event"),
			"AC3: a natural Shell Shove miss conjures no damage, Fray or rank shift")
	var beetle_after := battle.get_unit(BEETLE)
	_check(int(beetle_after.get("hp", -1)) == int(next_actor.get("hp", -2))
		and int(beetle_after.get("statuses", {}).get("thorns", 0)) == THORNS - 1
		and (battle.is_over() or battle.current_actor_id() != BEETLE),
		"AC3: the beetle keeps its HP and remaining Thorns and spends exactly one turn")
	return {
		"seed": seed_value,
		"hit": damaged,
		"shelter": shelter.duplicate(true),
		"up": up.duplicate(true),
		"shove": shove.duplicate(true),
		"cast": cast.duplicate(true),
		"receipts": receipts.duplicate(true),
		"state": battle.state_snapshot(),
		"rng": battle.rng_state(),
	}


## Tangled and thread-cut dolls are genuinely immovable: the confirmed hit still deals its
## damage and Fray, but the shared thread legality refuses the Push.
func _assert_blocked_shifts(seed_value: int) -> void:
	var witnessed := 0
	for blocked in ["tangled", "thread_cut"]:
		var battle := _fixture(FOES, seed_value)
		if battle == null:
			continue
		var maximum := int(battle.get_unit(BEETLE).get("max_hp", 0))
		_set_hp(battle, BEETLE, maximum / 2)
		_set_statuses(battle, BEETLE, {"thorns": THORNS})
		var receipts: Array = []
		if not _reach(battle, BEETLE, receipts):
			continue
		var skipped := battle.pass_turn()
		receipts.append(skipped)
		if not bool(skipped.get("ok", false)) or not _reach(battle, BEETLE, receipts):
			continue
		var victim := _hero_id_at(battle, 1)
		if victim.is_empty():
			continue
		if blocked == "tangled":
			battle._units[victim]["statuses"]["tangled"] = 1
		else:
			battle._thread_cuts[victim] = 1
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BEETLE))
		if not _check(str(intent.get("ability_id", "")) == SHOVE
			and int(intent.get("target_rank", 0)) == 1,
			"AC3: an immovable-but-legal front doll is still the authored shove target (" + blocked + ")"):
			continue
		var before := battle.get_unit(victim)
		var cast := battle.use_foe_ability(SHOVE, 1)
		var results: Array = cast.get("results", [])
		if not _check(bool(cast.get("ok", false)) and results.size() == 1,
			"AC3: the real shove resolves against the immovable doll (" + blocked + ")"):
			continue
		var hit: Dictionary = results[0]
		if not _check(bool(hit.get("hit", false)),
			"AC3: the bounded hit seed really lands on the immovable doll (" + blocked + ")"):
			continue
		var after := battle.get_unit(victim)
		var shift: Dictionary = hit.get("shift", {})
		var reason := "tangled units cannot move" if blocked == "tangled" else "thread cut blocks movement"
		_check(not bool(shift.get("ok", true)) and str(shift.get("reason", "")) == reason
			and int(after.get("rank", 0)) == 1 and int(before.get("rank", 0)) == 1,
			"AC3: " + blocked + " refuses the Push instead of conjuring a shift")
		var allowed: Array = []
		for base in range(4, 7):
			allowed.append(StitchedRules.damage_after_modifiers(
				base, {}, before.get("statuses", {}), false, 0, int(before.get("prot", 0))))
		var damage := int(hit.get("damage", -1))
		_check(allowed.has(damage)
			and int(after.get("hp", -1)) == int(before.get("hp", 0)) - damage
			and int(after.get("fray", -1)) == int(before.get("fray", 0)) + FRAY,
			"AC3: the confirmed hit still deals its damage and Fray through a refused Push (" + blocked + ")")
		var resisted := false
		for entry in hit.get("statuses", []):
			resisted = resisted or bool(entry.get("resisted", false))
		_check(not resisted,
			"AC3: the foe's Push is settled by doll thread legality, never a separate resist evaluator")
		witnessed += 1
	_check(witnessed == 2,
		"AC3: both the Tangled and thread-cut immovable dolls really resolved a landed shove")


# ---------------------------------------------------------------- AC3 mounted live path

func _test_live_screen() -> void:
	var config: Dictionary = _preview.duplicate(true)
	config["seed"] = 7
	config["candle"] = 100
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(_catalog, BEETLE),
		StitchedEnemyCatalog.foe_for(_catalog, HEDGEHOG),
	]
	var host := Control.new()
	host.name = "ThimbleShellShoveHost"
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var stage := StitchedBattleScreen.new()
	var began := stage.begin(config)
	_check(began, "AC3 live: the real battle screen begins the canonical beetle fight")
	if not began:
		host.free()
		return
	host.add_child(stage)
	await process_frame
	var battle: StitchedRules = stage.battle
	if not _check(battle != null and battle.get_foes().size() == 2,
		"AC3 live: the mounted battle really holds the beetle and its escort"):
		host.free()
		return
	var maximum := int(battle.get_unit(BEETLE).get("max_hp", 0))
	_set_hp(battle, BEETLE, maximum / 2)
	var seen_up := -1
	var seen_shove := -1
	for step in range(14):
		if battle.is_over() or battle.current_side() != "hero":
			break
		stage.submit_pass()
		for index in range(stage.receipts.size()):
			var item: Dictionary = stage.receipts[index]
			if str(item.get("actor", "")) != BEETLE or str(item.get("action", "")) != "ability":
				continue
			if str(item.get("ability", "")) == SHELL_UP and seen_up < 0:
				seen_up = index
			if str(item.get("ability", "")) == SHOVE and seen_shove < 0:
				seen_shove = index
		if seen_up >= 0 and seen_shove >= 0:
			break
	_check(seen_up >= 0 and seen_shove > seen_up,
		"AC3 live: the mounted automatic driver commits Shell Up and then Shell Shove")
	if seen_up >= 0:
		var up: Dictionary = stage.receipts[seen_up]
		var up_results: Array = up.get("results", [])
		_check(str(up.get("actor", "")) == BEETLE and str(up.get("ability", "")) == SHELL_UP
			and up_results.size() == 1
			and str(up_results[0].get("target", "")) == BEETLE
			and int(up_results[0].get("damage", -1)) == 0
			and up_results[0].get("statuses", []) == [{"status": "thorns", "duration": THORNS}],
			"AC3 live: the real screen receipt shows the beetle's own Thorns 3 Shell Up")
	if seen_shove >= 0:
		var shove_receipt: Dictionary = stage.receipts[seen_shove]
		var results: Array = shove_receipt.get("results", [])
		_check(str(shove_receipt.get("actor", "")) == BEETLE
			and str(shove_receipt.get("ability", "")) == SHOVE and results.size() == 1
			and str(results[0].get("target_side", "")) == "hero"
			and int(results[0].get("hit_chance", -1)) == 80
			and bool(results[0].get("hit", true)) == (
				int(results[0].get("roll", 101)) <= int(results[0].get("hit_chance", 0))),
			"AC3 live: the screen commits a real seeded Shell Shove against a hero")
	host.free()
