class_name WardenPoolCards
extends RefCounted
## Authored reward-pool card definitions and upgrades for the Warden hero (D2-1).
## Self-contained, scene-free catalog providing safe lookup for base cards and '+' upgrades.
## Rules and views query this catalog only; live reward/hand wiring is isolated.

## Internal definition schema:
## {
##   id: String,
##   display_name: String,
##   owner: String,  # "warden"
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "self", "ally_single", "party_all", "enemy_single"
##   to_positions: Array[int],
##   effects: Dictionary,
##   illustration_path: String,
##   starting_copies: int,  # 0
##   rarity: String,  # "common", "uncommon", "rare"
##   reward_eligible: bool,  # true for base, false for +
##   upgrade_id: String,  # for base cards only
##   upgrade_of: String,  # for + variants only
## }

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	_base_ids = [
		"warden_hold_the_line",
		"warden_pinning_jab",
		"warden_heavy_thimble",
		"warden_patch_guard",
		"warden_quick_darn",
		"warden_brass_buckle",
		"warden_draw_fire",
		"warden_seam_breaker",
		"warden_iron_hem",
		"warden_counter_stitch",
		"warden_bastion_quilt",
		"warden_pin_and_pound",
	]

	_definitions = {
		# --- Common (6) ---
		"warden_hold_the_line": {
			"id": "warden_hold_the_line",
			"display_name": "Hold the Line",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 5, "other_ally_block": 2},
			"illustration_path": "res://assets/paper/cards/warden_hold_the_line.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_hold_the_line_plus",
		},
		"warden_hold_the_line_plus": {
			"id": "warden_hold_the_line_plus",
			"display_name": "Hold the Line+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 7, "other_ally_block": 3},
			"illustration_path": "res://assets/paper/cards/warden_hold_the_line.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_hold_the_line",
		},
		"warden_pinning_jab": {
			"id": "warden_pinning_jab",
			"display_name": "Pinning Jab",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1],
			"effects": {"damage": 4, "pinned": true},
			"illustration_path": "res://assets/paper/cards/warden_pinning_jab.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_pinning_jab_plus",
		},
		"warden_pinning_jab_plus": {
			"id": "warden_pinning_jab_plus",
			"display_name": "Pinning Jab+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1],
			"effects": {"damage": 6, "pinned": true},
			"illustration_path": "res://assets/paper/cards/warden_pinning_jab.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_pinning_jab",
		},
		"warden_heavy_thimble": {
			"id": "warden_heavy_thimble",
			"display_name": "Heavy Thimble",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 11},
			"illustration_path": "res://assets/paper/cards/warden_heavy_thimble.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_heavy_thimble_plus",
		},
		"warden_heavy_thimble_plus": {
			"id": "warden_heavy_thimble_plus",
			"display_name": "Heavy Thimble+",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 15},
			"illustration_path": "res://assets/paper/cards/warden_heavy_thimble.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_heavy_thimble",
		},
		"warden_patch_guard": {
			"id": "warden_patch_guard",
			"display_name": "Patch Guard",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"block": 8},
			"illustration_path": "res://assets/paper/cards/warden_patch_guard.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_patch_guard_plus",
		},
		"warden_patch_guard_plus": {
			"id": "warden_patch_guard_plus",
			"display_name": "Patch Guard+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"block": 11},
			"illustration_path": "res://assets/paper/cards/warden_patch_guard.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_patch_guard",
		},
		"warden_quick_darn": {
			"id": "warden_quick_darn",
			"display_name": "Quick Darn",
			"owner": "warden",
			"cost": 0,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 4},
			"illustration_path": "res://assets/paper/cards/warden_quick_darn.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_quick_darn_plus",
		},
		"warden_quick_darn_plus": {
			"id": "warden_quick_darn_plus",
			"display_name": "Quick Darn+",
			"owner": "warden",
			"cost": 0,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 6},
			"illustration_path": "res://assets/paper/cards/warden_quick_darn.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_quick_darn",
		},
		"warden_brass_buckle": {
			"id": "warden_brass_buckle",
			"display_name": "Brass Buckle",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 5, "block": 4},
			"illustration_path": "res://assets/paper/cards/warden_brass_buckle.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_brass_buckle_plus",
		},
		"warden_brass_buckle_plus": {
			"id": "warden_brass_buckle_plus",
			"display_name": "Brass Buckle+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 7, "block": 6},
			"illustration_path": "res://assets/paper/cards/warden_brass_buckle.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_brass_buckle",
		},

		# --- Uncommon (4) ---
		"warden_draw_fire": {
			"id": "warden_draw_fire",
			"display_name": "Draw Fire",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 6, "guarding": true, "duration": "until_next_turn"},
			"illustration_path": "res://assets/paper/cards/warden_draw_fire.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "warden_draw_fire_plus",
		},
		"warden_draw_fire_plus": {
			"id": "warden_draw_fire_plus",
			"display_name": "Draw Fire+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 8, "guarding": true, "duration": "until_next_turn"},
			"illustration_path": "res://assets/paper/cards/warden_draw_fire.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "warden_draw_fire",
		},
		"warden_seam_breaker": {
			"id": "warden_seam_breaker",
			"display_name": "Seam Breaker",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 7, "unravel": 4},
			"illustration_path": "res://assets/paper/cards/warden_seam_breaker.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "warden_seam_breaker_plus",
		},
		"warden_seam_breaker_plus": {
			"id": "warden_seam_breaker_plus",
			"display_name": "Seam Breaker+",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 10, "unravel": 6},
			"illustration_path": "res://assets/paper/cards/warden_seam_breaker.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "warden_seam_breaker",
		},
		"warden_iron_hem": {
			"id": "warden_iron_hem",
			"display_name": "Iron Hem",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1, 2, 3],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 14},
			"illustration_path": "res://assets/paper/cards/warden_iron_hem.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "warden_iron_hem_plus",
		},
		"warden_iron_hem_plus": {
			"id": "warden_iron_hem_plus",
			"display_name": "Iron Hem+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 14},
			"illustration_path": "res://assets/paper/cards/warden_iron_hem.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "warden_iron_hem",
		},
		"warden_counter_stitch": {
			"id": "warden_counter_stitch",
			"display_name": "Counter-stitch",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 5, "thorns": 3, "duration": "until_next_turn"},
			"illustration_path": "res://assets/paper/cards/warden_counter_stitch.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "warden_counter_stitch_plus",
		},
		"warden_counter_stitch_plus": {
			"id": "warden_counter_stitch_plus",
			"display_name": "Counter-stitch+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 7, "thorns": 4, "duration": "until_next_turn"},
			"illustration_path": "res://assets/paper/cards/warden_counter_stitch.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "warden_counter_stitch",
		},

		# --- Rare (2) ---
		"warden_bastion_quilt": {
			"id": "warden_bastion_quilt",
			"display_name": "Bastion Quilt",
			"owner": "warden",
			"cost": 3,
			"from_positions": [1, 2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"block_all": 10},
			"illustration_path": "res://assets/paper/cards/warden_bastion_quilt.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": true,
			"upgrade_id": "warden_bastion_quilt_plus",
		},
		"warden_bastion_quilt_plus": {
			"id": "warden_bastion_quilt_plus",
			"display_name": "Bastion Quilt+",
			"owner": "warden",
			"cost": 3,
			"from_positions": [1, 2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"block_all": 13},
			"illustration_path": "res://assets/paper/cards/warden_bastion_quilt.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": false,
			"upgrade_of": "warden_bastion_quilt",
		},
		"warden_pin_and_pound": {
			"id": "warden_pin_and_pound",
			"display_name": "Pin and Pound",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 9, "hits": 2},
			"illustration_path": "res://assets/paper/cards/warden_pin_and_pound.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": true,
			"upgrade_id": "warden_pin_and_pound_plus",
		},
		"warden_pin_and_pound_plus": {
			"id": "warden_pin_and_pound_plus",
			"display_name": "Pin and Pound+",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 12, "hits": 2},
			"illustration_path": "res://assets/paper/cards/warden_pin_and_pound.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": false,
			"upgrade_of": "warden_pin_and_pound",
		},
	}


## Returns a deep copy of the definition for the given card ID, or an empty dictionary if unknown.
func get_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not _definitions.has(id):
		return {}
	return _definitions[id].duplicate(true)


## Returns true if the card ID exists in this catalog.
func has_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	return _definitions.has(id)


## Returns an independent array of all twelve authored base card IDs.
func get_base_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in _base_ids:
		result.append(id)
	return result


## Returns the matching upgrade card ID for a valid base card ID, or "" if unknown or already upgraded.
func get_upgrade_id(card_id: Variant) -> String:
	if typeof(card_id) != TYPE_STRING:
		return ""
	var id: String = card_id
	if not _definitions.has(id):
		return ""
	return _definitions[id].get("upgrade_id", "")


## Returns a read-only array of all defined card IDs (safe to iterate).
func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _definitions:
		ids.append(id)
	return ids
