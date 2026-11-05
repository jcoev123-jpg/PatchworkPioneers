extends SceneTree
## Design v4 (Stitched) S3-prep data contract: the authored enemy droppable part slice.
##
## Parses res://data/parts/enemy_parts.json (a version-1 {"parts": [...]} catalog shaped like
## tests/fixtures/stitched_s1a_parts.json) and cross-checks it against the stable enemy roster in
## res://data/enemies/run_enemies.json. This is pure data checking: it builds no battle, imports no
## S1b rules and mounts no S2 screen, so it stays valid before the S3 drop/reward wiring lands.
##
## Records are found by named id, and no total or ordered list of the catalog is asserted, so later
## drop parts may be appended without breaking this test. Every appended entry still has to satisfy
## the same schema and uniqueness checks, which run over the whole file.

const PARTS_PATH := "res://data/parts/enemy_parts.json"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"

const SLOTS := ["head", "arms", "torso", "legs"]
const STAT_KEYS := ["acc", "crit", "dmg", "max_hp", "prot", "speed", "dodge"]
## Design v4: arms add damage; torso adds max HP or PROT; legs add SPEED or DODGE; head adds ACC or CRIT.
const SLOT_STATS := {
	"head": ["acc", "crit"],
	"arms": ["dmg"],
	"torso": ["max_hp", "prot"],
	"legs": ["speed", "dodge"],
}
const ABILITY_KINDS := ["melee", "ranged", "heal", "guard", "buff", "debuff", "move"]
const TARGET_SIDES := ["enemy", "ally", "self"]
const MOVE_POSES := ["attack", "attack2", "guard", "skill"]
const PART_FIELDS := ["id", "name", "slot", "owner", "stat", "ability", "tiers", "text"]
const ABILITY_FIELDS := [
	"id", "name", "kind", "launch", "target", "target_side", "multi", "acc", "dmg",
	"crit", "mark_damage", "effects", "self_move", "move",
]
## mark_damage is optional authored data (the S1a fixture only sets it where a mark bonus exists).
const REQUIRED_ABILITY_FIELDS := [
	"id", "name", "kind", "launch", "target", "target_side", "multi", "acc", "dmg",
	"crit", "effects", "self_move", "move",
]
const MIN_RANK := 1
const MAX_RANK := 4

