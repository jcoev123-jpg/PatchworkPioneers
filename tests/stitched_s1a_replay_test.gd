extends SceneTree
## S1a headless acceptance tests for the Design v4 "Stitched" rules core.
##
## The rules live in scripts/stitched/stitched_rules.gd and scripts/stitched/stitched_parts.gd;
## the part catalog is tests/fixtures/stitched_s1a_parts.json. Every battle below is built from
## authored data with one seeded RandomNumberGenerator, so all outcomes replay exactly.
## The existing card path (CombatParty/CombatState) is checked untouched in cards mode.

const FIXTURE := "res://tests/fixtures/stitched_s1a_parts.json"
const SETTING := "patchwork/combat_mode"
const SLOTS := ["head", "arms", "torso", "legs"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_modes()
	_test_ac2_turn_order()
	_test_ac2_actions()
	_test_ended_battle()
	_test_ac2_replay()
	_test_ac3_hit_crit_prot()
	_test_ac3_stun()
	_test_ac3_mark()
	_test_ac3_guard()
	_test_ac3_thorns()
	_test_ac3_scrap_heaps()
	_test_ac4_hanging()
	_test_ac4_retreat()
	_test_part_validation()
	_test_battle_validation()
	_test_ac2_non_boss_two_turns()
	_test_ac3_arm_damage_bonus()
	_test_ac3_zero_damage_effects()
	_test_ac3_heap_blocks_compaction()
	_test_ac3_self_move_preflight()
	_test_ac4_boss_retreat_after_death()
	ProjectSettings.set_setting(SETTING, "cards")
	if failures.is_empty():
		print("stitched_s1a_replay_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s1a_replay_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _copy(part: Dictionary) -> Dictionary:
	return part.duplicate(true)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


# ---------------------------------------------------------------- authored data helpers

func _fixture_parts() -> Array:
	var catalog := StitchedParts.load_catalog(FIXTURE)
	_check(catalog["ok"], "fixture parts load: " + str(catalog["error"]))
	return catalog["parts"]


func _parts_all() -> Array:
	var parts := _fixture_parts()
	for part in _test_parts():
		parts.append(part)
	return parts


func _party() -> Array:
	return [
		{
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"speed": 5,
			"dodge": 5,
			"acc": 5,
			"prot": 0,
			"parts": {
				"head": {"id": "warden_head_iron_helm", "tier": 1},
				"arms": {"id": "warden_arm_shield_bash", "tier": 1},
				"torso": {"id": "warden_torso_quilt", "tier": 1},
				"legs": {"id": "warden_legs_hold", "tier": 1},
			},
		},
		{
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"speed": 6,
			"dodge": 8,
			"acc": 5,
			"prot": 0,
			"parts": {
				"head": {"id": "any_head_needle_pin", "tier": 1},
				"arms": {"id": "any_arm_red_thread", "tier": 1},
				"torso": {"id": "any_torso_felt_coat", "tier": 1},
				"legs": {"id": "any_legs_stitch_step", "tier": 1},
			},
		},
		{
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"speed": 4,
			"dodge": 10,
			"acc": 8,
			"prot": 0,
			"parts": {
				"head": {"id": "warden_head_button_eye", "tier": 1},
				"arms": {"id": "warden_arm_brace", "tier": 1},
				"torso": {"id": "warden_torso_rivet", "tier": 1},
				"legs": {"id": "warden_legs_stride", "tier": 1},
			},
		},
		{
			"id": "monk",
			"name": "Lantern Monk",
			"max_hp": 30,
			"speed": 7,
			"dodge": 6,
			"acc": 6,
			"prot": 0,
			"parts": {
				"head": {"id": "warden_head_iron_helm", "tier": 2},
				"arms": {"id": "warden_arm_shield_bash", "tier": 2},
				"torso": {"id": "warden_torso_quilt", "tier": 2},
				"legs": {"id": "warden_legs_hold", "tier": 2},
			},
		},
	]


func _three_foes() -> Array:
	return [
		{
			"id": "pincushion",
			"name": "Pincushion",
			"max_hp": 21,
			"speed": 3,
			"dodge": 10,
			"acc": 0,
			"prot": 0,
			"abilities": [
				{
					"id": "quill",
					"name": "Quill Volley",
					"kind": "melee",
					"launch": [1, 2],
					"target": [1, 2],
					"target_side": "enemy",
					"acc": 85,
					"dmg": [4, 7],
					"crit": 0,
					"effects": {"bleed": 2},
					"move": "attack",
				},
			],
		},
		{
			"id": "moth",
			"name": "Moth Swarm",
			"max_hp": 18,
			"speed": 6,
			"dodge": 20,
			"acc": 0,
			"prot": 0,
			"abilities": [
				{
					"id": "flutter",
					"name": "Flutter Bite",
					"kind": "melee",
					"launch": [1, 2, 3],
					"target": [1, 2],
					"target_side": "enemy",
					"acc": 90,
					"dmg": [3, 5],
					"crit": 0,
					"effects": {"weak": 1},
					"move": "attack",
				},
			],
		},
		{
			"id": "thimble",
			"name": "Thimble Beetle",
			"max_hp": 24,
			"speed": 4,
			"dodge": 0,
			"acc": 0,
			"prot": 50,
			"abilities": [
				{
					"id": "clang",
					"name": "Clang",
					"kind": "melee",
					"launch": [1, 2],
					"target": [1, 2],
					"target_side": "enemy",
					"acc": 85,
					"dmg": [5, 8],
					"crit": 5,
					"effects": {},
					"move": "attack",
				},
			],
		},
	]


func _boss_foes() -> Array:
	var foes := _three_foes()
	foes[0] = {
		"id": "behemoth",
		"name": "Patchwork Behemoth",
		"max_hp": 60,
		"speed": 3,
		"dodge": 0,
		"acc": 0,
		"prot": 20,
		"is_boss": true,
		"turns_per_round": 2,
		"abilities": [
			{
				"id": "slam",
				"name": "Slam",
				"kind": "melee",
				"launch": [1, 2],
				"target": [1, 2],
				"target_side": "enemy",
				"acc": 85,
				"dmg": [6, 9],
				"crit": 0,
				"effects": {},
				"move": "attack",
			},
		],
	}
	return foes


func _config(seed_value: Variant, overrides: Dictionary = {}) -> Dictionary:
	var config := {
		"mode": "stitched",
		"seed": seed_value,
		"parts": _fixture_parts(),
		"heroes": _party(),
		"foes": _three_foes(),
	}
	for key in overrides:
		config[key] = overrides[key]
	return config


func _battle(seed_value: int, overrides: Dictionary = {}) -> StitchedRules:
	var built := StitchedRules.create(_config(seed_value, overrides))
	_check(built["ok"], "battle builds: " + str(built["error"]))
	if not built["ok"]:
		return null
	return built["battle"]


# ---------------------------------------------------------------- synthetic edge-case data

func _test_parts() -> Array:
	return [
		{
			"id": "test_head_crit",
			"name": "Test Crit Eye",
			"slot": "head",
			"owner": "any",
			"stat": {"crit": 95},
			"ability": {
				"id": "crit_strike",
				"name": "Crit Strike",
				"kind": "melee",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 100,
				"dmg": [10, 10],
				"crit": 0,
				"effects": {},
				"move": "attack",
			},
			"text": "Test part: always crits for 1.5x its maximum."
		},
		{
			"id": "test_head_miss",
			"name": "Test Blind Eye",
			"slot": "head",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "miss_strike",
				"name": "Miss Strike",
				"kind": "melee",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 0,
				"dmg": [1, 1],
				"crit": 0,
				"effects": {},
				"move": "attack",
			},
			"text": "Test part: almost always misses."
		},
		{
			"id": "test_head_mark",
			"name": "Test Mark Pin",
			"slot": "head",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "mark_pin",
				"name": "Mark Pin",
				"kind": "debuff",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 100,
				"dmg": [1, 1],
				"crit": 0,
				"effects": {"mark": 2},
				"move": "attack",
			},
			"text": "Test part: marks a foe for two of its turns."
		},
		{
			"id": "test_arm_plain",
			"name": "Test Plain Arm",
			"slot": "arms",
			"owner": "any",
			"stat": {"dmg": 0},
			"ability": {
				"id": "plain_hit",
				"name": "Plain Hit",
				"kind": "melee",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 100,
				"dmg": [10, 10],
				"crit": 0,
				"effects": {},
				"move": "attack",
			},
			"text": "Test part: a flat 10 damage hit."
		},
		{
			"id": "test_arm_hunt",
			"name": "Test Mark Hunter",
			"slot": "arms",
			"owner": "any",
			"stat": {"dmg": 0},
			"ability": {
				"id": "mark_hunt",
				"name": "Mark Hunt",
				"kind": "melee",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 100,
				"dmg": [4, 4],
				"crit": 0,
				"mark_damage": 3,
				"effects": {},
				"move": "attack",
			},
			"text": "Test part: 4 damage, +3 against a Marked foe."
		},
		{
			"id": "test_torso_prot",
			"name": "Test Stuffing",
			"slot": "torso",
			"owner": "any",
			"stat": {"prot": 150},
			"ability": {
				"id": "stuff_up",
				"name": "Stuff Up",
				"kind": "buff",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "self",
				"acc": 100,
				"dmg": [0, 0],
				"crit": 0,
				"effects": {},
				"move": "skill",
			},
			"text": "Test part: PROT far past the 80% cap."
		},
		{
			"id": "test_torso_plain",
			"name": "Test Plain Torso",
			"slot": "torso",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "breathe",
				"name": "Breathe",
				"kind": "buff",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "self",
				"acc": 100,
				"dmg": [0, 0],
				"crit": 0,
				"effects": {},
				"move": "skill",
			},
			"text": "Test part: a harmless self buff."
		},
		{
			"id": "test_torso_heal",
			"name": "Test Mend",
			"slot": "torso",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "test_mend",
				"name": "Test Mend",
				"kind": "heal",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "ally",
				"acc": 100,
				"dmg": [0, 0],
				"crit": 0,
				"effects": {"heal": 5},
				"move": "skill",
			},
			"text": "Test part: heals an ally 5."
		},
		{
			"id": "test_legs_plain",
			"name": "Test Plain Legs",
			"slot": "legs",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "step",
				"name": "Step",
				"kind": "buff",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "self",
				"acc": 100,
				"dmg": [0, 0],
				"crit": 0,
				"effects": {},
				"move": "skill",
			},
			"text": "Test part: a harmless self buff."
		},
		{
			"id": "test_head_plain",
			"name": "Test Plain Eye",
			"slot": "head",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "plain_strike",
				"name": "Plain Strike",
				"kind": "melee",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 100,
				"dmg": [10, 10],
				"crit": 0,
				"effects": {},
				"move": "attack",
			},
			"text": "Test part: a flat 10 damage hit with no crit bonus."
		},
		{
			"id": "test_head_zero_mark",
			"name": "Test Mark Needle",
			"slot": "head",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "zero_mark",
				"name": "Zero Mark",
				"kind": "debuff",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 100,
				"dmg": [0, 0],
				"crit": 0,
				"effects": {"mark": 2},
				"move": "attack",
			},
			"text": "Test part: a 0-damage hit that Marks the target for two turns."
		},
		{
			"id": "test_arm_plus_two",
			"name": "Test Weighted Arm",
			"slot": "arms",
			"owner": "any",
			"stat": {"dmg": 2},
			"ability": {
				"id": "weighted_hit",
				"name": "Weighted Hit",
				"kind": "melee",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": 100,
				"dmg": [10, 10],
				"crit": 0,
				"effects": {},
				"move": "attack",
			},
			"text": "Test part: a +2 damage arm whose own hit is a flat 10."
		},
		{
			"id": "test_arm_tangle",
			"name": "Test Snare Arm",
			"slot": "arms",
			"owner": "any",
			"stat": {},
			"ability": {
				"id": "tangle_ally",
				"name": "Tangle Ally",
				"kind": "debuff",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "ally",
				"acc": 100,
				"dmg": [0, 0],
				"crit": 0,
				"effects": {"tangled": 3},
				"move": "skill",
			},
			"text": "Test part: Tangles one ally for three of its turns."
		},
	]


