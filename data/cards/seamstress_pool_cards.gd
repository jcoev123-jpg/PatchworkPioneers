class_name SeamstressPoolCards
extends RefCounted
## D2-1 authored nonstarter pool. Printed effect descriptors only; this catalog
## does not execute combat effects or add cards to rewards, Rest or starter decks.

const _BASE_SPECS = [
	{"slug": "running_stitch", "name": "Running Stitch", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 2, "bleed": 3}, "plus_effects": {"damage": 3, "bleed": 4}},
	{"slug": "needle_pin", "name": "Needle Pin", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 3, "pinned": true}, "plus_effects": {"damage": 4, "pinned": true}},
	{"slug": "darning", "name": "Darning", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "ally_single", "to": [],
		"effects": {"heal": 4, "block": 3}, "plus_effects": {"heal": 6, "block": 4}},
	{"slug": "snag", "name": "Snag", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"unravel": 3, "weak": 1}, "plus_effects": {"unravel": 4, "weak": 1}},
	{"slug": "thread_whip", "name": "Thread Whip", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 6}, "plus_effects": {"damage": 8}},
	{"slug": "thimble_tea", "name": "Thimble Tea", "rarity": "common",
		"cost": 0, "plus_cost": 0, "from": [2, 3],
		"target": "ally_single", "to": [],
		"effects": {"heal": 3}, "plus_effects": {"heal": 4}},
	{"slug": "hemorrhage_hem", "name": "Hemorrhage Hem", "rarity": "uncommon",
		"cost": 2, "plus_cost": 1, "from": [1, 2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"bleed_multiplier": 2}, "plus_effects": {"bleed_multiplier": 2}},
	{"slug": "unpick", "name": "Unpick", "rarity": "uncommon",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"unravel": 5}, "plus_effects": {"unravel": 7}},
	{"slug": "blanket_stitch", "name": "Blanket Stitch", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"bleed": 2}, "plus_effects": {"bleed": 3}},
	{"slug": "field_mend", "name": "Field Mend", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3],
		"target": "party_all", "to": [],
		"effects": {"heal": 4}, "plus_effects": {"heal": 6}},
	{"slug": "red_thread", "name": "Red Thread", "rarity": "rare",
		"cost": 2, "plus_cost": 2, "from": [1, 2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"bleed": 6, "exposed": 1}, "plus_effects": {"bleed": 8, "exposed": 1}},
	{"slug": "tailors_trance", "name": "Tailor's Trance", "rarity": "rare",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "self", "to": [],
		"effects": {"energy": 1, "draw": 2}, "plus_effects": {"energy": 1, "draw": 3}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = "seamstress_" + str(spec["slug"])
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
		"owner": "seamstress",
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
