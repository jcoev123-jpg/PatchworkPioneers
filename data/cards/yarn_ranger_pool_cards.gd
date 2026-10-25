class_name YarnRangerPoolCards
extends RefCounted
## V3-1 authored nonstarter pool for Yarn Ranger. Printed effect descriptors only; this catalog
## does not execute combat effects or add cards to rewards, Rest or starter decks.

const _BASE_SPECS = [
	{"slug": "needle_arrow", "name": "Needle Arrow", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 5, "unravel": 1}, "plus_effects": {"damage": 7, "unravel": 2}},
	{"slug": "tangle_bolas", "name": "Tangle Bolas", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 2, "tangled": 2}, "plus_effects": {"damage": 3, "tangled": 3}},
	{"slug": "reel_in", "name": "Reel In", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_single", "to": [2, 3],
		"effects": {"pull_forward": 1, "tangled": 1}, "plus_effects": {"pull_forward": 1, "tangled": 2}},
	{"slug": "knit_shield", "name": "Knit Shield", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "ally_single", "to": [],
		"effects": {"block": 6, "draw": 1}, "plus_effects": {"block": 8, "draw": 1}},
	{"slug": "purling_barrage", "name": "Purling Barrage", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 3, "hit_count": 2, "unravel": 1}, "plus_effects": {"damage": 4, "hit_count": 2, "unravel": 2}},
	{"slug": "snare_net", "name": "Snare Net", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"tangled": 1, "living_targets_only": true}, "plus_effects": {"tangled": 2, "living_targets_only": true}},
	{"slug": "unspool", "name": "Unspool", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"damage": 7, "requires_target_status": "tangled", "living_targets_only": true}, "plus_effects": {"damage": 10, "requires_target_status": "tangled", "living_targets_only": true}},
	{"slug": "endless_skein", "name": "Endless Skein", "rarity": "rare",
		"cost": 3, "plus_cost": 3, "from": [2, 3],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"damage": 4, "tangled": 2, "living_targets_only": true}, "plus_effects": {"damage": 6, "tangled": 3, "living_targets_only": true}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = "yarn_ranger_" + str(spec["slug"])
		var plus_id: String = base_id + "_plus"
		_base_ids.append(base_id)
		_definitions[base_id] = _make_definition(spec, base_id, plus_id, false)
		_definitions[plus_id] = _make_definition(spec, base_id, plus_id, true)


func _make_definition(spec: Dictionary, base_id: String, plus_id: String,
		upgraded: bool) -> Dictionary:
	var from_positions: Array[int] = []
	for position in spec["from"]:
		from_positions.append(int(position))
	var to_positions: Array[int] = []
	for position in spec["to"]:
		to_positions.append(int(position))
	var definition: Dictionary = {
		"id": plus_id if upgraded else base_id,
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "yarn_ranger",
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


## Lookups return detached records, including effects and both position arrays.
func get_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not _definitions.has(id):
		return {}
	return _definitions[id].duplicate(true)


func has_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	return _definitions.has(id)


func get_base_ids() -> Array[String]:
	return _base_ids.duplicate()


func get_upgrade_id(card_id: Variant) -> String:
	if typeof(card_id) != TYPE_STRING:
		return ""
	var id: String = card_id
	if not _definitions.has(id):
		return ""
	return str(_definitions[id].get("upgrade_id", ""))


func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _definitions:
		ids.append(id)
	return ids
