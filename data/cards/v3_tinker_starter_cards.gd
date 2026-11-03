class_name V3TinkerStarterCards
extends RefCounted
## V3-1 authored starter data for the Tinker: four base cards and one "+" upgrade each.
## Data only. This catalog does not build a live party, add cards to the active three-hero
## starting deck, appear in rewards, or execute combat effects. A later wiring task owns that.
##
## The four bases are the scrap tinker's kit rather than plain attack/Block spells: a
## cog-loaded blunderbuss shot that salvages a piece of Combat Scrap, a folded casing of
## reclaimed metal that wards the Tinker himself, a powder charge thrown from the back seat
## into the whole enemy line, and a backpack tune-up that draws a bolt and a card.
## The independent v3 Tinker reward pool is a separate catalog and is deliberately not
## referenced here; every ID in this file belongs only to this starter catalog.
##
## Internal definition schema (one entry per base and per upgraded card):
## {
##   id: String,
##   display_name: String,
##   owner: "tinker",
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "enemy_all", "self" or "none"
##   to_positions: Array[int],
##   effects: Dictionary,
##   illustration_path: String,
##   starting_copies: int,
##   reward_eligible: bool,
##   upgrade_id: String   # base only; upgraded records carry upgrade_of instead
## }
##
## Effect descriptors are printed intent, not live resolution:
##   damage                 flat damage to one chosen enemy (Cog Shot) or to every living enemy
##                          (Scrap Bomb). Scrap Bomb keeps the legacy 4/6 damage budget and names
##                          the three party positions only; it never invents a fourth target.
##   block                  personal Block for the Tinker himself (Casing Ward), on the authored
##                          V3 Tinker Gear Brace 5/7 scale.
##   draw                   draw from the shared deck (Tune Up), on the legacy 1/2 budget.
##   combat_scrap_gain      gain that much Combat Scrap on the Tinker when this card resolves.
##                          Combat Scrap is a COMBAT counter, NEVER the run's wallet `scraps`; it
##                          is never granted by a lookup or by adding the card to a deck.
##   living_targets_only    an enemy_all hit skips downed enemies. The printed candidate slots
##                          stay 1..3; a live adapter must validate battle capacity.

const OWNER = "tinker"

const _BASE_SPECS = [
	{"id": "tinker_v3_cog_shot", "name": "Cog Shot", "cost": 1, "plus_cost": 1,
		"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 5, "combat_scrap_gain": 1},
		"plus_effects": {"damage": 7, "combat_scrap_gain": 1}},
	{"id": "tinker_v3_casing_ward", "name": "Casing Ward", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "self", "to": [],
		"effects": {"block": 5, "combat_scrap_gain": 1},
		"plus_effects": {"block": 7, "combat_scrap_gain": 1}},
	{"id": "tinker_v3_scrap_bomb", "name": "Scrap Bomb", "cost": 2, "plus_cost": 2,
		"from": [3], "target": "enemy_all", "to": [1, 2, 3],
		"effects": {"damage": 4, "combat_scrap_gain": 1, "living_targets_only": true},
		"plus_effects": {"damage": 6, "combat_scrap_gain": 1, "living_targets_only": true}},
	{"id": "tinker_v3_tune_up", "name": "Tune Up", "cost": 0, "plus_cost": 0,
		"from": [1, 2, 3], "target": "none", "to": [],
		"effects": {"draw": 1, "combat_scrap_gain": 1},
		"plus_effects": {"draw": 2, "combat_scrap_gain": 1}},
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


## The four dedicated Tinker base starters, in authored order. Not the active three-hero deck.
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
