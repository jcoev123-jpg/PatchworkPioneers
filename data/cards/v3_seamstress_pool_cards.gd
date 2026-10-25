class_name V3SeamstressPoolCards
extends RefCounted
## Standalone v3 reward-pool card definitions and upgrades for the Seamstress hero (V3-1).
## Self-contained, scene-free catalog providing safe lookup for base cards and '+' upgrades.
## This is deliberately NOT wired into battle, rewards, the map, shops or any other catalog yet:
## a later task registers these cards and implements Tether / cleanse resolution.

## Internal definition schema (identical to SeamstressPoolCards):
## {
##   id: String,
##   display_name: String,
##   owner: String,  # "seamstress"
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "enemy_pair", "enemy_all", "ally_single", "party_all"
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
## Printed descriptors that no live rules object dispatches yet (resolution is a later task):
##   tether_share_percent  (Tether Stitch: links two distinct living enemies so 50% of damage
##                          dealt to one is dealt to the other, rounded down, minimum zero)
##   cleanse_debuff        (Darn the Tear / Midnight Loom: remove one existing debuff
##                          - Bleed, Weak or Exposed - from the chosen living ally)
## targeting_enemy_pair  (implied by target_kind; exactly two distinct living enemies at
##                          authored legal positions, chosen by the future handlers)
## The link's lifetime and damage-trigger transaction are decided by that later task; this
## catalog records descriptors only and grants no new status, resource or persistent state.

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	_base_ids = [
		"seamstress_v3_needle_rain",
		"seamstress_v3_scarlet_knot",
		"seamstress_v3_bobbin_snag",
		"seamstress_v3_patchwork_poultice",
		"seamstress_v3_tether_stitch",
		"seamstress_v3_darn_the_tear",
		"seamstress_v3_blanket_of_barbs",
		"seamstress_v3_midnight_loom",
	]

	_definitions = {
		# --- Common (4) ---
		"seamstress_v3_needle_rain": {
			"id": "seamstress_v3_needle_rain",
			"display_name": "Needle Rain",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 2, "bleed": 3},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_needle_rain.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_needle_rain_plus",
		},
		"seamstress_v3_needle_rain_plus": {
			"id": "seamstress_v3_needle_rain_plus",
			"display_name": "Needle Rain+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 3, "bleed": 4},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_needle_rain.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_needle_rain",
		},
		"seamstress_v3_scarlet_knot": {
			"id": "seamstress_v3_scarlet_knot",
			"display_name": "Scarlet Knot",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 2, "weak": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_scarlet_knot.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_scarlet_knot_plus",
		},
		"seamstress_v3_scarlet_knot_plus": {
			"id": "seamstress_v3_scarlet_knot_plus",
			"display_name": "Scarlet Knot+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 3, "weak": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_scarlet_knot.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_scarlet_knot",
		},
		"seamstress_v3_bobbin_snag": {
			"id": "seamstress_v3_bobbin_snag",
			"display_name": "Bobbin Snag",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"unravel": 3, "pinned": true},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_bobbin_snag.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_bobbin_snag_plus",
		},
		"seamstress_v3_bobbin_snag_plus": {
			"id": "seamstress_v3_bobbin_snag_plus",
			"display_name": "Bobbin Snag+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"unravel": 4, "pinned": true},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_bobbin_snag.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_bobbin_snag",
		},
		"seamstress_v3_patchwork_poultice": {
			"id": "seamstress_v3_patchwork_poultice",
			"display_name": "Patchwork Poultice",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 3, "block": 3},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_patchwork_poultice.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_patchwork_poultice_plus",
		},
		"seamstress_v3_patchwork_poultice_plus": {
			"id": "seamstress_v3_patchwork_poultice_plus",
			"display_name": "Patchwork Poultice+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 4, "block": 4},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_patchwork_poultice.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_patchwork_poultice",
		},

		# --- Uncommon (3) ---
		"seamstress_v3_tether_stitch": {
			"id": "seamstress_v3_tether_stitch",
			"display_name": "Tether Stitch",
			"owner": "seamstress",
			"cost": 2,
			"from_positions": [2, 3],
			"target_kind": "enemy_pair",
			"to_positions": [1, 2, 3],
			"effects": {"tether_share_percent": 50},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_tether_stitch_plus",
		},
		"seamstress_v3_tether_stitch_plus": {
			"id": "seamstress_v3_tether_stitch_plus",
			"display_name": "Tether Stitch+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_pair",
			"to_positions": [1, 2, 3],
			"effects": {"tether_share_percent": 50},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_tether_stitch",
		},
		"seamstress_v3_darn_the_tear": {
			"id": "seamstress_v3_darn_the_tear",
			"display_name": "Darn the Tear",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 4, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_darn_the_tear.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_darn_the_tear_plus",
		},
		"seamstress_v3_darn_the_tear_plus": {
			"id": "seamstress_v3_darn_the_tear_plus",
			"display_name": "Darn the Tear+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 6, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_darn_the_tear.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_darn_the_tear",
		},
		"seamstress_v3_blanket_of_barbs": {
			"id": "seamstress_v3_blanket_of_barbs",
			"display_name": "Blanket of Barbs",
			"owner": "seamstress",
			"cost": 2,
			"from_positions": [2, 3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 2, "unravel": 2},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_blanket_of_barbs.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_blanket_of_barbs_plus",
		},
		"seamstress_v3_blanket_of_barbs_plus": {
			"id": "seamstress_v3_blanket_of_barbs_plus",
			"display_name": "Blanket of Barbs+",
			"owner": "seamstress",
			"cost": 2,
			"from_positions": [2, 3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 3, "unravel": 3},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_blanket_of_barbs.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_blanket_of_barbs",
		},

		# --- Rare (1) ---
		"seamstress_v3_midnight_loom": {
			"id": "seamstress_v3_midnight_loom",
			"display_name": "Midnight Loom",
			"owner": "seamstress",
			"cost": 3,
			"from_positions": [2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"heal": 4, "block": 4, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_midnight_loom.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_midnight_loom_plus",
		},
		"seamstress_v3_midnight_loom_plus": {
			"id": "seamstress_v3_midnight_loom_plus",
			"display_name": "Midnight Loom+",
			"owner": "seamstress",
			"cost": 3,
			"from_positions": [2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"heal": 6, "block": 6, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_midnight_loom.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_midnight_loom",
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
	return str(_definitions[id].get("upgrade_id", ""))


## Returns an independent array of all defined card IDs (base and '+').
func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _definitions:
		ids.append(id)
	return ids