## The three parts this slice asks for, keyed by part id (never a catalog total).
const EXPECTED_PARTS := {
	"scissor_crab_claw_arm": {
		"enemy": "scissor_crab",
		"name": "Scissor Claw",
		"slot": "arms",
		"ability": "snip",
		"ability_name": "Snip",
		"text": "Clip a front foe and open a bleeding seam.",
	},
	"moth_swarm_wings": {
		"enemy": "moth_swarm",
		"name": "Tatter Wings",
		"slot": "legs",
		"ability": "flutter_back",
		"ability_name": "Flutter Back",
		"text": "Flutter one rank back and briefly gain Dodge.",
	},
	"felt_bulwark_button_shield": {
		"enemy": "felt_bulwark",
		"name": "Button Shield Torso",
		"slot": "torso",
		"ability": "button_shield",
		"ability_name": "Button Shield",
		"text": "Take the hits meant for one ally behind your shield.",
	},
}

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var parts := _load_parts()
	if not parts.is_empty():
		var by_id := _index_and_validate(parts)
		var roster := _load_enemy_roster()
		_test_ac1_membership(by_id, roster)
		_test_ac2_ranks_and_behaviour(by_id)
		_test_ac3_tiers(by_id)
		_test_lint_gland_all_enemy_ranks()
	if _failures.is_empty():
		print("stitched_enemy_parts_catalog_test: PASS (", _checks, " checks)")
	else:
		for failure in _failures:
			printerr(failure)
		print("stitched_enemy_parts_catalog_test: FAIL (", _failures.size(), " failures)")
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# ---------------------------------------------------------------- loading

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_check(false, "missing data file: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_check(false, "empty data file: " + path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_check(false, "unparsable JSON: " + path)
		return null
	return parsed


func _load_parts() -> Array:
	var parsed: Variant = _read_json(PARTS_PATH)
	if not parsed is Dictionary:
		_check(false, "enemy parts file is not a JSON object")
		return []
	var document: Dictionary = parsed
	if not document.has("version"):
		_check(false, "enemy parts file has no version")
	elif not _is_int(document["version"]) or int(document["version"]) != 1:
		_check(false, "enemy parts file is not version 1: " + str(document["version"]))
	if not document.has("parts"):
		_check(false, "enemy parts file has no parts array")
		return []
	if not document["parts"] is Array:
		_check(false, "enemy parts file parts field is not an array")
		return []
	var parts: Array = document["parts"]
	_check(not parts.is_empty(), "enemy parts file authors at least one part")
	return parts


func _load_enemy_roster() -> Dictionary:
	var parsed: Variant = _read_json(ENEMIES_PATH)
	if not parsed is Array:
		_check(false, "enemy roster is not a JSON array")
		return {}
	var roster: Dictionary = {}
	var entries: Array = parsed
	for entry in entries:
		if entry is Dictionary and entry.get("id") is String:
			roster[str(entry["id"])] = entry
	_check(not roster.is_empty(), "enemy roster authors at least one enemy")
	return roster


# ---------------------------------------------------------------- whole-file schema

## Indexes the catalog by part id and validates every entry, so appended drops stay schema-clean.
func _index_and_validate(parts: Array) -> Dictionary:
	var by_id: Dictionary = {}
	var names: Dictionary = {}
	var ability_ids: Dictionary = {}
	for index in range(parts.size()):
		var label := "part %d" % index
		var raw: Variant = parts[index]
		if not raw is Dictionary:
			_check(false, label + " is not a JSON object")
			continue
		var part: Dictionary = raw
		_validate_part(part, label)
		var id := str(part.get("id", ""))
		if id.is_empty():
			continue
		if by_id.has(id):
			_check(false, "duplicate part id in the catalog: " + id)
			continue
		by_id[id] = part
		var part_name := str(part.get("name", ""))
		if names.has(part_name):
			_check(false, "duplicate part name in the catalog: " + part_name)
		names[part_name] = true
		var ability: Variant = part.get("ability")
		if ability is Dictionary:
			var ability_id := str(ability.get("id", ""))
			if ability_ids.has(ability_id):
				_check(false, "duplicate ability id in the catalog: " + ability_id)
			ability_ids[ability_id] = true
	return by_id


func _validate_part(part: Dictionary, label: String) -> void:
	for field in PART_FIELDS:
		_check(part.has(field), label + " is missing required field: " + field)
	for field in part:
		if not field is String or not field in PART_FIELDS:
			_check(false, label + " has an unknown field: " + str(field))
	var id: Variant = part.get("id")
	_check(id is String and not str(id).strip_edges().is_empty(), label + " needs a nonempty id")
	var name: Variant = part.get("name")
	_check(name is String and not str(name).strip_edges().is_empty(), label + " needs a nonempty name")
	var slot: Variant = part.get("slot")
	var slot_name := str(slot)
	_check(slot is String and slot_name in SLOTS, label + " has an illegal slot: " + slot_name)
	var owner: Variant = part.get("owner")
	_check(owner is String and not str(owner).strip_edges().is_empty(),
		label + " needs an owner id or any")
	var text: Variant = part.get("text")
	_check(text is String and not str(text).strip_edges().is_empty(), label + " needs rules text")
	_validate_stat(part.get("stat"), slot_name, label)
	_validate_ability(part.get("ability"), label + " ability", false)
	_validate_tiers(part.get("tiers"), slot_name, label)


func _validate_stat(value: Variant, slot: String, label: String) -> void:
	if not value is Dictionary:
		_check(false, label + " stat is not a JSON object")
		return
	var stat: Dictionary = value
	var allowed: Array = SLOT_STATS.get(slot, [])
	for key in stat:
		if not key is String:
			_check(false, label + " has a non-string stat key")
			continue
		var key_name := str(key)
		_check(key_name in STAT_KEYS, label + " has an unknown stat: " + key_name)
		_check(allowed.is_empty() or key_name in allowed,
			"%s cannot grant %s in the %s slot" % [label, key_name, slot])
		_check(_is_int(stat[key]) and int(stat[key]) >= 0,
			label + " stat " + key_name + " must be a nonnegative integer")


func _validate_ability(value: Variant, label: String, partial: bool) -> void:
	if not value is Dictionary:
		_check(false, label + " is not a JSON object")
		return
	var ability: Dictionary = value
	if not partial:
		for field in REQUIRED_ABILITY_FIELDS:
			_check(ability.has(field), label + " is missing required field: " + field)
	for field in ability:
		if not field is String or not field in ABILITY_FIELDS:
			_check(false, label + " has an unknown field: " + str(field))
	if ability.has("id"):
		_check(ability["id"] is String and not str(ability["id"]).strip_edges().is_empty(),
			label + " needs a nonempty id")
	if ability.has("name"):
		_check(ability["name"] is String and not str(ability["name"]).strip_edges().is_empty(),
			label + " needs a nonempty name")
	if ability.has("kind"):
		_check(ability["kind"] is String and str(ability["kind"]) in ABILITY_KINDS,
			label + " has an illegal kind: " + str(ability.get("kind")))
	for field in ["launch", "target"]:
		if ability.has(field):
			_check(_valid_ranks(ability[field]),
				label + " " + str(field) + " must be unique ranks 1-4")
	if ability.has("target_side"):
		_check(ability["target_side"] is String and str(ability["target_side"]) in TARGET_SIDES,
			label + " has an illegal target_side: " + str(ability.get("target_side")))
	if ability.has("multi"):
		_check(typeof(ability["multi"]) == TYPE_BOOL, label + " multi must be a boolean")
	if ability.has("acc"):
		_check(_is_int(ability["acc"]) and int(ability["acc"]) >= 0 and int(ability["acc"]) <= 100,
			label + " needs acc 0-100")
	if ability.has("dmg"):
		_check(_valid_range(ability["dmg"]),
			label + " needs a dmg [min, max] pair with 0 <= min <= max")
	if ability.has("crit"):
		_check(_is_int(ability["crit"]) and int(ability["crit"]) >= 0,
			label + " crit must be a nonnegative integer")
	if ability.has("mark_damage"):
		_check(_is_int(ability["mark_damage"]) and int(ability["mark_damage"]) >= 0,
			label + " mark_damage must be a nonnegative integer")
	if ability.has("effects"):
		_check(_valid_effects(ability["effects"]),
			label + " effects must be nonnegative integer values")
	if ability.has("self_move"):
		_check(_is_int(ability["self_move"]) and int(ability["self_move"]) >= -1
			and int(ability["self_move"]) <= 1, label + " self_move must be -1, 0 or 1")
	if ability.has("move"):
		_check(ability["move"] is String and str(ability["move"]) in MOVE_POSES,
			label + " has an unknown move pose: " + str(ability.get("move")))


func _validate_tiers(value: Variant, slot: String, label: String) -> void:
	if not value is Dictionary:
		_check(false, label + " tiers is not a JSON object")
		return
	var tiers: Dictionary = value
	for key in tiers:
		if not key is String or not str(key) in ["2", "3"]:
			_check(false, label + " has an illegal tier key: " + str(key))
			continue
		var tier_label := label + " tier " + str(key)
		var override: Variant = tiers[key]
		if not override is Dictionary:
			_check(false, tier_label + " is not a JSON object")
			continue
		var fields: Dictionary = override
		_check(not fields.is_empty(), tier_label + " must override something")
		for field in fields:
			if not field is String or not field in ["stat", "ability", "text"]:
				_check(false, tier_label + " has an unknown field: " + str(field))
		if fields.has("stat"):
			_validate_stat(fields["stat"], slot, tier_label)
		if fields.has("ability"):
			_validate_ability(fields["ability"], tier_label + " ability", true)
		if fields.has("text"):
			_check(fields["text"] is String and not str(fields["text"]).strip_edges().is_empty(),
				tier_label + " text must be nonempty")


# ---------------------------------------------------------------- AC1: themed drop membership

func _test_ac1_membership(by_id: Dictionary, roster: Dictionary) -> void:
	var seen_names: Dictionary = {}
	var seen_abilities: Dictionary = {}
	for part_id in EXPECTED_PARTS:
		var spec: Dictionary = EXPECTED_PARTS[part_id]
		var enemy_id := str(spec["enemy"])
		_check(roster.has(enemy_id), "AC1: the enemy roster still lists " + enemy_id)
		var part := _required_part(by_id, part_id)
		if part.is_empty():
			continue
		_check(str(part.get("owner", "")) == "any",
			"AC1: " + part_id + " is owner any, so any hero can wear it")
		_check(str(part.get("slot", "")) == str(spec["slot"]),
			"AC1: " + part_id + " fills the " + str(spec["slot"]) + " slot")
		_check(str(part.get("name", "")) == str(spec["name"]),
			"AC1: " + part_id + " is named " + str(spec["name"]))
		_check(str(part.get("text", "")) == str(spec["text"]),
			"AC1: " + part_id + " carries its authored rules text")
		_check(part_id.begins_with(enemy_id + "_"),
			"AC1: " + part_id + " uses its source enemy id as the id prefix")
		var part_name := str(part.get("name", ""))
		_check(not seen_names.has(part_name),
			"AC1: the part name " + part_name + " stays unique in this slice")
		seen_names[part_name] = true
		var ability: Variant = part.get("ability")
		_check(ability is Dictionary,
			"AC1: " + part_id + " grants exactly one ability record, not a list")
		if not ability is Dictionary:
			continue
		var ability_record: Dictionary = ability
		var ability_id := str(ability_record.get("id", ""))
		_check(ability_id == str(spec["ability"]),
			"AC1: " + part_id + " grants the ability " + str(spec["ability"]))
		_check(str(ability_record.get("name", "")) == str(spec["ability_name"]),
			"AC1: " + part_id + " names its ability " + str(spec["ability_name"]))
		_check(not seen_abilities.has(ability_id),
			"AC1: the ability id " + ability_id + " stays unique in this slice")
		seen_abilities[ability_id] = true
	_check(seen_names.size() == EXPECTED_PARTS.size(), "AC1: the three part names are distinct")
	_check(seen_abilities.size() == EXPECTED_PARTS.size(), "AC1: the three ability ids are distinct")


# ---------------------------------------------------------------- AC2: ranks and look-driven behaviour

func _test_ac2_ranks_and_behaviour(by_id: Dictionary) -> void:
	var claw := _required_part(by_id, "scissor_crab_claw_arm")
	var wings := _required_part(by_id, "moth_swarm_wings")
	var shield := _required_part(by_id, "felt_bulwark_button_shield")

	# Scissor Crab: crossed metal pincers, +1 damage arm with a bleeding clip.
	_check_stat(claw, {"dmg": 1}, "AC2: Scissor Claw adds +1 damage")
	_check_ability(claw, {
		"id": "snip",
		"name": "Snip",
		"kind": "melee",
		"launch": [1, 2],
		"target": [1, 2],
		"target_side": "enemy",
		"multi": false,
		"acc": 90,
		"dmg": [4, 7],
		"crit": 0,
		"effects": {"bleed": 2},
		"self_move": 0,
		"move": "attack",
	}, "AC2: Snip is an ACC-90 melee hit on enemy ranks 1-2")
	var snip := _ability_of(claw)
	var snip_effects := _int_dict(snip.get("effects", {}))
	_check(snip_effects.has("bleed"), "AC2: Snip opens a Bleed")
	_check(not snip_effects.has("snip") and not snip_effects.has("tear"),
		"AC2: Snip is a foe-hitting bleed skill, not the enemy's thread-cutting snip_block intent")

	# Moth Swarm: ragged wings, +5 Dodge legs that flutter one rank back.
	_check_stat(wings, {"dodge": 5}, "AC2: Tatter Wings adds 5 Dodge")
	_check_ability(wings, {
		"id": "flutter_back",
		"name": "Flutter Back",
		"kind": "move",
		"launch": [1, 2, 3],
		"target": [1, 2, 3],
		"target_side": "self",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"dodge": 5, "duration": 1},
		"self_move": 1,
		"move": "skill",
	}, "AC2: Flutter Back is a self move from ranks 1-3")
	var flutter := _ability_of(wings)
	var flutter_launch := _int_list(flutter.get("launch", []))
	_check(flutter_launch.has(MIN_RANK) and flutter_launch.has(2) and flutter_launch.has(3),
		"AC2: Flutter Back launches from ranks 1-3")
	_check(not (MAX_RANK in flutter_launch),
		"AC2: Flutter Back never launches from rank 4, where there is no rank behind")
	_check(int(flutter.get("self_move", 0)) == 1,
		"AC2: Flutter Back moves the wearer one rank back (rank number rises toward 4)")
	_check(int(_int_dict(flutter.get("effects", {})).get("duration", 0)) == 1,
		"AC2: the Flutter Dodge lasts until the wearer's next turn")
	_check(_int_list(flutter.get("target", [])) == [1, 2, 3],
		"AC2: Flutter Back targets the wearer's own rank range, not a foe")

	# Felt Bulwark: oversized button shield over a stuffed torso, +10 PROT guard.
	_check_stat(shield, {"prot": 10}, "AC2: Button Shield Torso adds 10 PROT")
	_check_ability(shield, {
		"id": "button_shield",
		"name": "Button Shield",
		"kind": "guard",
		"launch": [1, 2],
		"target": [1, 2, 3, 4],
		"target_side": "ally",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"guard": 2},
		"self_move": 0,
		"move": "guard",
	}, "AC2: Button Shield is a Guard on one ally in ranks 1-4")
	var button := _ability_of(shield)
	var guard_effects := _int_dict(button.get("effects", {}))
	_check(JSON.stringify(guard_effects) == JSON.stringify({"guard": 2}),
		"AC2: Button Shield Guards its chosen ally for two turns")
	_check(not guard_effects.has("block"),
		"AC2: Button Shield uses Guard, not the retired card Block resource")
	_check(_int_list(button.get("target", [])) == [1, 2, 3, 4],
		"AC2: Button Shield can cover an ally standing in any rank 1-4")
	_check(str(button.get("target_side", "")) == "ally",
		"AC2: Button Shield redirects onto the wearer without a self-target hack")


