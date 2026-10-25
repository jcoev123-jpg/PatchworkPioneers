class_name ButtonGolemStarterCards
extends RefCounted
## V3-1 authored starter data for Button Golem: four base cards and one "+" upgrade each.
## Data only. This catalog does not build a live party, add cards to the active three-hero
## starting deck, appear in rewards, or execute combat effects. A later wiring task owns that.
## The four bases are the hero's look signatures: a heavy Button Fist that clips a front enemy
## and braces the caster, a Loose Button Pop that spends 5 of its own Block like v3 Pop Button,
## a Threadwheel Roll that swaps with an ally and gains Block, and a Seam Re-Sew that gains
## Block for every button popped earlier in the combat.
## The independent Button Golem reward pool is a separate catalog and is deliberately not
## referenced here. These starter IDs carry "starter_" so they never collide with it.

## Internal definition schema (one entry per base and per upgraded card):
## {
##   id: String,
##   display_name: String,
##   owner: "button_golem",
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
##   damage: N             deal N damage to the chosen enemy.
##   block_self: N         give N Block to the Button Golem caster, not to the chosen ally.
##   spend_block: 5        the caster must already hold 5 Block; spend 5 before the hit.
##   buttons_popped: 1     count one popped button only on successful resolution of the hit.
##   swap_with_ally: 1     swap the Golem with one different living ally; no shuffle or RNG.
##   block_per_button_popped: 1  one Block per button successfully popped earlier this combat;
##                        this never creates or spends a button count.
##   block: N              flat Block added by the upgraded Seam Re-Sew+.

const OWNER = "button_golem"

const _BASE_SPECS = [
	{"slug": "starter_button_fist", "name": "Button Fist", "cost": 1, "plus_cost": 1,
		"from": [1, 2], "target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 5, "block_self": 2},
		"plus_effects": {"damage": 7, "block_self": 3}},
	{"slug": "starter_loose_pop", "name": "Loose Button Pop", "cost": 1, "plus_cost": 1,
		"from": [1, 2], "target": "enemy_single", "to": [1, 2],
		"effects": {"spend_block": 5, "damage": 9, "buttons_popped": 1},
		"plus_effects": {"spend_block": 5, "damage": 11, "buttons_popped": 1}},
	{"slug": "starter_threadwheel_roll", "name": "Threadwheel Roll", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "ally_single", "to": [],
		"effects": {"swap_with_ally": 1, "block_self": 5},
		"plus_effects": {"swap_with_ally": 1, "block_self": 7}},
	{"slug": "starter_seam_resew", "name": "Seam Re-Sew", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "self", "to": [],
		"effects": {"block_per_button_popped": 1},
		"plus_effects": {"block_per_button_popped": 1, "block": 2}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = "button_golem_" + str(spec["slug"])
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


## The four dedicated Button Golem base starters, in authored order. Not the active three-hero deck.
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
