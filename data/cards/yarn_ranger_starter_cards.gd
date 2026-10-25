class_name YarnRangerStarterCards
extends RefCounted
## V3-1 authored starter data for Yarn Ranger: four base cards and one "+" upgrade each.
## Data only. This catalog does not build a live party, add cards to the active three-hero
## starting deck, appear in rewards, or execute combat effects. A later wiring task owns that.

## Internal definition schema (one entry per base and per upgraded card):
## {
##   id: String,
##   display_name: String,
##   owner: "yarn_ranger",
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single" or "ally_single"
##   to_positions: Array[int],
##   effects: Dictionary,
##   illustration_path: String,
##   starting_copies: int,
##   reward_eligible: bool,
##   upgrade_id: String   # base only; upgraded records carry upgrade_of instead
## }

const OWNER = "yarn_ranger"

const _BASE_SPECS = [
	{"slug": "needle_nock", "name": "Needle Nock", "cost": 1, "plus_cost": 1,
		"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 4, "unravel": 1}, "plus_effects": {"damage": 6, "unravel": 2}},
	{"slug": "wool_bolas", "name": "Wool Bolas", "cost": 1, "plus_cost": 1,
		"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 2, "tangled": 1}, "plus_effects": {"damage": 3, "tangled": 2}},
	{"slug": "reel_thread", "name": "Reel Thread", "cost": 1, "plus_cost": 0,
		"from": [2, 3], "target": "enemy_single", "to": [2, 3],
		"effects": {"pull_forward": 1}, "plus_effects": {"pull_forward": 1}},
	{"slug": "hood_knit", "name": "Hood Knit", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "ally_single", "to": [],
		"effects": {"block": 4, "draw": 1}, "plus_effects": {"block": 6, "draw": 1}},
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
		"owner": OWNER,
		"cost": int(spec["plus_cost"] if upgraded else spec["cost"]),
		"from_positions": from_positions,
		"target_kind": str(spec["target"]),
		"to_positions": to_positions,
		"effects": (spec["plus_effects"] if upgraded else spec["effects"]).duplicate(true),
		"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
		"starting_copies": 0 if upgraded else 1,
		"reward_eligible": false,
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


func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _definitions:
		ids.append(id)
	return ids


## The four dedicated Yarn Ranger base starters, each once. Not the active three-hero deck.
func get_starter_ids() -> Array[String]:
	return _base_ids.duplicate()


## Future starting-deck projection for this hero alone: one copy per base starter, no upgrades.
func get_starting_deck() -> Array[String]:
	var deck: Array[String] = []
	for base_id: String in _base_ids:
		var copies: int = int(_definitions[base_id].get("starting_copies", 0))
		for _copy in range(copies):
			deck.append(base_id)
	return deck


## Returns the "+" card ID for a base starter; upgraded, unknown and non-string IDs return "".
func get_upgrade_id(card_id: Variant) -> String:
	if typeof(card_id) != TYPE_STRING:
		return ""
	var id: String = card_id
	if not _definitions.has(id):
		return ""
	return str(_definitions[id].get("upgrade_id", ""))