# ---------------------------------------------------------------- AC3: three stitch tiers

func _test_ac3_tiers(by_id: Dictionary) -> void:
	var claw := _required_part(by_id, "scissor_crab_claw_arm")
	var wings := _required_part(by_id, "moth_swarm_wings")
	var shield := _required_part(by_id, "felt_bulwark_button_shield")

	_check_tier_shape(claw, "AC3: Scissor Claw")
	_check_tier_shape(wings, "AC3: Tatter Wings")
	_check_tier_shape(shield, "AC3: Button Shield Torso")

	# Scissor Claw: damage [5,8] and Bleed 3 at tier II, [6,9] and Bleed 4 at tier III.
	_check_tier_ability(claw, 2, {
		"id": "snip",
		"name": "Snip",
		"kind": "melee",
		"launch": [1, 2],
		"target": [1, 2],
		"target_side": "enemy",
		"multi": false,
		"acc": 90,
		"dmg": [5, 8],
		"crit": 0,
		"effects": {"bleed": 3},
		"self_move": 0,
		"move": "attack",
	}, "AC3: Scissor Claw tier II")
	_check_tier_ability(claw, 3, {
		"id": "snip",
		"name": "Snip",
		"kind": "melee",
		"launch": [1, 2],
		"target": [1, 2],
		"target_side": "enemy",
		"multi": false,
		"acc": 90,
		"dmg": [6, 9],
		"crit": 0,
		"effects": {"bleed": 4},
		"self_move": 0,
		"move": "attack",
	}, "AC3: Scissor Claw tier III")
	_check_tier_stat(claw, 2, {"dmg": 1}, "AC3: Scissor Claw keeps +1 damage")
	_check_tier_stat(claw, 3, {"dmg": 1}, "AC3: Scissor Claw keeps +1 damage")

	# Tatter Wings: stat and temporary Dodge rise to 7 at tier II and 10 at tier III.
	_check_tier_stat(wings, 2, {"dodge": 7}, "AC3: Tatter Wings")
	_check_tier_stat(wings, 3, {"dodge": 10}, "AC3: Tatter Wings")
	_check_tier_ability(wings, 2, {
		"id": "flutter_back",
		"name": "Flutter Back",
		"kind": "move",
		"launch": [1, 2, 3],
		"target": [1, 2, 3],
		"target_side": "self",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"dodge": 7, "duration": 1},
		"self_move": 1,
		"move": "skill",
	}, "AC3: Tatter Wings tier II")
	_check_tier_ability(wings, 3, {
		"id": "flutter_back",
		"name": "Flutter Back",
		"kind": "move",
		"launch": [1, 2, 3],
		"target": [1, 2, 3],
		"target_side": "self",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"dodge": 10, "duration": 1},
		"self_move": 1,
		"move": "skill",
	}, "AC3: Tatter Wings tier III")

	# Button Shield Torso: PROT rises to 12 and Guard to 3 at tier II, 15 and 4 at tier III.
	_check_tier_stat(shield, 2, {"prot": 12}, "AC3: Button Shield Torso")
	_check_tier_stat(shield, 3, {"prot": 15}, "AC3: Button Shield Torso")
	_check_tier_ability(shield, 2, {
		"id": "button_shield",
		"name": "Button Shield",
		"kind": "guard",
		"launch": [1, 2],
		"target": [1, 2, 3, 4],
		"target_side": "ally",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"guard": 3},
		"self_move": 0,
		"move": "guard",
	}, "AC3: Button Shield Torso tier II")
	_check_tier_ability(shield, 3, {
		"id": "button_shield",
		"name": "Button Shield",
		"kind": "guard",
		"launch": [1, 2],
		"target": [1, 2, 3, 4],
		"target_side": "ally",
		"multi": false,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"guard": 4},
		"self_move": 0,
		"move": "guard",
	}, "AC3: Button Shield Torso tier III")

	# Legal metadata: each higher tier really raises its named numbers.
	_check_growth("AC3: Scissor Claw", "damage maximum",
		[_dmg_max(claw, 1), _dmg_max(claw, 2), _dmg_max(claw, 3)])
	_check_growth("AC3: Scissor Claw", "Bleed",
		[_effect_value(claw, 1, "bleed"), _effect_value(claw, 2, "bleed"),
			_effect_value(claw, 3, "bleed")])
	_check_growth("AC3: Tatter Wings", "DODGE stat",
		[_stat_value(wings, 1, "dodge"), _stat_value(wings, 2, "dodge"),
			_stat_value(wings, 3, "dodge")])
	_check_growth("AC3: Tatter Wings", "temporary Dodge",
		[_effect_value(wings, 1, "dodge"), _effect_value(wings, 2, "dodge"),
			_effect_value(wings, 3, "dodge")])
	_check_growth("AC3: Button Shield Torso", "PROT",
		[_stat_value(shield, 1, "prot"), _stat_value(shield, 2, "prot"),
			_stat_value(shield, 3, "prot")])
	_check_growth("AC3: Button Shield Torso", "Guard",
		[_effect_value(shield, 1, "guard"), _effect_value(shield, 2, "guard"),
			_effect_value(shield, 3, "guard")])
	_check_damage_ranges(claw, "AC3: Scissor Claw")
	_check_damage_ranges(wings, "AC3: Tatter Wings")
	_check_damage_ranges(shield, "AC3: Button Shield Torso")


