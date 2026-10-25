class_name ScarecrowStarterCards
extends RefCounted
## V3-1 authored starter data for Scarecrow: four look-driven base cards and one "+" upgrade each.
## Data only. This catalog does not build a live party, add cards to the active three-hero starting
## deck, appear in rewards, or execute combat effects. The existing ScarecrowPoolCards registry stays
## reward-only; a later wiring task owns hand, reward and effect-dispatch integration.
##
## Look-driven kit (burial sack head, pitchfork, black shoulder crow, straw seams):
##   Fork Jab      - the pitchfork pierces cloth: damage plus Bleed.
##   Sack Glare    - the grinning sack face scares an enemy: Weak plus Fear's one-turn buff lock.
##   Crow Dive     - the shoulder crow strikes the backmost living enemy and ignores Block.
##   Straw Padding - straw tucked into a teammate's seams: Block plus one shared-hand draw.

## Internal definition schema (one entry per base and per upgraded card):
## {
##   id: String,
##   display_name: String,
##   owner: "scarecrow",
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "enemy_back" or "ally_single"
##   to_positions: Array[int],
##   effects: Dictionary,  # printed descriptors only; no live rules object dispatches them yet
##   illustration_path: String,
##   starting_copies: int,
##   reward_eligible: bool,
##   upgrade_id: String   # base only; upgraded records carry upgrade_of instead
## }
##
## Effect keys that a later task must resolve:
##   damage / bleed / weak / block / draw  (the usual printed magnitudes)
##   ignore_block              (Crow Dive: this hit's damage is not stopped by enemy Block)
##   cannot_buff_next_turn     (Fear: the target cannot buff on its next enemy turn; one enemy turn
##                              only, never lengthened when '+' raises weak)

const OWNER = "scarecrow"

const _BASE_SPECS = [
	{"slug": "fork_jab", "name": "Fork Jab", "cost": 1, "plus_cost": 1,
		"from": [1, 2], "target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 4, "bleed": 1}, "plus_effects": {"damage": 6, "bleed": 2}},
	{"slug": "sack_glare", "name": "Sack Glare", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
		"effects": {"weak": 1, "cannot_buff_next_turn": true},
		"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
	{"slug": "crow_dive", "name": "Crow Dive", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "enemy_back", "to": [1, 2, 3],
		"effects": {"damage": 3, "ignore_block": true},
		"plus_effects": {"damage": 5, "ignore_block": true}},
	{"slug": "straw_padding", "name": "Straw Padding", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "ally_single", "to": [],
		"effects": {"block": 4, "draw": 1}, "plus_effects": {"block": 6, "draw": 1}},
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


## The four dedicated Scarecrow base starters, each once. Not the active three-hero deck.
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
