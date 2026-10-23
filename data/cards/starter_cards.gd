class_name StarterCards
extends Resource
## Authored starter-card definitions and starting deck membership.
## Provides safe lookup and a fresh starting-deck array.
## No combat integration; rules and views query this catalog only.

## Internal definition schema:
## {
##   id: String,
##   display_name: String,
##   owner: String,
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "enemy_all", "self", "ally_single", "none"
##   to_positions: Array[int],
##   effects: Dictionary,
##   illustration_path: String,
##   starting_copies: int
## }

var _definitions: Dictionary = {}

func _init() -> void:
	_definitions = {
		"warden_strike_plus": {
			"id": "warden_strike_plus",
			"display_name": "Strike+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 7},
			"illustration_path": "res://assets/paper/cards/warden_strike.png",
			"starting_copies": 0
		},
		"warden_strike": {
			"id": "warden_strike",
			"display_name": "Strike",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 6},
			"illustration_path": "res://assets/paper/cards/warden_strike.png",
			"starting_copies": 2
		},
		"warden_brace": {
			"id": "warden_brace",
			"display_name": "Brace",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 7},
			"illustration_path": "res://assets/paper/cards/warden_brace.png",
			"starting_copies": 1
		},
		"warden_brace_plus": {
			"id": "warden_brace_plus",
			"display_name": "Brace+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 10},
			"illustration_path": "res://assets/paper/cards/warden_brace.png",
			"starting_copies": 0
		},
		"warden_shield_bash": {
			"id": "warden_shield_bash",
			"display_name": "Shield Bash",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1],
			"target_kind": "enemy_single",
			"to_positions": [1],
			"effects": {"damage": 8, "weak": 1},
			"illustration_path": "res://assets/paper/cards/warden_shield_bash.png",
			"starting_copies": 1
		},
		"warden_shield_bash_plus": {
			"id": "warden_shield_bash_plus",
			"display_name": "Shield Bash+",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1],
			"target_kind": "enemy_single",
			"to_positions": [1],
			"effects": {"damage": 11, "weak": 1},
			"illustration_path": "res://assets/paper/cards/warden_shield_bash.png",
			"starting_copies": 0
		},
		"seamstress_prick": {
			"id": "seamstress_prick",
			"display_name": "Prick",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 3, "bleed": 2},
			"illustration_path": "res://assets/paper/cards/seamstress_prick.png",
			"starting_copies": 2
		},
		"seamstress_prick_plus": {
			"id": "seamstress_prick_plus",
			"display_name": "Prick+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 4, "bleed": 3},
			"illustration_path": "res://assets/paper/cards/seamstress_prick.png",
			"starting_copies": 0
		},
		"seamstress_mend": {
			"id": "seamstress_mend",
			"display_name": "Mend",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 5},
			"illustration_path": "res://assets/paper/cards/seamstress_mend.png",
			"starting_copies": 1
		},
		"seamstress_mend_plus": {
			"id": "seamstress_mend_plus",
			"display_name": "Mend+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 7},
			"illustration_path": "res://assets/paper/cards/seamstress_mend.png",
			"starting_copies": 0
		},
		"seamstress_stitch_up": {
			"id": "seamstress_stitch_up",
			"display_name": "Stitch Up",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"block": 5},
			"illustration_path": "res://assets/paper/cards/seamstress_stitch_up.png",
			"starting_copies": 1
		},
		"seamstress_stitch_up_plus": {
			"id": "seamstress_stitch_up_plus",
			"display_name": "Stitch Up+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"block": 7},
			"illustration_path": "res://assets/paper/cards/seamstress_stitch_up.png",
			"starting_copies": 0
		},
		"tinker_pop_shot": {
			"id": "tinker_pop_shot",
			"display_name": "Pop Shot",
			"owner": "tinker",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 5},
			"illustration_path": "res://assets/paper/cards/tinker_pop_shot.png",
			"starting_copies": 2
		},
		"tinker_pop_shot_plus": {
			"id": "tinker_pop_shot_plus",
			"display_name": "Pop Shot+",
			"owner": "tinker",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 7},
			"illustration_path": "res://assets/paper/cards/tinker_pop_shot.png",
			"starting_copies": 0
		},
		"tinker_scrap_bomb": {
			"id": "tinker_scrap_bomb",
			"display_name": "Scrap Bomb",
			"owner": "tinker",
			"cost": 2,
			"from_positions": [3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 4},
			"illustration_path": "res://assets/paper/cards/tinker_scrap_bomb.png",
			"starting_copies": 1
		},
		"tinker_scrap_bomb_plus": {
			"id": "tinker_scrap_bomb_plus",
			"display_name": "Scrap Bomb+",
			"owner": "tinker",
			"cost": 2,
			"from_positions": [3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 6},
			"illustration_path": "res://assets/paper/cards/tinker_scrap_bomb.png",
			"starting_copies": 0
		},
		"tinker_tune_up": {
			"id": "tinker_tune_up",
			"display_name": "Tune Up",
			"owner": "tinker",
			"cost": 0,
			"from_positions": [1, 2, 3],
			"target_kind": "none",
			"to_positions": [],
			"effects": {"draw": 1},
			"illustration_path": "res://assets/paper/cards/tinker_tune_up.png",
			"starting_copies": 1
		}
	}

## Returns a deep copy of the definition for the given card ID, or an empty dictionary if unknown.
func get_definition(card_id: String) -> Dictionary:
	if not _definitions.has(card_id):
		return {}
	return _definitions[card_id].duplicate(true)

## Returns a fresh array of card IDs representing the starting deck with specified multiplicities.
## The returned array can be freely modified without affecting the catalog.
func get_starting_deck() -> Array[String]:
	var deck: Array[String] = []
	for card_id in _definitions:
		var definition: Dictionary = _definitions[card_id]
		var copies: int = definition.get("starting_copies", 0)
		for i in range(copies):
			deck.append(card_id)
	return deck

## Returns true if the card ID exists in the catalog.
func has_card(card_id: String) -> bool:
	return _definitions.has(card_id)

## Returns a read-only array of all defined card IDs (shallow copy, safe to iterate).
func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _definitions:
		ids.append(id)
	return ids
