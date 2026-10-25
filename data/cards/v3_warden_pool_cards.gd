class_name V3WardenPoolCards
extends RefCounted
## Standalone v3 reward-pool card definitions and upgrades for the Warden hero (V3-1).
## Self-contained, scene-free catalog providing safe lookup for base cards and '+' upgrades.
## This is deliberately NOT wired into battle, rewards, the map, shops or any other catalog yet:
## a later task replaces the live Warden pool and implements Guard / Shield Toss / Taunt.

## Internal definition schema (identical to WardenPoolCards):
## {
##   id: String,
##   display_name: String,
##   owner: String,  # "warden"
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "self", "ally_single", "party_all", "enemy_single"
##   to_positions: Array[int],
##   effects: Dictionary,  # may describe effects that combat does not dispatch yet
##   illustration_path: String,
##   starting_copies: int,  # 0
##   rarity: String,  # "common", "uncommon", "rare"
##   reward_eligible: bool,  # true for base, false for +
##   upgrade_id: String,  # for base cards only
##   upgrade_of: String,  # for + variants only
## }
##
## Effect keys that no live rules object dispatches yet (resolution is a later task):
##   damage_equal_to_owner_block / bonus_damage  (Shield Toss: Warden's Block at resolution, not spent)
##   guard_next_hit                              (one-use redirect of an ally's next incoming enemy hit)
##   taunt_next_enemy_turn                       (enemies aim at the Warden on their next turn)

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	_base_ids = [
		"warden_v3_shield_toss",
		"warden_v3_helmet_rattle",
		"warden_v3_guard_stitch",
		"warden_v3_iron_taunt",
		"warden_v3_rivet_pummel",
		"warden_v3_buckle_rebound",
		"warden_v3_shieldwall_chorus",
		"warden_v3_final_bastion",
	]

	_definitions = {
		# --- Common (4) ---
		"warden_v3_shield_toss": {
			"id": "warden_v3_shield_toss",
			"display_name": "Shield Toss",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage_equal_to_owner_block": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_shield_toss.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_shield_toss_plus",
		},
		"warden_v3_shield_toss_plus": {
			"id": "warden_v3_shield_toss_plus",
			"display_name": "Shield Toss+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage_equal_to_owner_block": true, "bonus_damage": 3},
			"illustration_path": "res://assets/paper/cards/warden_v3_shield_toss.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_shield_toss",
		},
		"warden_v3_helmet_rattle": {
			"id": "warden_v3_helmet_rattle",
			"display_name": "Helmet Rattle",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 4, "weak": 1},
			"illustration_path": "res://assets/paper/cards/warden_v3_helmet_rattle.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_helmet_rattle_plus",
		},
		"warden_v3_helmet_rattle_plus": {
			"id": "warden_v3_helmet_rattle_plus",
			"display_name": "Helmet Rattle+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 6, "weak": 1},
			"illustration_path": "res://assets/paper/cards/warden_v3_helmet_rattle.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_helmet_rattle",
		},
		"warden_v3_guard_stitch": {
			"id": "warden_v3_guard_stitch",
			"display_name": "Guard Stitch",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"block": 5, "guard_next_hit": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_guard_stitch.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_guard_stitch_plus",
		},
		"warden_v3_guard_stitch_plus": {
			"id": "warden_v3_guard_stitch_plus",
			"display_name": "Guard Stitch+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"block": 7, "guard_next_hit": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_guard_stitch.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_guard_stitch",
		},
		"warden_v3_iron_taunt": {
			"id": "warden_v3_iron_taunt",
			"display_name": "Iron Taunt",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 4, "taunt_next_enemy_turn": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_iron_taunt.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_iron_taunt_plus",
		},
		"warden_v3_iron_taunt_plus": {
			"id": "warden_v3_iron_taunt_plus",
			"display_name": "Iron Taunt+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 6, "taunt_next_enemy_turn": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_iron_taunt.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_iron_taunt",
		},

		# --- Uncommon (3) ---
		"warden_v3_rivet_pummel": {
			"id": "warden_v3_rivet_pummel",
			"display_name": "Rivet Pummel",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 3, "hits": 2, "pinned": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_rivet_pummel.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_rivet_pummel_plus",
		},
		"warden_v3_rivet_pummel_plus": {
			"id": "warden_v3_rivet_pummel_plus",
			"display_name": "Rivet Pummel+",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [1, 2],
			"effects": {"damage": 4, "hits": 2, "pinned": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_rivet_pummel.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_rivet_pummel",
		},
		"warden_v3_buckle_rebound": {
			"id": "warden_v3_buckle_rebound",
			"display_name": "Buckle Rebound",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 4, "thorns": 3, "duration": "until_next_turn"},
			"illustration_path": "res://assets/paper/cards/warden_v3_buckle_rebound.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_buckle_rebound_plus",
		},
		"warden_v3_buckle_rebound_plus": {
			"id": "warden_v3_buckle_rebound_plus",
			"display_name": "Buckle Rebound+",
			"owner": "warden",
			"cost": 1,
			"from_positions": [1, 2],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 6, "thorns": 4, "duration": "until_next_turn"},
			"illustration_path": "res://assets/paper/cards/warden_v3_buckle_rebound.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_buckle_rebound",
		},
		"warden_v3_shieldwall_chorus": {
			"id": "warden_v3_shieldwall_chorus",
			"display_name": "Shieldwall Chorus",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1, 2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"block_all": 4, "taunt_next_enemy_turn": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_shieldwall_chorus.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_shieldwall_chorus_plus",
		},
		"warden_v3_shieldwall_chorus_plus": {
			"id": "warden_v3_shieldwall_chorus_plus",
			"display_name": "Shieldwall Chorus+",
			"owner": "warden",
			"cost": 2,
			"from_positions": [1, 2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"block_all": 6, "taunt_next_enemy_turn": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_shieldwall_chorus.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_shieldwall_chorus",
		},

		# --- Rare (1) ---
		"warden_v3_final_bastion": {
			"id": "warden_v3_final_bastion",
			"display_name": "Final Bastion",
			"owner": "warden",
			"cost": 3,
			"from_positions": [1],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 12, "guard_next_hit": true, "taunt_next_enemy_turn": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_final_bastion.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": true,
			"upgrade_id": "warden_v3_final_bastion_plus",
		},
		"warden_v3_final_bastion_plus": {
			"id": "warden_v3_final_bastion_plus",
			"display_name": "Final Bastion+",
			"owner": "warden",
			"cost": 3,
			"from_positions": [1],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 16, "guard_next_hit": true, "taunt_next_enemy_turn": true},
			"illustration_path": "res://assets/paper/cards/warden_v3_final_bastion.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": false,
			"upgrade_of": "warden_v3_final_bastion",
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


## Returns an independent array of the eight authored base card IDs.
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


## Returns an independent array of all defined card IDs (base and '+').
func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _definitions:
		ids.append(id)
	return ids