func _synthetic_hero(
	unit_id: String,
	head_id: String,
	arms_id: String,
	torso_id: String,
	legs_id: String,
	max_hp: int = 40,
	speed: int = 5,
	dodge: int = 0,
	acc: int = 0,
	prot: int = 0
) -> Dictionary:
	return {
		"id": unit_id,
		"name": unit_id,
		"max_hp": max_hp,
		"speed": speed,
		"dodge": dodge,
		"acc": acc,
		"prot": prot,
		"parts": {
			"head": {"id": head_id, "tier": 1},
			"arms": {"id": arms_id, "tier": 1},
			"torso": {"id": torso_id, "tier": 1},
			"legs": {"id": legs_id, "tier": 1},
		},
	}


func _synthetic_foe(
	unit_id: String,
	max_hp: int = 60,
	speed: int = 2,
	dodge: int = 0,
	prot: int = 0,
	damage: Array = [1, 1],
	acc: int = 100,
	is_boss: bool = false,
	turns: int = 1
) -> Dictionary:
	return {
		"id": unit_id,
		"name": unit_id,
		"max_hp": max_hp,
		"speed": speed,
		"dodge": dodge,
		"acc": 0,
		"prot": prot,
		"is_boss": is_boss,
		"turns_per_round": turns,
		"abilities": [
			{
				"id": unit_id + "_strike",
				"name": unit_id + " strike",
				"kind": "melee",
				"launch": [1, 2, 3, 4],
				"target": [1, 2, 3, 4],
				"target_side": "enemy",
				"acc": acc,
				"dmg": damage,
				"crit": 0,
				"effects": {},
				"move": "attack",
			},
		],
	}


func _synthetic_battle(seed_value: int, heroes: Array, foes: Array) -> StitchedRules:
	var built := StitchedRules.create({
		"mode": "stitched",
		"seed": seed_value,
		"parts": _parts_all(),
		"heroes": heroes,
		"foes": foes,
	})
	_check(built["ok"], "synthetic battle builds: " + str(built["error"]))
	if not built["ok"]:
		return null
	return built["battle"]


func _plain_party() -> Array:
	return [
		_synthetic_hero("warden", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
	]


func _weak_foes() -> Array:
	return [_synthetic_foe("foe_a"), _synthetic_foe("foe_b")]


## A party whose only difference is the Warden's head ability and arms stat, used to compare
## the same seeded attack with and without an arms damage bonus.
func _damage_test_party(head_id: String, arms_id: String) -> Array:
	return [
		_synthetic_hero("warden", head_id, arms_id, "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
	]


## Drives the Warden's turns until the named foe in the given rank is dead.
func _kill_foe_with_plain_arm(
	battle: StitchedRules, hero_id: String, foe_id: String, rank: int
) -> bool:
	var steps := 0
	while int(battle.get_unit(foe_id)["hp"]) > 0 and not battle.is_over() and steps < 40:
		if not _drive_to(battle, hero_id):
			return false
		var receipt := battle.use_part("test_arm_plain", rank)
		if not receipt["ok"]:
			return false
		steps += 1
	return int(battle.get_unit(foe_id)["hp"]) == 0


## Drives the Warden's turns until the scrap heap in the given rank is cleared.
func _clear_heap_at(battle: StitchedRules, hero_id: String, rank: int) -> bool:
	var steps := 0
	while not battle.is_over() and steps < 40:
		var standing := false
		for heap in battle.get_heaps():
			if int(heap["rank"]) == rank:
				standing = true
		if not standing:
			return false
		if not _drive_to(battle, hero_id):
			return false
		var receipt := battle.use_part("test_arm_plain", rank)
		if not receipt["ok"]:
			return false
		if bool(receipt["results"][0].get("heap_cleared", false)):
			return true
		steps += 1
	return false


# ---------------------------------------------------------------- driving helpers

func _snapshot_text(battle: StitchedRules) -> String:
	return JSON.stringify(battle.state_snapshot())


func _act_for_current(battle: StitchedRules) -> Dictionary:
	if battle.current_side() == "hero":
		return battle.pass_turn()
	return _foe_auto_action(battle, battle.current_actor_id())


func _foe_auto_action(battle: StitchedRules, actor_id: String) -> Dictionary:
	var unit := battle.get_unit(actor_id)
	var abilities: Array = unit.get("abilities", [])
	if abilities.is_empty():
		return battle.pass_turn()
	var ability_id := str(abilities[0]["id"])
	for rank in range(1, 5):
		var receipt := battle.use_foe_ability(ability_id, rank)
		if receipt["ok"]:
			return receipt
	return battle.pass_turn()


func _foe_action_on_rank(battle: StitchedRules, actor_id: String, rank: int) -> Dictionary:
	var unit := battle.get_unit(actor_id)
	var abilities: Array = unit.get("abilities", [])
	if abilities.is_empty():
		return battle.pass_turn()
	return battle.use_foe_ability(str(abilities[0]["id"]), rank)


func _hero_auto_action(battle: StitchedRules, actor_id: String) -> Dictionary:
	var unit := battle.get_unit(actor_id)
	var parts: Dictionary = unit.get("parts", {})
	for slot in SLOTS:
		if not parts.has(slot):
			continue
		var part_id := str(parts[slot]["id"])
		for rank in range(1, 5):
			var receipt := battle.use_part(part_id, rank)
			if receipt["ok"]:
				return receipt
	for direction in [-1, 1]:
		var moved := battle.move(direction)
		if moved["ok"]:
			return moved
	return battle.pass_turn()


func _drive_to(battle: StitchedRules, unit_id: String, limit: int = 80) -> bool:
	var steps := 0
	while not battle.is_over() and steps < limit:
		if battle.current_actor_id() == unit_id:
			return true
		var receipt := _act_for_current(battle)
		if not receipt["ok"]:
			return false
		steps += 1
	return not battle.is_over() and battle.current_actor_id() == unit_id


func _drive_to_side(battle: StitchedRules, side: String, limit: int = 80) -> bool:
	var steps := 0
	while not battle.is_over() and steps < limit:
		if battle.current_side() == side:
			return true
		var receipt := _act_for_current(battle)
		if not receipt["ok"]:
			return false
		steps += 1
	return not battle.is_over() and battle.current_side() == side


func _expected_order(battle: StitchedRules, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var entries: Array = []
	var heroes := battle.get_heroes()
	heroes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["rank"]) < int(b["rank"]))
	for hero in heroes:
		entries.append({
			"id": str(hero["id"]),
			"side": "hero",
			"rank": int(hero["rank"]),
			"total": int(hero["speed"]) + rng.randi_range(1, 8),
			"seq": entries.size(),
		})
	var foes := battle.get_foes()
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["rank"]) < int(b["rank"]))
	for foe in foes:
		var total := int(foe["speed"]) + rng.randi_range(1, 8)
		for _turn in range(int(foe["turns_per_round"])):
			entries.append({
				"id": str(foe["id"]),
				"side": "foe",
				"rank": int(foe["rank"]),
				"total": total,
				"seq": entries.size(),
			})
	var ids: Array = []
	for entry in StitchedRules.sort_turn_entries(entries):
		ids.append(str(entry["id"]))
	return ids


# ---------------------------------------------------------------- AC1

