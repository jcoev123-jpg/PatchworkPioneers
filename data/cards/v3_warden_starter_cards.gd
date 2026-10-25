class_name V3WardenStarterCards
extends RefCounted
## V3-1 authored starter data for the Warden: four base cards and one "+" upgrade each.
## Data only. This catalog does not build a live party, add cards to the active three-hero
## starting deck, appear in rewards, or execute combat effects. A later wiring task owns that.
##
## The four bases are the squat shield-bearer's look signatures rather than plain attack/Block
## spells: a dented pot helmet bonk that Weakens one foe, the huge round patchwork shield raised
## over an ally (Guard), a shield-rim toss whose damage equals the Warden's own current Block,
## and a helmet-and-shield challenge that draws the next enemy turn (Taunt).
## The independent v3 Warden reward pool is a separate catalog and is deliberately not
## referenced here; every ID in this file belongs only to this starter catalog.

## Internal definition schema (one entry per base and per upgraded card):
## {
##   id: String,
##   display_name: String,
##   owner: "warden",
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "ally_single" or "self"
##   to_positions: Array[int],
##   effects: Dictionary,
##   illustration_path: String,
##   starting_copies: int,
##   reward_eligible: bool,
##   upgrade_id: String   # base only; upgraded records carry upgrade_of instead
## }
##
## Effect descriptors are printed intent, not live resolution:
##   damage / weak                  flat damage; Weak 1 means the foe deals 25% less attack
##                                  damage for its duration, rounded down.
##   block                          Block for the chosen living ally (Shield Catch) or the Warden
##                                  itself (Iron Challenge); it applies normally.
##   guard_next_hit                 the next enemy hit aimed at that ally is redirected to the
##                                  Warden once; one use.
##   damage_equal_to_owner_block    damage equals the Warden's CURRENT Block at resolution,
##                                  without spending that Block (same language as Shield Toss).
##   bonus_damage                   flat damage added to that Block-based hit on the "+".
##   taunt_next_enemy_turn          next enemy turn's targetable attacks aim at the living Warden.

const OWNER = "warden"

const _BASE_SPECS = [
	{"id": "warden_v3_pot_helm_bonk", "name": "Pot Helm Bonk", "cost": 1, "plus_cost": 1,
		"from": [1, 2], "target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 4, "weak": 1},
		"plus_effects": {"damage": 6, "weak": 1}},
	{"id": "warden_v3_shield_catch", "name": "Shield Catch", "cost": 1, "plus_cost": 1,
		"from": [1, 2], "target": "ally_single", "to": [],
		"effects": {"block": 4, "guard_next_hit": true},
		"plus_effects": {"block": 6, "guard_next_hit": true}},
	{"id": "warden_v3_rim_toss", "name": "Rim Toss", "cost": 1, "plus_cost": 1,
		"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage_equal_to_owner_block": true},
		"plus_effects": {"damage_equal_to_owner_block": true, "bonus_damage": 2}},
	{"id": "warden_v3_iron_challenge", "name": "Iron Challenge", "cost": 1, "plus_cost": 1,
		"from": [1], "target": "self", "to": [],
		"effects": {"block": 3, "taunt_next_enemy_turn": true},
		"plus_effects": {"block": 5, "taunt_next_enemy_turn": true}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = str(spec["id"])
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


## The four dedicated Warden base starters, in authored order. Not the active three-hero deck.
func get_starter_ids() -> Array[String]:
	return _base_ids.duplicate()


## Future starting-deck projection for this hero alone: one copy per base starter, no upgrades.
## This is a local membership contract, never the shared Warden/Seamstress/Tinker deck.
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
