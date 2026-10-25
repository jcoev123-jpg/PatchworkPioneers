class_name ScarecrowPoolCards
extends RefCounted
## V3-1 authored reward-only pool for Scarecrow: eight base cards plus their '+' upgrades.
## Printed effect descriptors only. This catalog does not execute combat effects, is not registered
## in the reward offers, has no starters and adds no card to the starting deck; live wiring (raising
## Fear, backmost Crow Peck, max-HP-for-heal, front pull) is a later task.

## Internal definition schema:
## {
##   id: String,
##   display_name: String,
##   owner: String,  # "scarecrow"
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "enemy_back", "enemy_all", "ally_single", "self"
##   to_positions: Array[int],
##   effects: Dictionary,  # metadata that no live rules object dispatches yet
##   illustration_path: String,
##   starting_copies: int,  # 0: pool cards are never starters
##   rarity: String,  # "common", "uncommon", "rare"
##   reward_eligible: bool,  # true for base cards only
##   upgrade_id: String,  # for base cards only
##   upgrade_of: String,  # for '+' variants only
## }
##
## Effect keys that a later task must resolve:
##   bleed / weak / block / draw / heal / damage  (the usual printed magnitudes)
##   ignore_block              (Crow Peck: this hit's damage is not stopped by enemy Block)
##   cannot_buff_next_turn     (Fear: the target cannot buff on its next enemy turn; one enemy turn
##                              only, never lengthened when '+' raises weak)
##   max_hp_loss then heal     (Re-Stuff: the cap drops first, the heal applies to the new cap)
##   pull_forward              (Pitchfork Hook: one position toward the front, only into an empty slot)

const _BASE_SPECS = [
	{"slug": "pitchfork_prick", "name": "Pitchfork Prick", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2],
		"target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 5, "bleed": 1},
		"plus_effects": {"damage": 7, "bleed": 2}},
	{"slug": "crow_peck", "name": "Crow Peck", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "enemy_back", "to": [1, 2, 3],
		"effects": {"damage": 4, "ignore_block": true},
		"plus_effects": {"damage": 6, "ignore_block": true}},
	{"slug": "sack_grin", "name": "Sack Grin", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"weak": 1, "cannot_buff_next_turn": true},
		"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
	{"slug": "straw_wrap", "name": "Straw Wrap", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "ally_single", "to": [],
		"effects": {"block": 6, "draw": 1},
		"plus_effects": {"block": 8, "draw": 1}},
	{"slug": "crow_flock", "name": "Crow Flock", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"weak": 1, "cannot_buff_next_turn": true},
		"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
	{"slug": "re_stuff", "name": "Re-Stuff", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [1, 2, 3],
		"target": "self", "to": [],
		"effects": {"max_hp_loss": 2, "heal": 10},
		"plus_effects": {"max_hp_loss": 2, "heal": 13}},
	{"slug": "pitchfork_hook", "name": "Pitchfork Hook", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [1, 2],
		"target": "enemy_single", "to": [2, 3],
		"effects": {"damage": 7, "pull_forward": 1},
		"plus_effects": {"damage": 10, "pull_forward": 1}},
	{"slug": "harvest_fright", "name": "Harvest Fright", "rarity": "rare",
		"cost": 3, "plus_cost": 3, "from": [1, 2, 3],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"damage": 4, "weak": 2, "cannot_buff_next_turn": true},
		"plus_effects": {"damage": 6, "weak": 3, "cannot_buff_next_turn": true}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = "scarecrow_" + str(spec["slug"])
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
		"owner": "scarecrow",
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