func _test_ac1_modes() -> void:
	_check(ProjectSettings.has_setting(SETTING), "AC1: project.godot authors the combat_mode setting")
	_check(str(ProjectSettings.get_setting(SETTING)) == StitchedRules.MODE_CARDS, "AC1: the authored combat_mode is cards")
	_check(StitchedRules.combat_mode() == StitchedRules.MODE_CARDS, "AC1: the shipped default combat mode is cards")
	_check(StitchedRules.uses_card_combat(), "AC1: cards mode keeps the card battle in charge")
	var cards_config := _config(11)
	cards_config.erase("mode")
	var blocked := StitchedRules.create(cards_config)
	_check(not blocked["ok"], "AC1: the stitched core refuses to build while combat_mode is cards")
	_check(blocked["battle"] == null, "AC1: a refused build returns no battle object")
	# The existing card path still works exactly as before: three heroes and the 3-energy turn.
	var card_party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(card_party.is_valid(), "AC1: the existing three-hero card party still builds")
	_check(card_party.get_heroes().size() == 3, "AC1: the card party keeps three heroes")
	var card_state := CombatState.new()
	_check(card_state.start_player_turn() and card_state.energy == 3, "AC1: the card turn still grants three energy")
	_check(card_state.try_spend_energy(1) and card_state.energy == 2, "AC1: the card turn still spends energy")
	# Stitched mode comes from the real project setting.
	ProjectSettings.set_setting(SETTING, "stitched")
	_check(StitchedRules.combat_mode() == StitchedRules.MODE_STITCHED, "AC1: the project setting switches combat to stitched")
	var built := StitchedRules.create(_config(7))
	ProjectSettings.set_setting(SETTING, "cards")
	_check(built["ok"], "AC1: stitched mode builds a battle: " + str(built["error"]))
	if built["ok"]:
		var battle: StitchedRules = built["battle"]
		_check(battle.is_valid(), "AC1: the stitched battle is valid")
		var heroes := battle.get_heroes()
		_check(heroes.size() == 4, "AC1: stitched mode constructs four heroes")
		var ranks: Array = []
		for hero in heroes:
			ranks.append(int(hero["rank"]))
			_check(hero["parts"].size() == 4, "AC1: every hero wears four equipped slots")
		_check(ranks == [1, 2, 3, 4], "AC1: the four heroes fill ranks 1-4")
		_check(int(battle.get_unit("warden")["max_hp"]) == 46, "AC1: a tier I torso adds its max HP in the battle")
		_check(int(battle.get_unit("monk")["max_hp"]) == 39, "AC1: a tier II torso adds its raised max HP in the battle")
		var foes := battle.get_foes()
		_check(foes.size() >= 2 and foes.size() <= 3, "AC1: a stitched fight starts with two or three foes")
		_check(battle.turn_order().size() == 7, "AC1: four heroes and three foes roll seven turns")
	# Four starting foes are refused before any state exists.
	var four := StitchedRules.create(_config(7, {"foes": _three_foes() + [_synthetic_foe("extra")]}))
	_check(not four["ok"], "AC1: a four-foe starting fight is refused")
	# A malformed setting falls back to cards; an explicit unknown mode is refused.
	ProjectSettings.set_setting(SETTING, "banana")
	_check(StitchedRules.combat_mode() == StitchedRules.MODE_CARDS, "AC1: a malformed setting falls back to cards")
	var unknown := StitchedRules.create(_config(7, {"mode": "sideways"}))
	ProjectSettings.set_setting(SETTING, "cards")
	_check(not unknown["ok"], "AC1: an explicit unknown combat mode is refused")
	_check(StitchedRules.combat_mode() == StitchedRules.MODE_CARDS, "AC1: the test restores the cards default")


# ---------------------------------------------------------------- AC2

func _test_ac2_turn_order() -> void:
	var entries: Array = [
		{"id": "hero_back", "side": "hero", "rank": 3, "total": 12, "seq": 2},
		{"id": "hero_front", "side": "hero", "rank": 1, "total": 12, "seq": 1},
		{"id": "foe_front", "side": "foe", "rank": 1, "total": 12, "seq": 3},
		{"id": "foe_high", "side": "foe", "rank": 2, "total": 20, "seq": 4},
	]
	var sorted := StitchedRules.sort_turn_entries(entries)
	_check(str(sorted[0]["id"]) == "foe_high", "AC2: the highest SPEED+1d8 total acts first")
	_check(str(sorted[1]["id"]) == "hero_front", "AC2: a hero wins a tie against a foe")
	_check(str(sorted[2]["id"]) == "hero_back", "AC2: a lower rank wins a tie within a side")
	_check(str(sorted[3]["id"]) == "foe_front", "AC2: the tied foe acts last")
	var battle := _battle(4242)
	var expected := _expected_order(battle, 4242)
	_check(battle.turn_order() == expected, "AC2: the round order is SPEED+1d8 from the seeded RNG")
	var acted: Array = []
	var guard := 0
	while battle.round_number() == 1 and not battle.is_over() and guard < 20:
		acted.append(battle.current_actor_id())
		var receipt := battle.pass_turn()
		_check(receipt["ok"], "AC2: each unit can spend its turn")
		guard += 1
	_check(acted == expected, "AC2: each unit acts exactly once, in the rolled order")
	_check(battle.round_number() == 2, "AC2: the round ends after every unit has acted")
	var boss := _battle(99, {"foes": _boss_foes()})
	var boss_order := boss.turn_order()
	_check(boss_order.size() == 8, "AC2: a boss takes two turns, so four heroes and three foes roll eight")
	var boss_turns := 0
	for unit_id in boss_order:
		if str(unit_id) == "behemoth":
			boss_turns += 1
	_check(boss_turns == 2, "AC2: the boss appears twice in the round order")
	var boss_acts := 0
	guard = 0
	while boss.round_number() == 1 and not boss.is_over() and guard < 20:
		if boss.current_actor_id() == "behemoth":
			boss_acts += 1
		_check(boss.pass_turn()["ok"], "AC2: the boss round can be spent turn by turn")
		guard += 1
	_check(boss_acts == 2, "AC2: the boss really acts twice in the round")
	_check(boss.round_number() == 2, "AC2: the boss round ends after eight turns")


func _test_ac2_actions() -> void:
	var battle := _battle(2024)
	_check(_drive_to(battle, "warden"), "AC2: the drive helper reaches the Warden's turn")
	var before := _snapshot_text(battle)
	var wrong_part := battle.use_part("any_head_needle_pin", 1)
	_check(not wrong_part["ok"], "AC2: a part the hero does not wear is refused")
	_check(_snapshot_text(battle) == before, "AC2: a refused part leaves state and RNG unchanged")
	var wrong_rank := battle.use_part("warden_head_iron_helm", 4)
	_check(not wrong_rank["ok"], "AC2: a target outside the ability's rank mask is refused")
	_check(_snapshot_text(battle) == before, "AC2: a refused target rank leaves state and RNG unchanged")
	var legal := battle.use_part("warden_head_iron_helm", 1)
	_check(legal["ok"], "AC2: a legal part ability resolves")
	_check(int(legal["results"][0]["hit_chance"]) >= 5 and int(legal["results"][0]["hit_chance"]) <= 95, "AC2: the receipt reports a clamped hit chance")
	_check(_snapshot_text(battle) != before, "AC2: a legal action changes the battle")
	var spent := _snapshot_text(battle)
	var again := battle.use_part("warden_head_iron_helm", 1)
	_check(not again["ok"], "AC2: a hero cannot act twice in the same turn")
	_check(_snapshot_text(battle) == spent, "AC2: the refused extra action leaves state and RNG unchanged")
	_check(_drive_to(battle, "warden"), "AC2: the Warden gets another turn")
	var from_rank := int(battle.get_unit("warden")["rank"])
	var direction := 1 if from_rank < 4 else -1
	var destination := from_rank + direction
	var neighbour := ""
	for hero in battle.get_heroes():
		if int(hero["rank"]) == destination:
			neighbour = str(hero["id"])
	var move_receipt := battle.move(direction)
	_check(move_receipt["ok"], "AC2: Move swaps with the adjacent ally")
	_check(int(battle.get_unit("warden")["rank"]) == destination, "AC2: Move lands in the adjacent rank")
	_check(neighbour != "" and str(move_receipt["swapped"]) == neighbour, "AC2: Move swaps with the ally standing there")
	_check(int(battle.get_unit(neighbour)["rank"]) == from_rank, "AC2: the swapped ally takes the old rank")
	_check(_drive_to(battle, "warden"), "AC2: the Warden gets a third turn")
	var moved := _snapshot_text(battle)
	var bad_move := battle.move(2)
	_check(not bad_move["ok"], "AC2: an illegal move direction is refused")
	_check(_snapshot_text(battle) == moved, "AC2: a refused move leaves state and RNG unchanged")
	_check(battle.pass_turn()["ok"], "AC2: Pass spends the turn without acting")
	# Wrong launch rank: the Monk stands in rank 4 and the tier II helm launches only from rank 1.
	var monk_rank := int(battle.get_unit("monk")["rank"])
	_check(monk_rank == 4, "AC2: the Monk stands in the back rank")
	_check(_drive_to(battle, "monk"), "AC2: the drive helper reaches the Monk's turn")
	var launch_before := _snapshot_text(battle)
	var wrong_launch := battle.use_part("warden_head_iron_helm", 1)
	_check(not wrong_launch["ok"], "AC2: an ability that cannot launch from the hero's rank is refused")
	_check(_snapshot_text(battle) == launch_before, "AC2: a refused launch rank leaves state and RNG unchanged")
	var wrong_target := battle.use_part("warden_torso_quilt", 2)
	_check(not wrong_target["ok"], "AC2: an ally ability cannot target a rank outside its mask")
	_check(_snapshot_text(battle) == launch_before, "AC2: a refused ally target leaves state and RNG unchanged")
	# Turn ownership: no hero action while a foe owns the turn.
	_check(_drive_to_side(battle, "foe"), "AC2: the drive helper reaches a foe turn")
	var foe_turn_before := _snapshot_text(battle)
	var out_of_turn := battle.use_part("any_head_needle_pin", 1)
	_check(not out_of_turn["ok"], "AC2: a hero cannot act on a foe's turn")
	_check(_snapshot_text(battle) == foe_turn_before, "AC2: an out-of-turn action leaves state and RNG unchanged")
	var foe_receipt := _foe_auto_action(battle, battle.current_actor_id())
	_check(foe_receipt["ok"], "AC2: a foe spends its turn with a legal action")
	if foe_receipt.has("results"):
		_check(foe_receipt["results"].size() >= 1, "AC2: a foe ability reports its target")