## Tier I is the base record; tiers II and III are partial overrides that never restate identity.
func _check_tier_shape(part: Dictionary, label: String) -> void:
	var part_id := str(part.get("id", "?"))
	for tier in [2, 3]:
		var override := _tier_override(part, tier)
		_check(not override.is_empty(),
			"%s (%s) authors a tier %d override" % [label, part_id, tier])
		var fields: Variant = override.get("ability")
		if fields is Dictionary:
			var ability_fields: Dictionary = fields
			for identity in ["id", "name", "kind", "launch", "target", "target_side"]:
				_check(not ability_fields.has(identity),
					"%s (%s) tier %d is a partial ability override, not a full copy"
						% [label, part_id, tier])
	var tiers: Variant = part.get("tiers")
	if tiers is Dictionary:
		var authored_tiers: Dictionary = tiers
		_check(not authored_tiers.has("1"),
			"%s (%s) keeps tier I in the base fields" % [label, part_id])


func _check_tier_ability(part: Dictionary, tier: int, expected: Dictionary, label: String) -> void:
	_check(not _tier_override(part, tier).is_empty(),
		label + ": expected an authored tier " + str(tier) + " override")
	var record := _effective_ability(part, tier)
	if record.is_empty():
		_check(false, label + ": expected an ability at tier " + str(tier))
		return
	_check_ability_values(record, expected, label + " at tier " + str(tier))


