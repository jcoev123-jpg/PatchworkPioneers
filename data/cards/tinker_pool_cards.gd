class_name TinkerPoolCards
extends Resource
## D2-1 reward-only Tinker card definitions. No live reward/Rest/combat wiring.
## Base IDs are reward candidates; their _plus partners are addressable upgrades
## only. Lookups return deep copies and never consume any RNG.
##
## Schema follows StarterCards, adding:
## rarity: "common" | "uncommon" | "rare"
## base_id: base reward ID shared by both versions
## upgrade_id: the corresponding _plus ID (on both versions)
## is_upgrade: bool
##
## Effect conventions for later resolution:
## - target_kind "enemy_all" applies effects to EACH living enemy in to_positions.
## - "enemy_random" selects a NEW living enemy per hit with the single run RNG.
## - pinned: records the source hero; a DIFFERENT hero's next attack gets +5
##   before Weak/Exposed, consumes once; a same-hero attack does not consume.
## - unravel: gauge increase. Status/threshold execution belongs to D2-2/3.
## - conditional_damage: replace normal damage when EITHER predicate matches.

var _definitions: Dictionary = {}
var _pool_card_ids: Array[String] = []
var _upgrade_ids: Dictionary = {}


func _init() -> void:
	_add("tinker_rivet_shot", "Rivet Shot", "common", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"damage": 4, "exposed": 1},
		{"damage": 6, "exposed": 1})
	_add("tinker_spring_trap", "Spring Trap", "common", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"damage": 3, "pinned": _pinned_rule()},
		{"damage": 4, "pinned": _pinned_rule()})
	_add("tinker_scatter_bolts", "Scatter Bolts", "common", 1, [3],
		"enemy_all", [1, 2, 3],
		{"damage": 3, "living_targets_only": true},
		{"damage": 4, "living_targets_only": true})
	_add("tinker_spare_parts", "Spare Parts", "common", 0, [2, 3],
		"self", [],
		{"block": 3, "draw": 1},
		{"block": 4, "draw": 1})
	_add("tinker_long_barrel", "Long Barrel", "common", 2, [3],
		"enemy_single", [1, 2, 3],
		{"damage": 12},
		{"damage": 16})
	_add("tinker_spool_launcher", "Spool Launcher", "common", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"damage": 3, "unravel": 3},
		{"damage": 4, "unravel": 4})
	_add("tinker_overclock", "Overclock", "uncommon", 0, [1, 2, 3],
		"self", [],
		{"gain_energy": 1, "self_hp_loss": 3},
		{"gain_energy": 1, "self_hp_loss": 3})
	_add("tinker_shrapnel_seam", "Shrapnel Seam", "uncommon", 2, [3],
		"enemy_all", [1, 2, 3],
		{"damage": 5, "unravel": 2, "living_targets_only": true},
		{"damage": 7, "unravel": 3, "living_targets_only": true})
	_add("tinker_sight_glass", "Sight Glass", "uncommon", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"exposed": 2, "draw": 1},
		{"exposed": 2, "draw": 1})
	_add("tinker_ricochet", "Ricochet", "uncommon", 1, [2, 3],
		"enemy_random", [1, 2, 3],
		{"damage": 4, "hit_count": 3, "random_target_each_hit": true,
			"rng_source": "run", "living_targets_only": true},
		{"damage": 6, "hit_count": 3, "random_target_each_hit": true,
			"rng_source": "run", "living_targets_only": true})
	_add("tinker_bobbin_cannon", "Bobbin Cannon", "rare", 3, [3],
		"enemy_single", [1, 2, 3],
		{"damage": 20},
		{"damage": 26})
	_add("tinker_snip_the_seam", "Snip the Seam", "rare", 1, [2, 3],
		"enemy_single", [1, 2, 3],
		{"damage": 5, "conditional_damage": _snip_condition(15)},
		{"damage": 7, "conditional_damage": _snip_condition(20)})


static func _pinned_rule() -> Dictionary:
	return {
		"pinner_identity": "source_hero",
		"trigger": "next_attack_by_different_hero",
		"bonus_damage": 5,
		"bonus_timing": "before_weak_exposed",
		"consume_once": true,
		"same_hero_consumes": false
	}


static func _snip_condition(empowered_damage: int) -> Dictionary:
	return {
		"damage": empowered_damage,
		"operator": "or",
		"conditions": [
			{"status": "unravelled"},
			{"gauge": "unravel", "comparison": "at_least_half",
				"threshold": "current_target_threshold"}
		]
	}


func _add(base_id: String, name: String, rarity: String, cost: int,
		from_positions: Array[int], target_kind: String, to_positions: Array[int],
		base_effects: Dictionary, plus_effects: Dictionary) -> void:
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
			"cost": cost,
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


## Unknown IDs return {}, never a mutable reference to stored definitions.
func get_definition(card_id: String) -> Dictionary:
	if not _definitions.has(card_id):
		return {}
	return _definitions[card_id].duplicate(true)


func has_card(card_id: String) -> bool:
	return _definitions.has(card_id)


## Reward candidates are ONLY the unupgraded Tinker pool IDs.
func get_pool_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id in _pool_card_ids:
		ids.append(card_id)
	return ids


## Returns "" for unknown IDs or an already-upgraded card.
func get_upgrade_id(base_id: String) -> String:
	return _upgrade_ids.get(base_id, "")