func _test_ended_battle() -> void:
	var battle := _synthetic_battle(404, _plain_party(), [
		_synthetic_foe("foe_a", 10),
		_synthetic_foe("foe_b", 10),
	])
	var steps := 0
	while not battle.is_over() and steps < 60:
		if battle.current_side() == "hero":
			var receipt := battle.use_part("test_arm_plain", 1)
			_check(receipt["ok"], "AC2: a hero attack resolves while the fight runs")
		else:
			_check(_foe_auto_action(battle, battle.current_actor_id())["ok"], "AC2: a foe action resolves while the fight runs")
		steps += 1
	_check(battle.is_over(), "AC2: the fight reaches an outcome")
	_check(battle.outcome() == "victory", "AC2: killing every foe wins the fight")
	_check(battle.current_actor_id() == "", "AC2: a finished battle has no acting unit")
	_check(battle.get_unit("nobody").is_empty(), "AC2: a missing actor has no state")
	var before := _snapshot_text(battle)
	_check(not battle.use_part("test_arm_plain", 1)["ok"], "AC2: no ability can be used after the battle")
	_check(not battle.move(-1)["ok"], "AC2: no hero can move after the battle")
	_check(not battle.pass_turn()["ok"], "AC2: no unit can pass after the battle")
	_check(not battle.retreat()["ok"], "AC2: retreat is refused after the battle")
	_check(_snapshot_text(battle) == before, "AC2: ended-battle refusals leave state and RNG unchanged")


func _test_ac2_replay() -> void:
	var first := _play_trace(777)
	var second := _play_trace(777)
	var other := _play_trace(778)
	_check(JSON.stringify(first) == JSON.stringify(second), "AC2: two seeded traces of the same fight match exactly")
	_check(JSON.stringify(first) != JSON.stringify(other), "AC2: a different seed produces a different trace")
	var hits := 0
	var misses := 0
	var crits := 0
	for step in first:
		if not step.has("receipt"):
			continue
		for result in step["receipt"].get("results", []):
			if bool(result.get("hit", false)):
				hits += 1
			else:
				misses += 1
			if bool(result.get("crit", false)):
				crits += 1
	_check(hits > 0, "AC2: the replayed fight really lands hits")
	_check(misses > 0, "AC2: the replayed fight really records misses")
	_check(crits > 0, "AC2: the replayed fight really records crits")
	var last: Dictionary = first[first.size() - 1]
	_check(str(last.get("outcome", "")) in ["victory", "defeat", "retreated"], "AC2: the replayed fight reaches a real outcome")


func _play_trace(seed_value: int) -> Array:
	var battle := _battle(seed_value)
	var trace: Array = []
	var steps := 0
	while battle != null and not battle.is_over() and steps < 240:
		var actor := battle.current_actor_id()
		var receipt: Dictionary
		if battle.current_side() == "hero":
			receipt = _hero_auto_action(battle, actor)
		else:
			receipt = _foe_auto_action(battle, actor)
		trace.append({
			"actor": actor,
			"receipt": receipt,
			"state": battle.state_snapshot(),
		})
		steps += 1
	if battle != null:
		trace.append({"outcome": battle.outcome(), "round": battle.round_number()})
	return trace


# ---------------------------------------------------------------- AC3