func _check_tier_stat(part: Dictionary, tier: int, expected: Dictionary, label: String) -> void:
	var stat := _effective_stat(part, tier)
	_check(JSON.stringify(stat) == JSON.stringify(_int_dict(expected)),
		"%s: tier %d stat expected %s, found %s" % [label, tier, str(expected), str(stat)])


func _check_growth(label: String, name: String, values: Array) -> void:
	for index in range(1, values.size()):
		_check(int(values[index]) > int(values[index - 1]),
			"%s: %s must rise each tier (%s)" % [label, name, str(values)])


func _check_damage_ranges(part: Dictionary, label: String) -> void:
	var previous_min := 0
	var previous_max := 0
	for tier in [1, 2, 3]:
		var dmg := _int_list(_effective_ability(part, tier).get("dmg", []))
		_check(dmg.size() == 2 and int(dmg[0]) >= 0 and int(dmg[1]) >= int(dmg[0]),
			"%s: tier %d needs a nondecreasing dmg [min, max]" % [label, tier])
		if dmg.size() != 2:
			return
		_check(int(dmg[0]) >= previous_min and int(dmg[1]) >= previous_max,
			"%s: tier %d damage must not fall below the previous tier" % [label, tier])
		previous_min = int(dmg[0])
		previous_max = int(dmg[1])


