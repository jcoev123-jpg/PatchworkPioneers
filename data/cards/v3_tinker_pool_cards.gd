class_name V3TinkerPoolCards
extends Resource
## Standalone v3 Tinker reward-pool card definitions and upgrades (V3-1).
## Self-contained, scene-free catalog providing safe lookup for base cards and '+' upgrades.
## This is deliberately NOT wired into battle, rewards, the map, shops or any live pool yet:
## a later task replaces the live Tinker pool and implements Combat Scrap, Overload,
## Wind-up Turret and Jury-rig resolution.
##
## Schema follows TinkerPoolCards:
## {
##   id: String,
##   display_name: String,
##   owner: String,  # "tinker"
##   rarity: String,  # "common", "uncommon", "rare"
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "self", "enemy_single", "enemy_all"
##   to_positions: Array[int],
##   effects: Dictionary,  # declarative until the later combat integration
##   illustration_path: String,
##   starting_copies: int,  # always 0
##   base_id: String,
##   upgrade_id: String,
##   is_upgrade: bool,
## }
##
## Combat Scrap is a COMBAT counter, never the run's wallet `scraps` currency.
## Effect keys that no live rules object dispatches yet (resolution is a later task):
##   combat_scrap_gain             (gain Combat Scrap when the card resolves)
##   damage_per_combat_scrap       (Overload: add this per Combat Scrap held)
##   consume_all_combat_scrap      (Overload: spend all Combat Scrap, never wallet scraps)
##   combat_scrap_spend_max        (Scrapstorm: spend at most this much Combat Scrap)
##   bonus_damage_per_combat_scrap (Scrapstorm: +damage to each living enemy per scrap spent)
##   turret                        (Wind-up Turret: end-of-turn 3-damage ticks for 3 turns)
##   copy_previous_card            (Jury-rig: copy the previous other card once per combat at cost 0)

var _definitions: Dictionary = {}
var _pool_card_ids: Array[String] = []
var _upgrade_ids: Dictionary = {}


func _init() -> void:
	_add("tinker_v3_brass_casing", "Brass Casing", "common", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"damage": 4, "combat_scrap_gain": 1},
		{"damage": 6, "combat_scrap_gain": 1})
	_add("tinker_v3_gear_brace", "Gear Brace", "common", 1, [1, 2, 3],
		"self", [],
		{"block": 5, "combat_scrap_gain": 1},
		{"block": 7, "combat_scrap_gain": 1})
	_add("tinker_v3_spare_screws", "Spare Screws", "common", 1, [2, 3],
		"self", [],
		{"combat_scrap_gain": 2, "draw": 1},
		{"combat_scrap_gain": 2, "draw": 1}, 0)
	_add("tinker_v3_spring_clamp", "Spring Clamp", "common", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"damage": 3, "weak": 1, "combat_scrap_gain": 1},
		{"damage": 4, "weak": 1, "combat_scrap_gain": 1})
	_add("tinker_v3_wind_up_turret", "Wind-up Turret", "uncommon", 2, [3],
		"self", [],
		{"turret": _turret(3)},
		{"turret": _turret(4)})
	_add("tinker_v3_overload", "Overload", "uncommon", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"damage": 2, "damage_per_combat_scrap": 3, "consume_all_combat_scrap": true},
		{"damage": 3, "damage_per_combat_scrap": 4, "consume_all_combat_scrap": true})
	_add("tinker_v3_jury_rig", "Jury-rig", "rare", 2, [2, 3],
		"self", [],
		{"copy_previous_card": true, "copied_card_cost": 0,
			"once_per_combat": true, "exclude_self": true},
		{"copy_previous_card": true, "copied_card_cost": 0,
			"once_per_combat": true, "exclude_self": true}, 1)
	_add("tinker_v3_scrapstorm", "Scrapstorm", "rare", 2, [3],
		"enemy_all", [1, 2, 3],
		{"damage": 3, "combat_scrap_spend_max": 3,
			"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
		{"damage": 4, "combat_scrap_spend_max": 3,
			"bonus_damage_per_combat_scrap": 1, "living_targets_only": true})


## Wind-up Turret payload: exactly three end-of-player-turn ticks, each striking a
## random living enemy through the single run RNG only when selection requires it.
static func _turret(damage: int) -> Dictionary:
	return {
		"damage": damage,
		"duration_turns": 3,
		"tick": "end_player_turn",
		"target_kind": "enemy_random",
		"living_targets_only": true,
		"rng_source": "run"
	}


func _add(base_id: String, name: String, rarity: String, cost: int,
		from_positions: Array[int], target_kind: String, to_positions: Array[int],
		base_effects: Dictionary, plus_effects: Dictionary,
		plus_cost: int = -1) -> void:
	var plus_id: String = base_id + "_plus"
	_pool_card_ids.append(base_id)
	_upgrade_ids[base_id] = plus_id
	for is_plus in [false, true]:
		var card_id: String = plus_id if is_plus else base_id
		var definition: Dictionary = {
			"id": card_id,
			"display_name": name + ("+" if is_plus else ""),
			"owner": "tinker",
			"rarity": rarity,
			"cost": plus_cost if is_plus and plus_cost >= 0 else cost,
			"from_positions": from_positions.duplicate(),
			"target_kind": target_kind,
			"to_positions": to_positions.duplicate(),
			"effects": (plus_effects if is_plus else base_effects).duplicate(true),
			"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
			"starting_copies": 0,
			"base_id": base_id,
			"upgrade_id": plus_id,
			"is_upgrade": is_plus
		}
		_definitions[card_id] = definition


## Unknown/invalid IDs return {}, never a mutable reference to stored definitions.
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


## Reward candidates are ONLY the unupgraded Tinker pool IDs.
func get_pool_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id in _pool_card_ids:
		ids.append(card_id)
	return ids


## Returns "" for unknown IDs or an already-upgraded card.
func get_upgrade_id(base_id: Variant) -> String:
	if typeof(base_id) != TYPE_STRING:
		return ""
	var id: String = base_id
	if not _definitions.has(id):
		return ""
	return _upgrade_ids.get(id, "")
