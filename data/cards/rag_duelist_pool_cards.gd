class_name RagDuelistPoolCards
extends RefCounted
## V3-1 authored nonstarter pool for Rag Duelist. Printed effect descriptors only.

const _BASE_SPECS = [
	{"slug": "needle_prick", "name": "Needle Prick", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2],
		"target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 4, "bleed": 2}, "plus_effects": {"damage": 6, "bleed": 3}},
	{"slug": "needle_lunge", "name": "Needle Lunge", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [2, 3],
		"target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 6, "move_self_forward": 1}, "plus_effects": {"damage": 8, "move_self_forward": 1}},
	{"slug": "cape_guard", "name": "Cape Guard", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "self", "to": [],
		"effects": {"block": 5, "riposte": 3, "duration": 1}, "plus_effects": {"block": 7, "riposte": 4, "duration": 1}},
	{"slug": "velvet_feint", "name": "Velvet Feint", "rarity": "common",
		"cost": 1, "plus_cost": 0, "from": [1, 2],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"exposed": 1, "draw": 1}, "plus_effects": {"exposed": 1, "draw": 1}},
	{"slug": "duelist_reprise", "name": "Duelist Reprise", "rarity": "uncommon",
		"cost": 1, "plus_cost": 1, "from": [1, 2],
		"target": "self", "to": [],
		"effects": {"riposte": 5, "duration": 1}, "plus_effects": {"riposte": 7, "duration": 1}},
	{"slug": "cape_flourish", "name": "Cape Flourish", "rarity": "uncommon",
		"cost": 1, "plus_cost": 0, "from": [1, 2, 3],
		"target": "self", "to": [],
		"effects": {"dodge_next_attack": 1, "duration": 1}, "plus_effects": {"dodge_next_attack": 1, "duration": 1}},
	{"slug": "tattered_snare", "name": "Tattered Snare", "rarity": "uncommon",
		"cost": 1, "plus_cost": 1, "from": [1, 2],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"tangled": 2}, "plus_effects": {"tangled": 3}},
	{"slug": "needle_barrage", "name": "Needle Barrage", "rarity": "rare",
		"cost": 2, "plus_cost": 2, "from": [1],
		"target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 3, "hit_count": 3, "independent_hits": true}, "plus_effects": {"damage": 4, "hit_count": 3, "independent_hits": true}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = "rag_duelist_" + str(spec["slug"])
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
		"owner": "rag_duelist",
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