# ---------------------------------------------------------------- Thread Biter Lint Gland

## The Lint Gland's Lint Spit exposes a foe in any enemy rank 1-4, while the wearer may still
## cast it only from the outer hero ranks 1 and 4. The part comes from the same real
## StitchedParts catalog the live battle wiring consumes, and every stitch tier is checked.
func _test_lint_gland_all_enemy_ranks() -> void:
	var catalog := StitchedParts.load_catalog(PARTS_PATH)
	_check(bool(catalog.get("ok", false)),
		"Lint Gland AC1: the real StitchedParts catalog loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	_check(by_id.has("thread_biter_lint_gland"),
		"Lint Gland AC1: the real catalog contains thread_biter_lint_gland")
	if not by_id.has("thread_biter_lint_gland"):
		return
	var part: Dictionary = by_id["thread_biter_lint_gland"]
	_check(str(part.get("id", "")) == "thread_biter_lint_gland",
		"Lint Gland AC1: the named part keeps its id")
	_check(str(part.get("owner", "")) == "any",
		"Lint Gland AC1: the Lint Gland is owner any, so any hero can wear it")
	_check(str(part.get("slot", "")) == "head",
		"Lint Gland AC1: the Lint Gland fills the head slot")
	_check(str(part.get("name", "")) == "Lint Gland",
		"Lint Gland AC1: the part is named Lint Gland")
	_check(str(part.get("text", "")) == "Spit a wad of lint that leaves any rank Exposed 2.",
		"Lint Gland AC1: the rules text still promises any rank")

	for tier in [1, 2, 3]:
		var label := "Lint Gland tier " + str(tier)
		var ability := StitchedParts.ability_at_tier(part, tier)
		var stat := StitchedParts.stat_at_tier(part, tier)
		_check(not ability.is_empty(), label + ": resolves an ability")
		if ability.is_empty():
			continue
		var target := _int_list(ability.get("target", []))
		_check(target == [1, 2, 3, 4], label + ": target is exactly enemy ranks 1-4")
		var target_mask := int(ability.get("target_mask", 0))
		_check(target_mask == StitchedParts.rank_mask([1, 2, 3, 4]),
			label + ": the target mask marks enemy ranks 1-4")
		for rank in [1, 2, 3, 4]:
			_check(StitchedParts.ranks_allowed(target_mask, rank),
				label + ": a foe in rank " + str(rank) + " may be targeted")
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(target_mask, rank),
				label + ": rank " + str(rank) + " is never a legal target")
		var launch := _int_list(ability.get("launch", []))
		_check(launch == [1, 4], label + ": launch stays exactly ranks 1 and 4")
		var launch_mask := int(ability.get("launch_mask", 0))
		_check(launch_mask == StitchedParts.rank_mask([1, 4]),
			label + ": the launch mask marks only ranks 1 and 4")
		for rank in [1, 4]:
			_check(StitchedParts.ranks_allowed(launch_mask, rank),
				label + ": the wearer may cast from rank " + str(rank))
		for rank in [0, 2, 3, 5]:
			_check(not StitchedParts.ranks_allowed(launch_mask, rank),
				label + ": the wearer may not cast from rank " + str(rank))
		_check(str(ability.get("id", "")) == "lint_spit", label + ": ability id stays lint_spit")
		_check(str(ability.get("kind", "")) == "debuff", label + ": Lint Spit stays a debuff")
		_check(str(ability.get("target_side", "")) == "enemy",
			label + ": Lint Spit still targets foes")
		_check(typeof(ability.get("multi")) == TYPE_BOOL and not bool(ability["multi"]),
			label + ": Lint Spit stays single-target")
		_check(int(ability.get("acc", -1)) == 88, label + ": Lint Spit keeps ACC 88")
		_check(_int_list(ability.get("dmg", [])) == [0, 0],
			label + ": Lint Spit deals no direct damage")
		_check(int(ability.get("crit", -1)) == 0, label + ": Lint Spit keeps crit 0")
		_check(int(ability.get("self_move", -1)) == 0,
			label + ": Lint Spit never moves the wearer")
		_check(str(ability.get("move", "")) == "skill", label + ": Lint Spit keeps the skill pose")
		var effects := _int_dict(ability.get("effects", {}))
		var exposed: int = 2 + (int(tier) - 1)
		_check(JSON.stringify(effects) == JSON.stringify({"exposed": exposed}),
			"%s: effects are exactly Exposed %d" % [label, exposed])
		_check(_int_dict(stat) == {"acc": 2 + tier},
			"%s: head stat is ACC %d" % [label, 2 + tier])