func _test_ac3_hit_crit_prot() -> void:
	_check(StitchedRules.hit_chance(200, 0, 0) == 95, "AC3: hit chance clamps at 95")
	_check(StitchedRules.hit_chance(-200, 0, 0) == 5, "AC3: hit chance clamps at 5")
	_check(StitchedRules.hit_chance(90, 10, 0) == 80, "AC3: hit chance subtracts the target's DODGE")
	_check(StitchedRules.hit_chance(90, 10, 1) == 85, "AC3: a repeated miss adds +5 ACC")
	_check(StitchedRules.hit_chance(90, 10, 3) == 95, "AC3: a miss streak still clamps at 95")
	_check(StitchedRules.crit_damage(10) == 15, "AC3: a crit deals 1.5x the range maximum")
	_check(StitchedRules.crit_damage(7) == 10, "AC3: crit damage floors its 1.5x")
	_check(StitchedRules.apply_protection(10, 50) == 5, "AC3: PROT cuts direct damage by its percentage")
	_check(StitchedRules.apply_protection(10, 80) == 2, "AC3: PROT caps at 80%")
	_check(StitchedRules.apply_protection(10, 150) == 2, "AC3: PROT above the cap still cuts only 80%")
	# A guaranteed crit: 5% base + 95 crit stat = 100%.
	var crit_battle := _synthetic_battle(31, [
		_synthetic_hero("warden", "test_head_crit", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
	], _weak_foes())
	_check(_drive_to(crit_battle, "warden"), "AC3: the crit battle reaches the Warden")
	var crit_receipt := crit_battle.use_part("test_head_crit", 1)
	_check(crit_receipt["ok"], "AC3: the guaranteed crit resolves")
	var crit_result: Dictionary = crit_receipt["results"][0]
	_check(bool(crit_result["crit"]), "AC3: a 100% crit chance really crits")
	_check(int(crit_result["damage"]) == 15, "AC3: the crit deals exactly 1.5x the maximum")
	_check(int(crit_result.get("fray_relief", 0)) == 3, "AC3: a crit relieves three fray")
	# PROT in a real hit: 150 PROT takes only 20% of a flat 10.
	var prot_battle := _synthetic_battle(32, [
		_synthetic_hero("warden", "test_head_miss", "test_arm_plain", "test_torso_prot", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
	], [
		_synthetic_foe("foe_a", 60, 2, 0, 0, [10, 10]),
		_synthetic_foe("foe_b", 60, 2, 0, 0, [10, 10]),
	])
	_check(_drive_to_side(prot_battle, "foe"), "AC3: the PROT battle reaches a foe turn")
	var warden_hp := int(prot_battle.get_unit("warden")["hp"])
	var prot_receipt := _foe_auto_action(prot_battle, prot_battle.current_actor_id())
	_check(prot_receipt["ok"], "AC3: the foe hits the stuffed hero")
	var prot_result: Dictionary = prot_receipt["results"][0]
	_check(str(prot_result["target"]) == "warden", "AC3: the foe hits the front hero")
	_check(int(prot_result["damage"]) == 2, "AC3: the capped PROT cut really applies in a hit")
	_check(int(prot_battle.get_unit("warden")["hp"]) == warden_hp - 2, "AC3: the hero loses exactly the reduced damage")
	# Miss streaks: 0 ACC means a 5% chance; the next try is 10%.
	var streak_found := false
	for seed_value in range(1, 200):
		var battle := _synthetic_battle(seed_value, _plain_party(), _weak_foes())
		if not _drive_to(battle, "warden"):
			continue
		var first_attack := battle.use_part("test_head_miss", 1)
		if not first_attack["ok"] or bool(first_attack["results"][0]["hit"]):
			continue
		_check(int(first_attack["results"][0]["hit_chance"]) == 5, "AC3: the first try uses the clamped 5%")
		_check(int(battle.get_unit("warden")["miss_streak"]) == 1, "AC3: a miss records one miss in the streak")
		if not _drive_to(battle, "warden"):
			continue
		var second_attack := battle.use_part("test_head_miss", 1)
		if not second_attack["ok"] or bool(second_attack["results"][0]["hit"]):
			continue
		_check(int(second_attack["results"][0]["hit_chance"]) == 5, "AC3: one miss is still inside the 5% floor")
		_check(int(battle.get_unit("warden")["miss_streak"]) == 2, "AC3: a second miss extends the streak")
		if not _drive_to(battle, "warden"):
			continue
		var third_attack := battle.use_part("test_head_miss", 1)
		if not third_attack["ok"]:
			continue
		_check(int(third_attack["results"][0]["hit_chance"]) == 10, "AC3: two misses raise the next try by +5 ACC each")
		streak_found = true
		break
	_check(streak_found, "AC3: a seeded fight demonstrated the repeated-miss ACC bonus")


func _test_ac3_stun() -> void:
	var verified := false
	var refused_seen := false
	for seed_value in range(1, 200):
		var heroes := _plain_party()
		heroes[0] = _synthetic_hero("warden", "test_head_miss", "warden_arm_shield_bash", "test_torso_plain", "test_legs_plain")
		heroes[3] = _synthetic_hero("monk", "test_head_miss", "warden_arm_shield_bash", "test_torso_plain", "test_legs_plain")
		var battle := _synthetic_battle(seed_value, heroes, _weak_foes())
		if not _drive_to(battle, "warden"):
			continue
		var stun_receipt := battle.use_part("warden_arm_shield_bash", 1)
		if not stun_receipt["ok"] or not bool(stun_receipt["results"][0]["hit"]):
			continue
		if int(battle.get_unit("foe_a")["statuses"].get("stun", 0)) != 1:
			continue
		verified = true
		# The stunned foe's turn is skipped: it never owns a turn and gains stun resist.
		var visited: Array = []
		var steps := 0
		while int(battle.get_unit("foe_a")["statuses"].get("stun", 0)) > 0 \
				and not battle.is_over() and steps < 40:
			visited.append(battle.current_actor_id())
			if not _act_for_current(battle)["ok"]:
				break
			steps += 1
		_check(not ("foe_a" in visited), "AC3: a Stunned foe's turn is skipped")
		_check(int(battle.get_unit("foe_a")["statuses"].get("stun", 0)) == 0, "AC3: the skipped turn consumes the Stun")
		_check(int(battle.get_unit("foe_a")["statuses"].get("stun_resist", 0)) == 1, "AC3: the skipped turn grants one turn of stun resist")
		# Find a stun-capable hero turn while the resist still stands.
		steps = 0
		while not battle.is_over() and steps < 40:
			var resist := int(battle.get_unit("foe_a")["statuses"].get("stun_resist", 0))
			if resist != 1:
				break
			var actor := battle.current_actor_id()
			if actor == "warden" or actor == "monk":
				break
			if not _act_for_current(battle)["ok"]:
				break
			steps += 1
		if int(battle.get_unit("foe_a")["statuses"].get("stun_resist", 0)) != 1:
			continue
		# A second Stun while the resist still stands is refused.
		var second := battle.use_part("warden_arm_shield_bash", 1)
		if second["ok"] and bool(second["results"][0]["hit"]):
			var refused := false
			for entry in second["results"][0]["statuses"]:
				if str(entry["status"]) == "stun" and bool(entry.get("refused", false)):
					refused = true
			_check(refused, "AC3: Stun is refused while stun resist is active")
			_check(int(battle.get_unit("foe_a")["statuses"].get("stun", 0)) == 0, "AC3: a refused Stun leaves no stun status")
			refused_seen = refused
		if refused_seen:
			break
	_check(verified, "AC3: a seeded fight landed a Stun")
	_check(refused_seen, "AC3: a seeded fight showed stun resist refusing a second Stun")


func _test_ac3_mark() -> void:
	var applied := false
	var bonus_seen := false
	var expiry_seen := false
	for seed_value in range(1, 200):
		var battle := _synthetic_battle(seed_value, [
			_synthetic_hero("warden", "test_head_mark", "test_arm_hunt", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("seamstress", "test_head_miss", "test_arm_hunt", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("tinker", "test_head_miss", "test_arm_hunt", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("monk", "test_head_miss", "test_arm_hunt", "test_torso_plain", "test_legs_plain"),
		], _weak_foes())
		if not _drive_to(battle, "warden"):
			continue
		var mark_receipt := battle.use_part("test_head_mark", 1)
		if not mark_receipt["ok"] or not bool(mark_receipt["results"][0]["hit"]):
			continue
		var applied_duration := 0
		for entry in mark_receipt["results"][0]["statuses"]:
			if str(entry["status"]) == "mark":
				applied_duration = int(entry["duration"])
		_check(applied_duration == 2, "AC3: the Mark ability applies two turns of Mark")
		applied = true
		# Hunt the marked foe while the Mark still stands.
		var steps := 0
		var hunted := false
		while not battle.is_over() and steps < 30:
			if battle.current_side() == "hero" \
					and int(battle.get_unit("foe_a")["statuses"].get("mark", 0)) > 0:
				var hunt_receipt := battle.use_part("test_arm_hunt", 1)
				if hunt_receipt["ok"] and bool(hunt_receipt["results"][0]["hit"]):
					_check(int(hunt_receipt["results"][0]["damage"]) == 7, "AC3: a mark-hunting ability adds its bonus to a Marked foe")
					bonus_seen = true
					hunted = true
					break
			if not _act_for_current(battle)["ok"]:
				break
			steps += 1
		if not hunted:
			continue
		# Mark ticks at the start of the foe's turns and expires after two of them.
		steps = 0
		while int(battle.get_unit("foe_a")["statuses"].get("mark", 0)) > 0 \
				and not battle.is_over() and steps < 40:
			if not _act_for_current(battle)["ok"]:
				break
			steps += 1
		_check(int(battle.get_unit("foe_a")["statuses"].get("mark", 0)) == 0, "AC3: Mark expires after two of the foe's turns")
		if int(battle.get_unit("foe_a")["statuses"].get("mark", 0)) != 0:
			continue
		expiry_seen = true
		steps = 0
		while not battle.is_over() and steps < 20:
			if battle.current_side() == "hero":
				var plain_receipt := battle.use_part("test_arm_hunt", 1)
				if plain_receipt["ok"] and bool(plain_receipt["results"][0]["hit"]):
					_check(int(plain_receipt["results"][0]["damage"]) == 4, "AC3: without Mark the hunting bonus is gone")
					break
			if not _act_for_current(battle)["ok"]:
				break
			steps += 1
		break
	_check(applied, "AC3: a seeded fight applied a Mark")
	_check(bonus_seen, "AC3: a seeded fight showed the mark-hunting bonus")
	_check(expiry_seen, "AC3: a seeded fight showed the Mark expiring")


func _test_ac3_guard() -> void:
	var battle := _synthetic_battle(71, [
		_synthetic_hero("warden", "test_head_miss", "warden_arm_brace", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
	], _weak_foes())
	_check(_drive_to(battle, "warden"), "AC3: the guard battle reaches the Warden")
	var guard_receipt := battle.use_part("warden_arm_brace", 4)
	_check(guard_receipt["ok"], "AC3: the guard ability resolves")
	var warden := battle.get_unit("warden")
	_check(int(warden["statuses"].get("guard", 0)) == 2, "AC3: Guard lasts two of the guarder's turns")
	_check(str(warden["guard_target"]) == "monk", "AC3: Guard remembers the guarded ally")
	_check(_drive_to_side(battle, "foe"), "AC3: a foe gets a turn while the Guard stands")
	var monk_hp := int(battle.get_unit("monk")["hp"])
	var warden_hp := int(battle.get_unit("warden")["hp"])
	var guarded_hit := _foe_action_on_rank(battle, battle.current_actor_id(), 4)
	_check(guarded_hit["ok"], "AC3: the foe attacks the guarded rank")
	var guarded_result: Dictionary = guarded_hit["results"][0]
	_check(str(guarded_result.get("guarded_by", "")) == "warden", "AC3: the guarding ally takes the hit")
	_check(int(battle.get_unit("monk")["hp"]) == monk_hp, "AC3: the guarded hero is untouched")
	_check(int(battle.get_unit("warden")["hp"]) == warden_hp - int(guarded_result["damage"]), "AC3: the guarder loses the damage instead")
	# After two of the Warden's turns the Guard is gone and the Monk takes hits again.
	var steps := 0
	while int(battle.get_unit("warden")["statuses"].get("guard", 0)) > 0 \
			and not battle.is_over() and steps < 60:
		if not _act_for_current(battle)["ok"]:
			break
		steps += 1
	_check(int(battle.get_unit("warden")["statuses"].get("guard", 0)) == 0, "AC3: Guard expires on the guarder's turn count")
	_check(_drive_to_side(battle, "foe"), "AC3: a foe gets a turn after the Guard expires")
	var open_hit := _foe_action_on_rank(battle, battle.current_actor_id(), 4)
	_check(open_hit["ok"], "AC3: the foe attacks after the Guard expires")
	_check(str(open_hit["results"][0].get("guarded_by", "")) == "", "AC3: no guard redirects the hit after expiry")
	_check(str(open_hit["results"][0]["target"]) == "monk", "AC3: the aimed hero takes the hit again")


func _test_ac3_thorns() -> void:
	var battle := _synthetic_battle(83, [
		_synthetic_hero("warden", "test_head_miss", "test_arm_plain", "warden_torso_quilt", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
	], _weak_foes())
	_check(_drive_to(battle, "warden"), "AC3: the thorns battle reaches the Warden")
	var thorns_receipt := battle.use_part("warden_torso_quilt", 1)
	_check(thorns_receipt["ok"], "AC3: the thorns buff resolves on an ally")
	_check(int(battle.get_unit("warden")["statuses"].get("thorns", 0)) == 2, "AC3: the buff grants Thorns 2")
	_check(_drive_to_side(battle, "foe"), "AC3: a foe attacks the thorned hero")
	var foe_hp := int(battle.get_unit(battle.current_actor_id())["hp"])
	var hit := _foe_auto_action(battle, battle.current_actor_id())
	_check(hit["ok"], "AC3: the foe's attack resolves")
	var result: Dictionary = hit["results"][0]
	_check(str(result["target"]) == "warden", "AC3: the thorned hero is hit")
	_check(int(result.get("thorns", 0)) == 2, "AC3: Thorns answer the confirmed hit")
	_check(int(battle.get_unit(hit["actor"])["hp"]) == foe_hp - 2, "AC3: the attacker loses the Thorns damage")


func _test_ac3_scrap_heaps() -> void:
	_check(StitchedRules.heap_hp_for(21) == 7, "AC3: a scrap heap keeps exactly one third of max HP")
	_check(StitchedRules.heap_hp_for(20) == 6, "AC3: one third floors for uneven max HP")
	_check(StitchedRules.heap_hp_for(2) == 1, "AC3: a scrap heap always keeps at least one HP")
	var verified := false
	for seed_value in range(1, 80):
		var foes: Array = [
			_synthetic_foe("foe_a", 20),
			_synthetic_foe("foe_b", 20),
			_synthetic_foe("foe_c", 20),
		]
		var battle := _synthetic_battle(seed_value, _plain_party(), foes)
		if not _drive_to(battle, "warden"):
			continue
		var first := battle.use_part("test_arm_plain", 1)
		if not first["ok"] or not bool(first["results"][0]["hit"]):
			continue
		if not _drive_to(battle, "warden"):
			continue
		var kill := battle.use_part("test_arm_plain", 1)
		if not kill["ok"] or not bool(kill["results"][0]["hit"]):
			continue
		if int(battle.get_unit("foe_a")["hp"]) != 0:
			continue
		verified = true
		var heaps := battle.get_heaps()
		_check(heaps.size() == 1, "AC3: the killed foe leaves one scrap heap")
		if heaps.size() == 1:
			_check(int(heaps[0]["hp"]) == 6, "AC3: the heap keeps one third of the foe's max HP")
			_check(int(heaps[0]["rank"]) == 1, "AC3: the heap stands in the foe's rank")
			_check(int(heaps[0]["max_hp"]) == 6, "AC3: the heap's maximum is the same one third")
		_check(not ("heap:foe_a" in battle.turn_order()), "AC3: a scrap heap never takes a turn")
		_check(int(battle.get_unit("foe_b")["rank"]) == 2, "AC3: the foe behind stays back while the heap stands")
		# The dead foe leaves the next round's order; the heap never enters it.
		var round_now := battle.round_number()
		var steps := 0
		while battle.round_number() == round_now and not battle.is_over() and steps < 30:
			if not _act_for_current(battle)["ok"]:
				break
			steps += 1
		_check(battle.round_number() == round_now + 1, "AC3: the round rolls over after the kill")
		_check(battle.turn_order().size() == 6, "AC3: a dead foe rolls no turn in the next round")
		_check(not ("foe_a" in battle.turn_order()), "AC3: the dead foe is out of the round order")
		# Clearing the heap lets the line behind step forward.
		var cleared := false
		for _attempt in range(4):
			if not _drive_to(battle, "warden"):
				break
			var clear := battle.use_part("test_arm_plain", 1)
			if clear["ok"] and bool(clear["results"][0].get("heap_cleared", false)):
				cleared = true
				break
		_check(cleared, "AC3: a hit clears the scrap heap")
		if not cleared:
			break
		_check(battle.get_heaps().is_empty(), "AC3: no heap remains after clearing")
		_check(int(battle.get_unit("foe_b")["rank"]) == 1, "AC3: clearing the heap moves the foe behind forward")
		_check(int(battle.get_unit("foe_c")["rank"]) == 2, "AC3: the whole line closes up one rank")
		break
	_check(verified, "AC3: a seeded fight killed a foe and left a heap")


# ---------------------------------------------------------------- AC4

func _test_ac4_hanging() -> void:
	_check(StitchedRules.seam_holds(1) and StitchedRules.seam_holds(67), "AC4: a seam check holds on 1-67")
	_check(not StitchedRules.seam_holds(68) and not StitchedRules.seam_holds(100), "AC4: a seam check is lost on 68-100")
	# A heal above 0 HP ends Hanging.
	var heal_battle := _synthetic_battle(101, [
		_synthetic_hero("warden", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_heal", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
	], [_synthetic_foe("foe_a", 60, 2, 0, 0, [40, 40]), _synthetic_foe("foe_b", 60, 2, 0, 0, [40, 40])])
	_check(_drive_to_side(heal_battle, "foe"), "AC4: the hanging battle reaches a foe")
	var downing := _foe_auto_action(heal_battle, heal_battle.current_actor_id())
	_check(downing["ok"], "AC4: the foe's heavy hit resolves")
	var warden := heal_battle.get_unit("warden")
	_check(int(warden["hp"]) == 0 and bool(warden["hanging"]), "AC4: a 0-HP hero is Hanging by a Thread")
	# S1b's extra opening/tear rolls can put another foe before this healer.
	# Pass intervening actors to keep this legacy S1a check about healing, not damage.
	var heal_steps := 0
	while not heal_battle.is_over() and heal_battle.current_actor_id() != "seamstress" and heal_steps < 50:
		heal_battle.pass_turn()
		heal_steps += 1
	_check(heal_battle.current_actor_id() == "seamstress", "AC4: a Hanging hero's ally still gets a turn")
	var mend := heal_battle.use_part("test_torso_heal", 1)
	_check(mend["ok"], "AC4: the mend resolves on the Hanging hero")
	warden = heal_battle.get_unit("warden")
	_check(int(warden["hp"]) == 5 and not bool(warden["hanging"]), "AC4: a heal above 0 ends Hanging")
	# Further hits on a Hanging hero are seeded 67/33 seam checks; both outcomes occur.
	var holds := 0
	var losses := 0
	for seed_value in range(1, 120):
		var battle := _synthetic_battle(seed_value, [
			_synthetic_hero("warden", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		], [_synthetic_foe("foe_a", 60, 2, 0, 0, [40, 40]), _synthetic_foe("foe_b", 60, 2, 0, 0, [40, 40])])
		if not _drive_to_side(battle, "foe"):
			continue
		var first_hit := _foe_auto_action(battle, battle.current_actor_id())
		if not first_hit["ok"] or not bool(first_hit["results"][0].get("hanging", false)):
			continue
		# The Hanging hero can still act.
		if _drive_to(battle, "warden"):
			_check(battle.pass_turn()["ok"], "AC4: a Hanging hero can still act")
		if not _drive_to_side(battle, "foe"):
			continue
		var second_hit := _foe_auto_action(battle, battle.current_actor_id())
		if not second_hit["ok"]:
			continue
		var seam := str(second_hit["results"][0].get("seam", ""))
		if seam == "hold":
			holds += 1
			warden = battle.get_unit("warden")
			_check(bool(warden["hanging"]) and not bool(warden["lost"]), "AC4: a held seam keeps the hero Hanging, not lost")
		elif seam == "lost":
			losses += 1
			warden = battle.get_unit("warden")
			_check(bool(warden["lost"]), "AC4: a lost seam unpicks the hero")
			var round_now := battle.round_number()
			var steps := 0
			while battle.round_number() == round_now and not battle.is_over() and steps < 30:
				if not _act_for_current(battle)["ok"]:
					break
				steps += 1
			_check(not battle.is_over() and not ("warden" in battle.turn_order()), "AC4: a lost hero rolls no turn in the next round")
		if holds > 0 and losses > 0:
			break
	_check(holds > 0, "AC4: a seeded fight showed a Hanging hero holding the seam")
	_check(losses > 0, "AC4: a seeded fight showed a Hanging hero lost to the seam")


func _test_ac4_retreat() -> void:
	_check(StitchedRules.retreat_succeeds(1) and StitchedRules.retreat_succeeds(75), "AC4: retreat succeeds on 1-75")
	_check(not StitchedRules.retreat_succeeds(76) and not StitchedRules.retreat_succeeds(100), "AC4: retreat fails on 76-100")
	var success_seen := false
	var failure_seen := false
	for seed_value in range(1, 200):
		var battle := _synthetic_battle(seed_value, _plain_party(), _weak_foes())
		if not _drive_to_side(battle, "hero"):
			continue
		var actor := battle.current_actor_id()
		var receipt := battle.retreat()
		_check(receipt["ok"], "AC4: a non-boss retreat attempt is legal")
		if bool(receipt["success"]):
			success_seen = true
			_check(battle.outcome() == "retreated", "AC4: a successful retreat ends the fight")
			_check(receipt["reward"] == {}, "AC4: a retreat pays no reward")
			_check(int(receipt["fray_gain"]) == 15, "AC4: a successful retreat reports +15 fray")
			for hero in battle.get_heroes():
				_check(int(hero["fray"]) == 15, "AC4: every living hero gains +15 fray")
		else:
			failure_seen = true
			_check(battle.outcome() == "ongoing", "AC4: a failed retreat leaves the fight running")
			_check(int(receipt["fray_gain"]) == 0, "AC4: a failed retreat grants no fray")
			_check(battle.current_actor_id() != actor, "AC4: a failed retreat spends that hero's turn")
			for hero in battle.get_heroes():
				_check(int(hero["fray"]) == 0, "AC4: a failed retreat leaves fray unchanged")
		if success_seen and failure_seen:
			break
	_check(success_seen, "AC4: a seeded fight showed a successful retreat")
	_check(failure_seen, "AC4: a seeded fight showed a failed retreat")
	# A boss fight refuses retreat before any RNG or state change.
	var boss := _synthetic_battle(303, _plain_party(), [
		_synthetic_foe("behemoth", 60, 2, 0, 0, [1, 1], 100, true, 2),
		_synthetic_foe("foe_b", 20),
	])
	_check(_drive_to_side(boss, "hero"), "AC4: the boss battle reaches a hero turn")
	var before := _snapshot_text(boss)
	var refused := boss.retreat()
	_check(not refused["ok"], "AC4: a boss fight refuses retreat")
	_check(_snapshot_text(boss) == before, "AC4: a refused boss retreat leaves state and RNG unchanged")


# ---------------------------------------------------------------- data validation

func _test_part_validation() -> void:
	var base: Dictionary = _fixture_parts()[0]
	var duplicate := StitchedParts.build_catalog([base, base])
	_check(not duplicate["ok"], "validation: duplicate part ids are refused")
	var empty := StitchedParts.build_catalog([])
	_check(not empty["ok"], "validation: an empty catalog is refused")
	var missing := StitchedParts.load_catalog("res://tests/fixtures/does_not_exist.json")
	_check(not missing["ok"], "validation: a missing parts file is refused")
	var bad_slot := _copy(base)
	bad_slot["slot"] = "tail"
	_check(not StitchedParts.validate_part(bad_slot)["ok"], "validation: an illegal slot is refused")
	var bad_rank := _copy(base)
	bad_rank["ability"]["launch"] = [0]
	_check(not StitchedParts.validate_part(bad_rank)["ok"], "validation: a launch rank below 1 is refused")
	var high_rank := _copy(base)
	high_rank["ability"]["target"] = [5]
	_check(not StitchedParts.validate_part(high_rank)["ok"], "validation: a target rank above 4 is refused")
	var repeated_rank := _copy(base)
	repeated_rank["ability"]["launch"] = [1, 1]
	_check(not StitchedParts.validate_part(repeated_rank)["ok"], "validation: a repeated launch rank is refused")
	var bad_side := _copy(base)
	bad_side["ability"]["target_side"] = "everyone"
	_check(not StitchedParts.validate_part(bad_side)["ok"], "validation: an illegal target side is refused")
	var bad_dmg := _copy(base)
	bad_dmg["ability"]["dmg"] = [7, 4]
	_check(not StitchedParts.validate_part(bad_dmg)["ok"], "validation: a reversed damage range is refused")
	var bad_effect := _copy(base)
	bad_effect["ability"]["effects"] = {"poison": 1}
	_check(not StitchedParts.validate_part(bad_effect)["ok"], "validation: an unknown effect is refused")
	var bad_stat := _copy(base)
	bad_stat["stat"] = {"luck": 1}
	_check(not StitchedParts.validate_part(bad_stat)["ok"], "validation: an unknown stat is refused")
	var wrong_slot_stat := _copy(base)
	wrong_slot_stat["stat"] = {"max_hp": 5}
	_check(not StitchedParts.validate_part(wrong_slot_stat)["ok"], "validation: a head part cannot grant max HP")
	var bad_tier := _copy(base)
	bad_tier["tiers"] = {"4": {"ability": {"dmg": [1, 2]}}}
	_check(not StitchedParts.validate_part(bad_tier)["ok"], "validation: an illegal tier key is refused")
	var bad_tier_field := _copy(base)
	bad_tier_field["tiers"] = {"2": {"sparkle": true}}
	_check(not StitchedParts.validate_part(bad_tier_field)["ok"], "validation: an unknown tier field is refused")
	var missing_text := _copy(base)
	missing_text.erase("text")
	_check(not StitchedParts.validate_part(missing_text)["ok"], "validation: a part without rules text is refused")
	var unknown_field := _copy(base)
	unknown_field["sparkle"] = true
	_check(not StitchedParts.validate_part(unknown_field)["ok"], "validation: an unknown part field is refused")
	var missing_ability := _copy(base)
	missing_ability.erase("ability")
	_check(not StitchedParts.validate_part(missing_ability)["ok"], "validation: a part without an ability is refused")
	var bad_acc := _copy(base)
	bad_acc["ability"]["acc"] = 150
	_check(not StitchedParts.validate_part(bad_acc)["ok"], "validation: an ability ACC above 100 is refused")
	var mask := StitchedParts.rank_mask([1, 3])
	_check(mask == 0b01010, "validation: rank masks use one bit per rank")
	_check(StitchedParts.ranks_allowed(mask, 3) and not StitchedParts.ranks_allowed(mask, 2), "validation: rank masks answer legality")
	var tiers := StitchedParts.ability_at_tier(base, 3)
	_check(int(tiers["dmg"][1]) > int(base["ability"]["dmg"][1]), "validation: a tier III part raises its ability numbers")
	var stat_tiers := StitchedParts.stat_at_tier(_fixture_parts()[4], 2)
	_check(int(stat_tiers["max_hp"]) == 9, "validation: a tier II stat override replaces the base stat")


func _test_battle_validation() -> void:
	var three_heroes := _party().slice(0, 3)
	_check(not StitchedRules.create(_config(1, {"heroes": three_heroes}))["ok"], "validation: three heroes are refused")
	var five_heroes := _party() + [_party()[0].duplicate(true)]
	five_heroes[4]["id"] = "extra"
	_check(not StitchedRules.create(_config(1, {"heroes": five_heroes}))["ok"], "validation: five heroes are refused")
	_check(not StitchedRules.create(_config(1, {"foes": _three_foes().slice(0, 1)}))["ok"], "validation: a one-foe fight is refused")
	var duplicate_heroes := _party()
	duplicate_heroes[3] = duplicate_heroes[0].duplicate(true)
	_check(not StitchedRules.create(_config(1, {"heroes": duplicate_heroes}))["ok"], "validation: duplicate hero ids are refused")
	var missing_slot := _party()
	missing_slot[0] = missing_slot[0].duplicate(true)
	missing_slot[0]["parts"].erase("legs")
	_check(not StitchedRules.create(_config(1, {"heroes": missing_slot}))["ok"], "validation: a hero without four slots is refused")
	var unknown_part := _party()
	unknown_part[0] = unknown_part[0].duplicate(true)
	unknown_part[0]["parts"]["head"] = {"id": "no_such_part", "tier": 1}
	_check(not StitchedRules.create(_config(1, {"heroes": unknown_part}))["ok"], "validation: an unknown part id is refused")
	var bad_tier := _party()
	bad_tier[0] = bad_tier[0].duplicate(true)
	bad_tier[0]["parts"]["head"] = {"id": "warden_head_iron_helm", "tier": 4}
	_check(not StitchedRules.create(_config(1, {"heroes": bad_tier}))["ok"], "validation: an equipped tier above III is refused")
	var wrong_slot := _party()
	wrong_slot[0] = wrong_slot[0].duplicate(true)
	wrong_slot[0]["parts"]["arms"] = {"id": "warden_head_iron_helm", "tier": 1}
	_check(not StitchedRules.create(_config(1, {"heroes": wrong_slot}))["ok"], "validation: a head part in the arms slot is refused")
	var no_abilities := _three_foes()
	no_abilities[0] = no_abilities[0].duplicate(true)
	no_abilities[0]["abilities"] = []
	_check(not StitchedRules.create(_config(1, {"foes": no_abilities}))["ok"], "validation: a foe without abilities is refused")
	_check(not StitchedRules.create(_config("seven"))["ok"], "validation: a non-integer seed is refused")
	var bad_part := _fixture_parts()
	bad_part[0] = bad_part[0].duplicate(true)
	bad_part[0]["ability"]["target_side"] = "everyone"
	_check(not StitchedRules.create(_config(1, {"parts": bad_part}))["ok"], "validation: a malformed part blocks the battle")
	_check(not StitchedRules.create(_config(1, {"parts": []}))["ok"], "validation: an empty part catalog blocks the battle")


# ---------------------------------------------------------------- cycle 493 defect fixes

func _test_ac2_non_boss_two_turns() -> void:
	# Only a boss may take the two-turn exception.
	var two_turn := _three_foes()
	two_turn[0] = two_turn[0].duplicate(true)
	_check(not two_turn[0].has("is_boss") or not bool(two_turn[0]["is_boss"]), "AC2: the foe under test is not a boss")
	two_turn[0]["turns_per_round"] = 2
	var refused := StitchedRules.create(_config(5, {"foes": two_turn}))
	_check(not refused["ok"], "AC2: a non-boss foe with two turns is refused at construction")
	_check(refused["battle"] == null, "AC2: the refused non-boss build returns no battle")
	# A boss keeps its two turns, and ordinary foes still take exactly one.
	var boss := _battle(5, {"foes": _boss_foes()})
	if boss != null:
		_check(int(boss.get_unit("behemoth")["turns_per_round"]) == 2, "AC2: a boss keeps its two turns")
		_check(bool(boss.get_unit("behemoth")["is_boss"]), "AC2: the two-turn foe is authored as a boss")
		var counts := {}
		for unit_id in boss.turn_order():
			counts[unit_id] = int(counts.get(unit_id, 0)) + 1
		_check(int(counts.get("behemoth", 0)) == 2, "AC2: the two-turn boss appears twice in the round order")
		_check(int(counts.get("moth", 0)) == 1, "AC2: an ordinary foe rolls one turn")
		_check(int(counts.get("thimble", 0)) == 1, "AC2: every ordinary foe rolls one turn")


func _test_ac3_arm_damage_bonus() -> void:
	# The equipped arms' dmg stat is a flat bonus on a direct attack, before modifiers.
	var compared := false
	for seed_value in range(1, 60):
		var zero := _synthetic_battle(
			seed_value, _damage_test_party("test_head_plain", "test_arm_plain"), _weak_foes()
		)
		var two := _synthetic_battle(
			seed_value, _damage_test_party("test_head_plain", "test_arm_plus_two"), _weak_foes()
		)
		if zero == null or two == null:
			continue
		if not _drive_to(zero, "warden") or not _drive_to(two, "warden"):
			continue
		var plain_hit := zero.use_part("test_head_plain", 1)
		var bonus_hit := two.use_part("test_head_plain", 1)
		if not plain_hit["ok"] or not bonus_hit["ok"]:
			continue
		var plain_result: Dictionary = plain_hit["results"][0]
		var bonus_result: Dictionary = bonus_hit["results"][0]
		if not bool(plain_result["hit"]) or not bool(bonus_result["hit"]):
			continue
		compared = true
		_check(int(zero.get_unit("warden")["dmg_bonus"]) == 0, "AC3: a dmg 0 arm grants no attack bonus")
		_check(int(two.get_unit("warden")["dmg_bonus"]) == 2, "AC3: an arm's dmg stat is stored on the hero")
		_check(int(plain_result["damage"]) == 10, "AC3: a flat 10 hit with dmg 0 arms deals 10")
		_check(int(bonus_result["damage"]) == 12, "AC3: the dmg 2 arm adds +2 direct damage")
		break
	_check(compared, "AC3: a seeded fight compared dmg 0 arms with dmg 2 arms")
	# The same bonus applies inside the intended crit calculation.
	var crit_compared := false
	for seed_value in range(1, 60):
		var zero := _synthetic_battle(
			seed_value, _damage_test_party("test_head_crit", "test_arm_plain"), _weak_foes()
		)
		var two := _synthetic_battle(
			seed_value, _damage_test_party("test_head_crit", "test_arm_plus_two"), _weak_foes()
		)
		if zero == null or two == null:
			continue
		if not _drive_to(zero, "warden") or not _drive_to(two, "warden"):
			continue
		var plain_crit := zero.use_part("test_head_crit", 1)
		var bonus_crit := two.use_part("test_head_crit", 1)
		if not plain_crit["ok"] or not bonus_crit["ok"]:
			continue
		var plain_result: Dictionary = plain_crit["results"][0]
		var bonus_result: Dictionary = bonus_crit["results"][0]
		if not bool(plain_result["hit"]) or not bool(bonus_result["hit"]):
			continue
		if not bool(plain_result["crit"]) or not bool(bonus_result["crit"]):
			continue
		crit_compared = true
		_check(int(plain_result["damage"]) == 15, "AC3: a crit with dmg 0 arms deals 1.5x the maximum")
		_check(int(bonus_result["damage"]) == 17, "AC3: the arms dmg stat adds +2 inside a crit")
		break
	_check(crit_compared, "AC3: a seeded fight compared dmg 0 and dmg 2 arms on a guaranteed crit")


func _test_ac3_zero_damage_effects() -> void:
	# A confirmed enemy-target hit with dmg [0,0] must still apply its authored debuff.
	var applied := false
	var expired := false
	for seed_value in range(1, 120):
		var battle := _synthetic_battle(seed_value, [
			_synthetic_hero("warden", "test_head_zero_mark", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
			_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		], _weak_foes())
		if battle == null or not _drive_to(battle, "warden"):
			continue
		var foe_hp := int(battle.get_unit("foe_a")["hp"])
		var receipt := battle.use_part("test_head_zero_mark", 1)
		if not receipt["ok"] or not bool(receipt["results"][0]["hit"]):
			continue
		_check(int(receipt["results"][0]["damage"]) == 0, "AC3: a dmg 0 debuff deals no damage")
		_check(not bool(receipt["results"][0]["crit"]), "AC3: a dmg 0 debuff rolls no crit")
		_check(int(battle.get_unit("foe_a")["hp"]) == foe_hp, "AC3: the dmg 0 hit leaves the target HP unchanged")
		_check(int(battle.get_unit("foe_a")["statuses"].get("mark", 0)) == 2, "AC3: a dmg 0 hit still applies Mark 2")
		applied = true
		var steps := 0
		while int(battle.get_unit("foe_a")["statuses"].get("mark", 0)) > 0 \
				and not battle.is_over() and steps < 40:
			if not _act_for_current(battle)["ok"]:
				break
			steps += 1
		var mark_left := int(battle.get_unit("foe_a")["statuses"].get("mark", 0))
		_check(mark_left == 0, "AC3: a dmg 0 Mark expires on the foe's turns")
		expired = mark_left == 0
		break
	_check(applied, "AC3: a seeded fight landed a dmg 0 Marking hit")
	_check(expired, "AC3: a seeded fight showed the dmg 0 Mark expiring")


func _test_ac3_heap_blocks_compaction() -> void:
	var verified := false
	for seed_value in range(1, 60):
		var battle := _synthetic_battle(seed_value, _plain_party(), [
			_synthetic_foe("foe_a", 10),
			_synthetic_foe("foe_b", 10),
			_synthetic_foe("foe_c", 10),
		])
		if battle == null:
			continue
		if not _kill_foe_with_plain_arm(battle, "warden", "foe_a", 1):
			continue
		if not _kill_foe_with_plain_arm(battle, "warden", "foe_b", 2):
			continue
		if battle.get_heaps().size() != 2:
			continue
		if int(battle.get_unit("foe_c")["rank"]) != 3:
			continue
		verified = true
		_check(_clear_heap_at(battle, "warden", 1), "AC3: the front heap can be cleared")
		var after_front := battle.get_heaps()
		_check(after_front.size() == 1, "AC3: clearing the front heap leaves the second heap")
		if after_front.size() == 1:
			_check(int(after_front[0]["rank"]) == 2, "AC3: the uncleared heap still holds rank 2")
		_check(int(battle.get_unit("foe_c")["rank"]) == 3, "AC3: a foe behind a standing heap does not cross it")
		_check(_clear_heap_at(battle, "warden", 2), "AC3: the second heap can be cleared")
		_check(battle.get_heaps().is_empty(), "AC3: no heap remains after clearing both")
		_check(int(battle.get_unit("foe_c")["rank"]) == 1, "AC3: with both heaps gone the foe compacts forward")
		break
	_check(verified, "AC3: a seeded fight left heaps at ranks 1 and 2 with a living rank-3 foe")


func _test_ac3_self_move_preflight() -> void:
	# self_move -1 from rank 1 is off the board: refuse before any roll, state change or turn spend.
	var battle := _synthetic_battle(61, [
		_synthetic_hero("warden", "test_head_miss", "test_arm_plain", "test_torso_plain", "warden_legs_stride"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "warden_legs_stride"),
	], _weak_foes())
	if battle != null:
		_check(_drive_to(battle, "warden"), "AC3: the self-move battle reaches the front Warden")
		var before := _snapshot_text(battle)
		var off_board := battle.use_part("warden_legs_stride", 1)
		_check(not off_board["ok"], "AC3: a self_move step off the board is refused")
		_check(_snapshot_text(battle) == before, "AC3: a blocked self_move leaves state and RNG unchanged")
		_check(battle.current_actor_id() == "warden", "AC3: a blocked self_move does not spend the turn")
		# From rank 4 the same ability swaps with the ally in front.
		_check(_drive_to(battle, "monk"), "AC3: the self-move battle reaches the back Monk")
		var partner := ""
		for hero in battle.get_heroes():
			if int(hero["rank"]) == 3:
				partner = str(hero["id"])
		_check(int(battle.get_unit("monk")["rank"]) == 4, "AC3: the Monk stands in the back rank")
		_check(not partner.is_empty(), "AC3: an ally stands in front of the Monk")
		var shift := battle.use_part("warden_legs_stride", 4)
		_check(shift["ok"], "AC3: a legal self_move ability resolves")
		if shift["ok"]:
			_check(int(battle.get_unit("monk")["rank"]) == 3, "AC3: the self_move step lands one rank forward")
			_check(str(shift["self_move"].get("swapped", "")) == partner, "AC3: the step swaps with the ally in front")
			_check(int(battle.get_unit(partner)["rank"]) == 4, "AC3: the swapped ally takes the old rank")
	# A Tangled swap partner refuses the mandatory step.
	var tangled_partner := _synthetic_battle(62, [
		_synthetic_hero("warden", "test_head_miss", "test_arm_tangle", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "warden_legs_stride"),
	], _weak_foes())
	if tangled_partner != null:
		_check(_drive_to(tangled_partner, "warden"), "AC3: the tangled-partner battle reaches the Warden")
		var tangle := tangled_partner.use_part("test_arm_tangle", 3)
		_check(tangle["ok"], "AC3: an ally tangle applies")
		_check(int(tangled_partner.get_unit("tinker")["statuses"].get("tangled", 0)) == 3, "AC3: the ally is Tangled for three turns")
		_check(_drive_to(tangled_partner, "monk"), "AC3: the tangled-partner battle reaches the Monk")
		var tangled_before := _snapshot_text(tangled_partner)
		var blocked_swap := tangled_partner.use_part("warden_legs_stride", 4)
		_check(not blocked_swap["ok"], "AC3: a swap with a Tangled ally is refused")
		_check(_snapshot_text(tangled_partner) == tangled_before, "AC3: a Tangled swap refusal leaves state and RNG unchanged")
		_check(tangled_partner.current_actor_id() == "monk", "AC3: a Tangled swap refusal does not spend the turn")
	# A Tangled actor cannot self_move either.
	var tangled_actor := _synthetic_battle(63, [
		_synthetic_hero("warden", "test_head_miss", "test_arm_tangle", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("seamstress", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("tinker", "test_head_miss", "test_arm_plain", "test_torso_plain", "test_legs_plain"),
		_synthetic_hero("monk", "test_head_miss", "test_arm_plain", "test_torso_plain", "warden_legs_stride"),
	], _weak_foes())
	if tangled_actor != null:
		_check(_drive_to(tangled_actor, "warden"), "AC3: the tangled-actor battle reaches the Warden")
		var on_actor := tangled_actor.use_part("test_arm_tangle", 4)
		_check(on_actor["ok"], "AC3: the tangle lands on the Monk")
		_check(int(tangled_actor.get_unit("monk")["statuses"].get("tangled", 0)) == 3, "AC3: the Monk is Tangled for three turns")
		_check(_drive_to(tangled_actor, "monk"), "AC3: the tangled-actor battle reaches the Monk")
		var actor_before := _snapshot_text(tangled_actor)
		var blocked_shift := tangled_actor.use_part("warden_legs_stride", 4)
		_check(not blocked_shift["ok"], "AC3: a Tangled hero cannot self_move")
		_check(_snapshot_text(tangled_actor) == actor_before, "AC3: a Tangled self_move refusal leaves state and RNG unchanged")
		_check(tangled_actor.current_actor_id() == "monk", "AC3: a Tangled self_move refusal does not spend the turn")


func _test_ac4_boss_retreat_after_death() -> void:
	var verified := false
	for seed_value in range(1, 60):
		var battle := _synthetic_battle(seed_value, _plain_party(), [
			_synthetic_foe("behemoth", 10, 2, 0, 0, [1, 1], 100, true, 2),
			_synthetic_foe("foe_b", 30),
		])
		if battle == null or not battle.is_boss_encounter():
			continue
		if not _kill_foe_with_plain_arm(battle, "warden", "behemoth", 1):
			continue
		if battle.is_over() or not _drive_to_side(battle, "hero"):
			continue
		verified = true
		_check(bool(battle.get_unit("behemoth")["dead"]), "AC4: the boss is dead while a minion still fights")
		_check(not battle.is_over(), "AC4: the fight continues after the boss dies")
		_check(battle.is_boss_encounter(), "AC4: the battle remembers it is a boss encounter")
		var living_boss := false
		for foe in battle.get_foes():
			if bool(foe["is_boss"]) and not bool(foe["dead"]) and int(foe["hp"]) > 0:
				living_boss = true
		_check(not living_boss, "AC4: no living boss remains to justify the old retreat check")
		var before := _snapshot_text(battle)
		var refused := battle.retreat()
		_check(not refused["ok"], "AC4: a boss encounter refuses retreat after the boss dies")
		_check(_snapshot_text(battle) == before, "AC4: the refused retreat leaves state and RNG unchanged")
		_check(battle.current_side() == "hero", "AC4: the refused retreat does not spend the hero's turn")
		break
	_check(verified, "AC4: a seeded boss fight killed the boss with a minion alive")
