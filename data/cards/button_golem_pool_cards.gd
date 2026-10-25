class_name ButtonGolemPoolCards
extends RefCounted
## V3-1 authored nonstarter reward pool for Button Golem. Eight base cards and one "+"
## upgrade each, expressed as printed look-driven effect descriptors only.
## Data only: this catalog does not build a live party, add cards to the active three-hero
## starting deck or rewards, register a hero, or execute combat effects. A later wiring task
## owns that. The four Button Golem starters live in a separate catalog and are not referenced.
##
## Effect descriptors are printed intent, not live resolution:
##   require_owner_block: N   the caster must already hold N Block, or the card cannot be cast.
##   spend_owner_block: N     spend exactly N of the owner's Block when the card resolves.
##   buttons_popped_gain: 1   count one popped button for this hero this combat.
##   swap_with_target_ally    swap with one other living ally; unavailable allies are rejected.
##   block: N                 give N Block.
##   pinned: true             apply the Pinned status descriptor.
##   thorns: N, duration: 1   gain N Thorns for one turn.
##   block_per_button_popped: N  N Block per button popped earlier this combat; never consumes it.
##   tangled: N               apply N Turns of Tangled.
##   damage: N, hit_count: M, independent_hits: true  independent damage hits.
##   damage_per_button_popped: N  N damage per button popped earlier this combat; never consumes it.
##   living_targets_only: true  skip enemies that are already dead.

const OWNER = "button_golem"

const _BASE_SPECS = [
	{"slug": "pop_button", "name": "Pop Button", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2],
		"target": "enemy_single", "to": [1, 2],
		"effects": {"require_owner_block": 5, "spend_owner_block": 5, "damage": 9,
			"buttons_popped_gain": 1},
		"plus_effects": {"require_owner_block": 5, "spend_owner_block": 5, "damage": 12,
			"buttons_popped_gain": 1}},
	{"slug": "button_roll", "name": "Button Roll", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "ally_single", "to": [],
		"effects": {"swap_with_target_ally": true, "block": 5},
		"plus_effects": {"swap_with_target_ally": true, "block": 8}},
	{"slug": "button_knuckle", "name": "Button Knuckle", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2],
		"target": "enemy_single", "to": [1, 2],
		"effects": {"damage": 5, "pinned": true},
		"plus_effects": {"damage": 7, "pinned": true}},
	{"slug": "eyelet_guard", "name": "Eyelet Guard", "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "self", "to": [],
		"effects": {"block": 6, "thorns": 2, "duration": 1},
		"plus_effects": {"block": 9, "thorns": 3, "duration": 1}},
	{"slug": "sew_on", "name": "Sew On", "rarity": "uncommon",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3],
		"target": "self", "to": [],
		"effects": {"block_per_button_popped": 1},
		"plus_effects": {"block_per_button_popped": 2}},
	{"slug": "buttonhole_snag", "name": "Buttonhole Snag", "rarity": "uncommon",
		"cost": 1, "plus_cost": 1, "from": [1, 2],
		"target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 3, "tangled": 2},
		"plus_effects": {"damage": 4, "tangled": 3}},
	{"slug": "popping_volley", "name": "Popping Volley", "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [1, 2],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"damage": 3, "hit_count": 2, "independent_hits": true,
			"living_targets_only": true},
		"plus_effects": {"damage": 4, "hit_count": 2, "independent_hits": true,
			"living_targets_only": true}},
	{"slug": "buttonstorm", "name": "Buttonstorm", "rarity": "rare",
		"cost": 2, "plus_cost": 2, "from": [1],
		"target": "enemy_all", "to": [1, 2, 3],
		"effects": {"damage_per_button_popped": 4, "living_targets_only": true},
		"plus_effects": {"damage_per_button_popped": 5, "living_targets_only": true}},
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


## Returns the "+" card ID for a base card; upgraded, unknown and non-string IDs return "".
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