# ---------------------------------------------------------------- record helpers

func _required_part(by_id: Dictionary, part_id: String) -> Dictionary:
	if not by_id.has(part_id):
		_check(false, "enemy parts catalog is missing the required part: " + part_id)
		return {}
	var part: Variant = by_id[part_id]
	return part if part is Dictionary else {}


func _ability_of(part: Dictionary) -> Dictionary:
	var ability: Variant = part.get("ability")
	return ability if ability is Dictionary else {}


func _check_stat(part: Dictionary, expected: Dictionary, label: String) -> void:
	if not part.get("stat") is Dictionary:
		_check(false, label + ": " + str(part.get("id", "?")) + " has no stat record")
		return
	var actual := _int_dict(part["stat"])
	_check(JSON.stringify(actual) == JSON.stringify(_int_dict(expected)),
		"%s: expected %s, found %s" % [label, str(expected), str(actual)])


func _check_ability(part: Dictionary, expected: Dictionary, label: String) -> void:
	var record := _ability_of(part)
	if record.is_empty():
		_check(false, label + ": " + str(part.get("id", "?")) + " has no ability record")
		return
	_check_ability_values(record, expected, label)


func _check_ability_values(record: Dictionary, expected: Dictionary, label: String) -> void:
	for field in expected:
		if not record.has(field):
			_check(false, label + ": ability is missing " + str(field))
			continue
		var actual: Variant = record[field]
		match str(field):
			"launch", "target", "dmg":
				_check(JSON.stringify(_int_list(actual)) == JSON.stringify(_int_list(expected[field])),
					"%s: %s expected %s, found %s"
						% [label, field, str(expected[field]), str(actual)])
			"effects":
				_check(JSON.stringify(_int_dict(actual)) == JSON.stringify(_int_dict(expected[field])),
					"%s: %s expected %s, found %s"
						% [label, field, str(expected[field]), str(actual)])
			"multi":
				_check(typeof(actual) == TYPE_BOOL and bool(actual) == bool(expected[field]),
					"%s: multi expected %s, found %s"
						% [label, str(expected[field]), str(actual)])
			"acc", "crit", "self_move", "mark_damage":
				_check(_is_int(actual) and int(actual) == int(expected[field]),
					"%s: %s expected %s, found %s"
						% [label, field, str(expected[field]), str(actual)])
			_:
				_check(actual is String and str(actual) == str(expected[field]),
					"%s: %s expected %s, found %s"
						% [label, field, str(expected[field]), str(actual)])


