class_name LanternMonkPoolCards
extends RefCounted
## V3-1 authored nonstarter reward pool for the Lantern Monk hero.
## Self-contained, scene-free catalog of eight base cards and their eight '+' upgrades.
##
## This catalog is deliberately NOT wired into battle, rewards, the run map, shops or any other
## live catalog yet. A later owner task hooks it into the party/reward selection and the held-hand
## effect resolver. The effect keys below are printed descriptors only; several of them
## (blind_next_attack, cleanse_one_debuff_each_ally, dodge_next_attack, exhaust) have no live
## combat dispatch in this slice and are intentionally kept as data.
##
## Lantern Monk look-driven kit (GAME_DESIGN.md Design v3): what a hero looks like drives what it
## does. Blind makes an enemy's NEXT attack miss; it is a one-shot boolean, never a numeric stack.
## Lantern Glow heals every living ally a little and removes one debuff from each eligible ally.
## Moth Cloud Blinds every living enemy and Exhausts. Wax Ward is the kit's single plain Block
## card, so plain attack/Block stays at most one third of the eight-card pool.
##
## Internal definition schema (identical to the other v3 pool catalogs):
## {
##   id: String,
##   display_name: String,
##   owner: String,  # "lantern_monk"
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "enemy_all", "party_all", "ally_single", "self"
##   to_positions: Array[int],
##   effects: Dictionary,
##   illustration_path: String,  # future placeholder art; no PNG is created by this slice
##   starting_copies: int,  # 0
##   rarity: String,  # "common", "uncommon", "rare"
##   reward_eligible: bool,  # true for base, false for '+'
##   upgrade_id: String,  # base cards only
##   upgrade_of: String,  # '+' variants only
## }

const _BASE_SPECS = [
	# --- Common (4) ---
	{"slug": "wick_flicker", "name": "Wick Flicker", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 4, "blind_next_attack": true},
		"plus_effects": {"damage": 6, "blind_next_attack": true}},
	{"slug": "moth_lure", "name": "Moth Lure", "rarity": "common",
		"cost": 1, "plus_cost": 0, "from": [2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"blind_next_attack": true, "draw": 1},
		"plus_effects": {"blind_next_attack": true, "draw": 1}},
	{"slug": "lantern_glow", "name": "Lantern Glow", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "party_all", "to": [],
		"effects": {"heal_all": 2, "cleanse_one_debuff_each_ally": 1},
		"plus_effects": {"heal_all": 3, "cleanse_one_debuff_each_ally": 1}},
	{"slug": "wax_ward", "name": "Wax Ward", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "self", "to": [],
		"effects": {"block": 5},
		"plus_effects": {"block": 7}},
	# --- Uncommon (3) ---
	{"slug": "moth_shroud", "name": "Moth Shroud", "rarity": "uncommon",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "ally_single", "to": [],
		"effects": {"block": 6, "dodge_next_attack": 1},
		"plus_effects": {"block": 8, "dodge_next_attack": 1}},
	{"slug": "snuff_flame", "name": "Snuff Flame", "rarity": "uncommon",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 3, "blind_next_attack": true, "exposed": 1},
		"plus_effects": {"damage": 4, "blind_next_attack": true, "exposed": 2}},
	{"slug": "vigil_ring", "name": "Vigil Ring", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3],
		"target": "party_all", "to": [],
		"effects": {"heal_all": 4, "block_all": 4},
		"plus_effects": {"heal_all": 6, "block_all": 6}},
	# --- Rare (1) ---
	{"slug": "moth_cloud", "name": "Moth Cloud", "rarity": "rare",
		"cost": 2, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"blind_next_attack": true, "exhaust": true},
		"plus_effects": {"blind_next_attack": true, "exhaust": true}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = "lantern_monk_" + str(spec["slug"])
		var plus_id: String = base_id + "_plus"
		_base_ids.append(base_id)
		_definitions[base_id] = _make_definition(spec, base_id, plus_id, false)
		_definitions[plus_id] = _make_definition(spec, base_id, plus_id, true)


func _make_definition(spec: Dictionary, base_id: String, plus_id: String,
		upgraded: bool) -> Dictionary:
	var from_positions: Array[int] = []
	for position: int in spec["from"]:
		from_positions.append(position)
	var to_positions: Array[int] = []
	for position: int in spec["to"]:
		to_positions.append(position)
	var definition: Dictionary = {
		"id": plus_id if upgraded else base_id,
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "lantern_monk",
		"cost": int(spec["plus_cost"] if upgraded else spec["cost"]),
		"from_positions": from_positions,
		"target_kind": str(spec["target"]),
		"to_positions": to_positions,
		"effects": (spec["plus_effects"] if upgraded else spec["effects"]).duplicate(true),
		"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
		"starting_copies": 0,
		"rarity": str(spec["rarity"]),
		"reward_eligible": not upgraded,
	}
	if upgraded:
		definition["upgrade_of"] = base_id
	else:
		definition["upgrade_id"] = plus_id
	return definition


## Returns a deep copy of the definition for the given card ID, or {} when the ID is invalid.
## Non-string values (null, ints, floats, bools, containers, StringNames) are rejected.
func get_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not _definitions.has(id):
		return {}
	return _definitions[id].duplicate(true)


## Returns true only for an authored string card ID (base or '+').
func has_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	return _definitions.has(id)


## Returns an independent array of the eight authored base card IDs.
func get_base_ids() -> Array[String]:
	return _base_ids.duplicate()


## Returns the matching '+' card ID for a base ID, or "" for unknown and already-upgraded IDs.
func get_upgrade_id(card_id: Variant) -> String:
	if typeof(card_id) != TYPE_STRING:
		return ""
	var id: String = card_id
	if not _definitions.has(id):
		return ""
	return str(_definitions[id].get("upgrade_id", ""))


## Returns an independent array of every defined card ID (bases and '+' variants).
func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _definitions:
		ids.append(id)
	return ids