func _tier_override(part: Dictionary, tier: int) -> Dictionary:
	var tiers: Variant = part.get("tiers")
	if not tiers is Dictionary:
		return {}
	var authored_tiers: Dictionary = tiers
	if not authored_tiers.has(str(tier)):
		return {}
	var override: Variant = authored_tiers[str(tier)]
	return override if override is Dictionary else {}


## The same tier I base + partial tier override merge a shipped consumer performs, without
## importing the S1b battle rules (this lane is data-only).
func _effective_ability(part: Dictionary, tier: int) -> Dictionary:
	var ability := _ability_of(part).duplicate(true)
	if tier <= 1:
		return ability
	var fields: Variant = _tier_override(part, tier).get("ability")
	if not fields is Dictionary:
		return ability
	var overrides: Dictionary = fields
	for field in overrides:
		var value: Variant = overrides[field]
		if value is Array or value is Dictionary:
			ability[field] = value.duplicate(true)
		else:
			ability[field] = value
	return ability


func _effective_stat(part: Dictionary, tier: int) -> Dictionary:
	var stat := _int_dict(part.get("stat", {}))
	if tier <= 1:
		return stat
	var fields: Variant = _tier_override(part, tier).get("stat")
	if not fields is Dictionary:
		return stat
	var overrides: Dictionary = fields
	for field in overrides:
		if _is_int(overrides[field]):
			stat[str(field)] = int(overrides[field])
	return stat


func _dmg_max(part: Dictionary, tier: int) -> int:
	var dmg := _int_list(_effective_ability(part, tier).get("dmg", []))
	return int(dmg[1]) if dmg.size() == 2 else -1


func _effect_value(part: Dictionary, tier: int, effect: String) -> int:
	var effects := _int_dict(_effective_ability(part, tier).get("effects", {}))
	return int(effects.get(effect, -1))


func _stat_value(part: Dictionary, tier: int, stat: String) -> int:
	return int(_effective_stat(part, tier).get(stat, -1))


# ---------------------------------------------------------------- value helpers

func _is_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and float(value) == floorf(float(value))


func _int_list(value: Variant) -> Array:
	var out: Array = []
	if not value is Array:
		return out
	var source: Array = value
	for item in source:
		if not _is_int(item):
			return []
		out.append(int(item))
	return out


func _int_dict(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not value is Dictionary:
		return out
	var source: Dictionary = value
	for key in source:
		if not key is String or not _is_int(source[key]):
			return {}
		out[str(key)] = int(source[key])
	return out


func _valid_ranks(value: Variant) -> bool:
	if not value is Array:
		return false
	var ranks: Array = value
	if ranks.is_empty():
		return false
	var seen := 0
	for item in ranks:
		if not _is_int(item):
			return false
		var rank := int(item)
		if rank < MIN_RANK or rank > MAX_RANK:
			return false
		var bit := 1 << rank
		if seen & bit:
			return false
		seen |= bit
	return true


func _valid_range(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	var range_values: Array = value
	if not _is_int(range_values[0]) or not _is_int(range_values[1]):
		return false
	return int(range_values[0]) >= 0 and int(range_values[1]) >= int(range_values[0])


func _valid_effects(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var effects: Dictionary = value
	for key in effects:
		if not key is String:
			return false
		if not _is_int(effects[key]) or int(effects[key]) < 0:
			return false
	return true
