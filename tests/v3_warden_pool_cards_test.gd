extends SceneTree
## Deterministic headless test for the standalone V3WardenPoolCards catalog (V3-1).
## Verifies the eight authored v3 Warden base cards and their eight '+' upgrades field by field,
## catalog isolation (unknown/invalid IDs, base lookup, caller mutation) and that the existing v2
## Warden pool, starter cards and live reward draws are untouched. The v3 catalog is deliberately
## NOT wired into combat, rewards, the map or shops yet, so nothing here drives a live card.


var failures: Array[String] = []
var checks: int = 0

## Representative existing Warden definitions that must stay owned by their current catalogs.
const EXISTING_WARDEN_POOL_IDS: Array[String] = [
	"warden_hold_the_line",
	"warden_draw_fire",
	"warden_counter_stitch",
]
const EXISTING_STARTER_IDS: Array[String] = [
	"warden_strike",
	"warden_brace",
	"warden_shield_bash",
]


func _initialize() -> void:
	_test_base_card_definitions()
	_test_upgraded_card_definitions()
	_test_mechanic_payloads()
	_test_unknown_and_invalid_ids()
	_test_mutation_isolation()
	_test_existing_catalogs_untouched()
	_test_not_in_reward_draws()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("v3_warden_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_warden_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _get_catalog() -> V3WardenPoolCards:
	return V3WardenPoolCards.new()


func _expected_base_records() -> Dictionary:
	return {
		"warden_v3_shield_toss": {
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
		"warden_v3_helmet_rattle": {
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
		"warden_v3_guard_stitch": {
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
		"warden_v3_iron_taunt": {
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
		"warden_v3_rivet_pummel": {
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
		"warden_v3_buckle_rebound": {
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
		"warden_v3_shieldwall_chorus": {
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
		"warden_v3_final_bastion": {
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
	}


func _expected_plus_records() -> Dictionary:
	return {
		"warden_v3_shield_toss_plus": {
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
		"warden_v3_helmet_rattle_plus": {
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
		"warden_v3_guard_stitch_plus": {
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
		"warden_v3_iron_taunt_plus": {
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
		"warden_v3_rivet_pummel_plus": {
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
		"warden_v3_buckle_rebound_plus": {
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
		"warden_v3_shieldwall_chorus_plus": {
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
		"warden_v3_final_bastion_plus": {
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


func _test_base_card_definitions() -> void:
	var catalog: V3WardenPoolCards = _get_catalog()
	var expected_table: Dictionary = _expected_base_records()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()

	_check(not expected_table.is_empty(), "expected base table is non-empty (precondition)")
	_check(not base_ids.is_empty(), "get_base_ids is non-empty (precondition)")

	for card_id: String in expected_table:
		var expected: Dictionary = expected_table[card_id]
		_check(catalog.has_card(card_id), "catalog has base card " + card_id)
		_check(base_ids.has(card_id), "get_base_ids includes " + card_id)
		_check(all_ids.has(card_id), "get_all_card_ids includes " + card_id)

		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "definition for " + card_id + " is not empty")
		if definition.is_empty():
			continue

		_check(definition.get("id") == card_id, card_id + " id matches key")
		_check(definition.get("display_name") == expected["display_name"], card_id + " display_name")
		_check(definition.get("owner") == "warden", card_id + " owner is warden")
		_check(definition.get("cost") == expected["cost"], card_id + " cost")
		_check(definition.get("from_positions") == expected["from_positions"], card_id + " from_positions")
		_check(definition.get("target_kind") == expected["target_kind"], card_id + " target_kind")
		_check(definition.get("to_positions") == expected["to_positions"], card_id + " to_positions")
		_check(definition.get("effects") == expected["effects"], card_id + " exact effects payload")
		_check(definition.get("illustration_path") == expected["illustration_path"], card_id + " illustration_path")
		_check(String(definition.get("illustration_path", "")) == "res://assets/paper/cards/" + card_id + ".png", card_id + " illustration_path names its own art id")
		_check(definition.get("starting_copies") == 0, card_id + " starting_copies is 0")
		_check(definition.get("rarity") == expected["rarity"], card_id + " rarity")
		_check(definition.get("reward_eligible") == true, card_id + " reward_eligible is true")
		_check(definition.get("upgrade_id") == expected["upgrade_id"], card_id + " upgrade_id points at its plus")
		_check(not definition.has("upgrade_of"), card_id + " base has no upgrade_of")
		_check(catalog.get_upgrade_id(card_id) == expected["upgrade_id"], card_id + " get_upgrade_id resolves plus")

		# Legal target contract: only enemy targets name enemy positions; ally/self/party cards name none.
		var to_positions: Array = definition.get("to_positions", [])
		if String(definition.get("target_kind", "")) == "enemy_single":
			_check(not to_positions.is_empty(), card_id + " enemy_single has legal to_positions")
			for position: Variant in to_positions:
				_check(position is int and int(position) >= 1 and int(position) <= 3, card_id + " to position is 1..3")
		else:
			_check(to_positions.is_empty(), card_id + " non-enemy target has empty to_positions")
		var from_positions: Array = definition.get("from_positions", [])
		_check(not from_positions.is_empty(), card_id + " has a legal Warden from_positions")
		for position: Variant in from_positions:
			_check(position is int and int(position) >= 1 and int(position) <= 3, card_id + " from position is 1..3")
		_check(from_positions.has(1), card_id + " can be played from the front position")


func _test_upgraded_card_definitions() -> void:
	var catalog: V3WardenPoolCards = _get_catalog()
	var expected_base: Dictionary = _expected_base_records()
	var expected_plus: Dictionary = _expected_plus_records()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()

	for base_id: String in expected_base:
		var plus_id: String = catalog.get_upgrade_id(base_id)
		_check(not plus_id.is_empty(), base_id + " has a valid upgrade_id")
		_check(expected_plus.has(plus_id), plus_id + " is in the expected plus table")
		if not expected_plus.has(plus_id):
			continue

		var expected: Dictionary = expected_plus[plus_id]
		var base_definition: Dictionary = catalog.get_definition(base_id)
		var plus_definition: Dictionary = catalog.get_definition(plus_id)

		_check(catalog.has_card(plus_id), "catalog has upgraded card " + plus_id)
		_check(all_ids.has(plus_id), "get_all_card_ids includes " + plus_id)
		_check(not base_ids.has(plus_id), "plus ID " + plus_id + " is not in get_base_ids")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " is not a base for a further upgrade")
		_check(not plus_definition.is_empty(), "definition for " + plus_id + " is not empty")
		if plus_definition.is_empty():
			continue

		_check(plus_definition.get("id") == plus_id, plus_id + " id matches key")
		_check(plus_definition.get("display_name") == expected["display_name"], plus_id + " display_name")
		_check(plus_definition.get("display_name") == String(base_definition.get("display_name", "")) + "+", plus_id + " display_name appends '+'")
		_check(plus_definition.get("owner") == "warden", plus_id + " owner is warden")
		_check(plus_definition.get("cost") == expected["cost"], plus_id + " cost")
		_check(plus_definition.get("from_positions") == expected["from_positions"], plus_id + " from_positions")
		_check(plus_definition.get("target_kind") == expected["target_kind"], plus_id + " target_kind")
		_check(plus_definition.get("to_positions") == expected["to_positions"], plus_id + " to_positions")
		_check(plus_definition.get("effects") == expected["effects"], plus_id + " exact upgraded effects")
		_check(plus_definition.get("illustration_path") == expected["illustration_path"], plus_id + " illustration_path")
		_check(plus_definition.get("starting_copies") == 0, plus_id + " starting_copies is 0")
		_check(plus_definition.get("rarity") == expected["rarity"], plus_id + " rarity")
		_check(plus_definition.get("reward_eligible") == false, plus_id + " is not reward eligible")
		_check(plus_definition.get("upgrade_of") == base_id, plus_id + " upgrade_of points at its base")
		_check(not plus_definition.has("upgrade_id"), plus_id + " has no upgrade_id")

		# The '+' keeps the base's legal owner/position/target/rarity/cost contract.
		_check(plus_definition.get("owner") == base_definition.get("owner"), plus_id + " preserves owner")
		_check(plus_definition.get("cost") == base_definition.get("cost"), plus_id + " preserves cost")
		_check(plus_definition.get("from_positions") == base_definition.get("from_positions"), plus_id + " preserves from_positions")
		_check(plus_definition.get("target_kind") == base_definition.get("target_kind"), plus_id + " preserves target_kind")
		_check(plus_definition.get("to_positions") == base_definition.get("to_positions"), plus_id + " preserves to_positions")
		_check(plus_definition.get("rarity") == base_definition.get("rarity"), plus_id + " preserves rarity")
		_check(plus_definition.get("illustration_path") == base_definition.get("illustration_path"), plus_id + " shares the base art path")
		_check(plus_definition.get("starting_copies") == base_definition.get("starting_copies"), plus_id + " preserves starting_copies")
		_check(plus_definition.get("effects") != base_definition.get("effects"), plus_id + " differs from the base effects")


func _test_mechanic_payloads() -> void:
	var catalog: V3WardenPoolCards = _get_catalog()

	# Shield Toss: damage equals the Warden's Block at resolution; that Block is never a cost.
	var shield_toss: Dictionary = catalog.get_definition("warden_v3_shield_toss").get("effects", {})
	_check(shield_toss.get("damage_equal_to_owner_block") == true, "Shield Toss reads the Warden's Block at resolution")
	_check(not shield_toss.has("damage"), "Shield Toss has no flat damage key")
	_check(not shield_toss.has("bonus_damage"), "Shield Toss base has no bonus_damage")
	var shield_toss_plus: Dictionary = catalog.get_definition("warden_v3_shield_toss_plus").get("effects", {})
	_check(shield_toss_plus.get("damage_equal_to_owner_block") == true, "Shield Toss+ still reads the Warden's Block")
	_check(shield_toss_plus.get("bonus_damage") == 3, "Shield Toss+ adds exactly 3 bonus damage")

	# Guard: intercept the next hit aimed at an ally, one use.
	for guard_id: String in ["warden_v3_guard_stitch", "warden_v3_guard_stitch_plus", "warden_v3_final_bastion", "warden_v3_final_bastion_plus"]:
		var guard_definition: Dictionary = catalog.get_definition(guard_id)
		_check(guard_definition.get("effects", {}).get("guard_next_hit") == true, guard_id + " carries the Guard payload")
		_check(guard_definition.get("to_positions", []).is_empty(), guard_id + " guards without naming enemy positions")
	_check(catalog.get_definition("warden_v3_final_bastion").get("effects", {}).get("block") == 12, "Final Bastion gives 12 Block")
	_check(catalog.get_definition("warden_v3_final_bastion_plus").get("effects", {}).get("block") == 16, "Final Bastion+ gives 16 Block")

	# Taunt: enemies aim at the Warden on their next turn.
	for taunt_id: String in ["warden_v3_iron_taunt", "warden_v3_iron_taunt_plus", "warden_v3_shieldwall_chorus", "warden_v3_shieldwall_chorus_plus", "warden_v3_final_bastion", "warden_v3_final_bastion_plus"]:
		var taunt_definition: Dictionary = catalog.get_definition(taunt_id)
		_check(taunt_definition.get("effects", {}).get("taunt_next_enemy_turn") == true, taunt_id + " carries the Taunt payload")
	_check(catalog.get_definition("warden_v3_shieldwall_chorus").get("effects", {}).get("block_all") == 4, "Shieldwall Chorus blocks the whole living party for 4")
	_check(catalog.get_definition("warden_v3_shieldwall_chorus_plus").get("effects", {}).get("block_all") == 6, "Shieldwall Chorus+ blocks the whole living party for 6")

	# Rivet Pummel: exactly two 3-damage hits and a Pin for cross-hero follow-up.
	var pummel: Dictionary = catalog.get_definition("warden_v3_rivet_pummel").get("effects", {})
	_check(pummel.get("damage") == 3, "Rivet Pummel hit damage is 3")
	_check(pummel.get("hits") == 2, "Rivet Pummel lands exactly 2 hits")
	_check(pummel.get("pinned") == true, "Rivet Pummel pins the target")
	var pummel_plus: Dictionary = catalog.get_definition("warden_v3_rivet_pummel_plus").get("effects", {})
	_check(pummel_plus.get("damage") == 4, "Rivet Pummel+ hit damage is 4")
	_check(pummel_plus.get("hits") == 2, "Rivet Pummel+ keeps exactly 2 hits")

	# Helmet Rattle: a weak-enabling helmet strike.
	_check(catalog.get_definition("warden_v3_helmet_rattle").get("effects", {}).get("damage") == 4, "Helmet Rattle deals 4")
	_check(catalog.get_definition("warden_v3_helmet_rattle").get("effects", {}).get("weak") == 1, "Helmet Rattle applies 1 Weak")
	_check(catalog.get_definition("warden_v3_helmet_rattle_plus").get("effects", {}).get("damage") == 6, "Helmet Rattle+ deals 6")
	_check(catalog.get_definition("warden_v3_helmet_rattle_plus").get("effects", {}).get("weak") == 1, "Helmet Rattle+ keeps 1 Weak")

	# Buckle Rebound: until-next-turn Thorns beside Block, no Taunt/Guard.
	for rebound_id: String in ["warden_v3_buckle_rebound", "warden_v3_buckle_rebound_plus"]:
		var rebound: Dictionary = catalog.get_definition(rebound_id).get("effects", {})
		_check(rebound.get("duration") == "until_next_turn", rebound_id + " Thorns last until next turn")
		_check(int(rebound.get("thorns", 0)) > 0, rebound_id + " has Thorns")
		_check(not rebound.has("taunt_next_enemy_turn"), rebound_id + " does not taunt")
		_check(not rebound.has("guard_next_hit"), rebound_id + " does not guard")
	_check(catalog.get_definition("warden_v3_buckle_rebound").get("effects", {}).get("thorns") == 3, "Buckle Rebound Thorns 3")
	_check(catalog.get_definition("warden_v3_buckle_rebound_plus").get("effects", {}).get("thorns") == 4, "Buckle Rebound+ Thorns 4")
	_check(catalog.get_definition("warden_v3_buckle_rebound").get("effects", {}).get("block") == 4, "Buckle Rebound Block 4")
	_check(catalog.get_definition("warden_v3_buckle_rebound_plus").get("effects", {}).get("block") == 6, "Buckle Rebound+ Block 6")

	# Iron Taunt: never targets an enemy, only the Warden itself.
	_check(catalog.get_definition("warden_v3_iron_taunt").get("target_kind") == "self", "Iron Taunt targets self")
	_check(catalog.get_definition("warden_v3_iron_taunt_plus").get("target_kind") == "self", "Iron Taunt+ targets self")


func _test_unknown_and_invalid_ids() -> void:
	var catalog: V3WardenPoolCards = _get_catalog()
	var expected_plus: Dictionary = _expected_plus_records()

	_check(catalog.get_definition("nonexistent_id").is_empty(), "get_definition on nonexistent ID returns {}")
	_check(catalog.get_definition("").is_empty(), "get_definition on empty ID returns {}")
	_check(catalog.get_definition(null).is_empty(), "get_definition on null returns {}")
	_check(catalog.get_definition(123).is_empty(), "get_definition on int returns {}")
	_check(catalog.get_definition("warden_v3_").is_empty(), "get_definition on a bare v3 prefix returns {}")
	_check(catalog.get_definition("warden_hold_the_line").is_empty(), "get_definition does not expose the v2 Warden pool")
	_check(catalog.get_definition("warden_strike").is_empty(), "get_definition does not expose the starter deck")

	_check(not catalog.has_card("nonexistent_id"), "has_card on nonexistent ID returns false")
	_check(not catalog.has_card(""), "has_card on empty string returns false")
	_check(not catalog.has_card(null), "has_card on null returns false")
	_check(not catalog.has_card(123), "has_card on int returns false")
	_check(not catalog.has_card("warden_hold_the_line"), "has_card does not expose the v2 Warden pool")
	_check(not catalog.has_card("warden_strike"), "has_card does not expose the starter deck")

	_check(catalog.get_upgrade_id("nonexistent_id") == "", "get_upgrade_id on nonexistent ID returns ''")
	_check(catalog.get_upgrade_id("") == "", "get_upgrade_id on empty string returns ''")
	_check(catalog.get_upgrade_id(null) == "", "get_upgrade_id on null returns ''")
	_check(catalog.get_upgrade_id(123) == "", "get_upgrade_id on int returns ''")
	_check(catalog.get_upgrade_id("warden_hold_the_line") == "", "get_upgrade_id on a v2 card returns ''")

	# A '+' is never a base: no plus-first upgrade and no base lookup entry.
	var base_ids: Array[String] = catalog.get_base_ids()
	for plus_id: String in expected_plus:
		_check(catalog.has_card(plus_id), "plus card " + plus_id + " exists")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot itself be upgraded")
		_check(not base_ids.has(plus_id), plus_id + " is not reported as a base ID")
		_check(not catalog.get_definition(plus_id).is_empty(), plus_id + " still resolves as a definition")


func _test_mutation_isolation() -> void:
	var catalog: V3WardenPoolCards = _get_catalog()

	# Mutating top-level fields of a returned base definition.
	var mutated: Dictionary = catalog.get_definition("warden_v3_shield_toss")
	mutated["display_name"] = "Corrupted Name"
	mutated["cost"] = 99
	mutated["reward_eligible"] = false
	var fresh: Dictionary = catalog.get_definition("warden_v3_shield_toss")
	_check(fresh.get("display_name") == "Shield Toss", "base display_name protected from caller mutation")
	_check(fresh.get("cost") == 1, "base cost protected from caller mutation")
	_check(fresh.get("reward_eligible") == true, "base reward_eligible protected from caller mutation")

	# Mutating nested effects of a returned definition.
	var mutated_effects: Dictionary = catalog.get_definition("warden_v3_final_bastion")
	var effects: Dictionary = mutated_effects.get("effects", {})
	effects["block"] = 9999
	effects["injected_key"] = true
	effects.erase("taunt_next_enemy_turn")
	var fresh_bastion: Dictionary = catalog.get_definition("warden_v3_final_bastion")
	var fresh_effects: Dictionary = fresh_bastion.get("effects", {})
	_check(fresh_effects.get("block") == 12, "nested effects block protected from caller mutation")
	_check(fresh_effects.get("taunt_next_enemy_turn") == true, "nested taunt payload protected from caller erase")
	_check(not fresh_effects.has("injected_key"), "nested effects protected from key injection")

	# Mutating nested position arrays of a returned definition.
	var mutated_positions: Dictionary = catalog.get_definition("warden_v3_shield_toss")
	var from_positions: Array = mutated_positions.get("from_positions", [])
	from_positions.clear()
	var to_positions: Array = mutated_positions.get("to_positions", [])
	to_positions.append(999)
	var fresh_positions: Dictionary = catalog.get_definition("warden_v3_shield_toss")
	_check(fresh_positions.get("from_positions") == [1, 2], "nested from_positions protected from caller mutation")
	_check(fresh_positions.get("to_positions") == [1, 2, 3], "nested to_positions protected from caller mutation")

	# Mutating a returned '+' definition.
	var mutated_plus: Dictionary = catalog.get_definition("warden_v3_guard_stitch_plus")
	mutated_plus["effects"] = {"block": 0}
	mutated_plus["upgrade_of"] = "warden_v3_final_bastion"
	var fresh_plus: Dictionary = catalog.get_definition("warden_v3_guard_stitch_plus")
	_check(fresh_plus.get("effects") == {"block": 7, "guard_next_hit": true}, "plus effects protected from caller mutation")
	_check(fresh_plus.get("upgrade_of") == "warden_v3_guard_stitch", "plus upgrade_of protected from caller mutation")

	# Mutating the returned base ID array.
	var base_ids1: Array[String] = catalog.get_base_ids()
	base_ids1.clear()
	base_ids1.append("fake_card")
	var base_ids2: Array[String] = catalog.get_base_ids()
	_check(not base_ids2.is_empty(), "get_base_ids protected from caller clear")
	_check(not base_ids2.has("fake_card"), "get_base_ids protected from caller injection")
	_check(base_ids2.has("warden_v3_final_bastion"), "get_base_ids retains the authored bases after caller mutation")

	# Mutating the returned all-IDs array.
	var all_ids1: Array[String] = catalog.get_all_card_ids()
	all_ids1.clear()
	all_ids1.append("fake_card")
	var all_ids2: Array[String] = catalog.get_all_card_ids()
	_check(not all_ids2.is_empty(), "get_all_card_ids protected from caller clear")
	_check(not all_ids2.has("fake_card"), "get_all_card_ids protected from caller injection")
	_check(all_ids2.has("warden_v3_final_bastion_plus"), "get_all_card_ids retains plus IDs after caller mutation")

	# The catalog instance itself stays pristine for later callers.
	var reused: V3WardenPoolCards = catalog
	_check(reused.get_definition("warden_v3_shield_toss").get("effects") == {"damage_equal_to_owner_block": true}, "repeated lookups return the pristine payload")


func _snapshot_catalog_entries(catalog: RefCounted) -> Dictionary:
	var snapshot: Dictionary = {}
	var ids: Array[String] = catalog.get_all_card_ids()
	for card_id: String in ids:
		snapshot[card_id] = catalog.get_definition(card_id)
	return snapshot


func _test_existing_catalogs_untouched() -> void:
	var warden_pool: WardenPoolCards = WardenPoolCards.new()
	var starter_cards: StarterCards = StarterCards.new()
	var pool_before: Dictionary = _snapshot_catalog_entries(warden_pool)
	var starter_before: Dictionary = _snapshot_catalog_entries(starter_cards)
	var pool_base_before: Array[String] = warden_pool.get_base_ids()

	# Exercise the whole new catalog API, including a failed lookup, then compare the old catalogs.
	var v3: V3WardenPoolCards = _get_catalog()
	var v3_base_ids: Array[String] = v3.get_base_ids()
	var v3_all_ids: Array[String] = v3.get_all_card_ids()
	for card_id: String in v3_all_ids:
		_check(not v3.get_definition(card_id).is_empty(), "v3 definition resolves for " + card_id)
		v3.get_definition(card_id)
	_check(v3.get_definition("warden_hold_the_line").is_empty(), "v3 lookup stays closed for v2 IDs")

	_check(not pool_before.is_empty(), "v2 Warden pool snapshot is non-empty (precondition)")
	_check(not starter_before.is_empty(), "starter catalog snapshot is non-empty (precondition)")

	for card_id: String in pool_before:
		_check(warden_pool.get_definition(card_id) == pool_before[card_id], "v2 Warden definition unchanged: " + card_id)
	for card_id: String in starter_before:
		_check(starter_cards.get_definition(card_id) == starter_before[card_id], "starter definition unchanged: " + card_id)
	_check(warden_pool.get_base_ids() == pool_base_before, "v2 Warden base ID list unchanged")

	# Representative existing Warden definitions remain intact and owned by their own catalogs.
	var hold_the_line: Dictionary = warden_pool.get_definition("warden_hold_the_line")
	_check(hold_the_line.get("display_name") == "Hold the Line", "warden_hold_the_line display_name intact")
	_check(hold_the_line.get("owner") == "warden", "warden_hold_the_line owner intact")
	_check(hold_the_line.get("cost") == 1, "warden_hold_the_line cost intact")
	_check(hold_the_line.get("effects") == {"block": 5, "other_ally_block": 2}, "warden_hold_the_line effects intact")

	var draw_fire: Dictionary = warden_pool.get_definition("warden_draw_fire")
	_check(draw_fire.get("display_name") == "Draw Fire", "warden_draw_fire display_name intact")
	_check(draw_fire.get("owner") == "warden", "warden_draw_fire owner intact")
	_check(draw_fire.get("cost") == 1, "warden_draw_fire cost intact")
	_check(draw_fire.get("effects") == {"block": 6, "guarding": true, "duration": "until_next_turn"}, "warden_draw_fire effects intact")

	var counter_stitch: Dictionary = warden_pool.get_definition("warden_counter_stitch")
	_check(counter_stitch.get("display_name") == "Counter-stitch", "warden_counter_stitch display_name intact")
	_check(counter_stitch.get("owner") == "warden", "warden_counter_stitch owner intact")
	_check(counter_stitch.get("cost") == 1, "warden_counter_stitch cost intact")
	_check(counter_stitch.get("effects") == {"block": 5, "thorns": 3, "duration": "until_next_turn"}, "warden_counter_stitch effects intact")

	var strike: Dictionary = starter_cards.get_definition("warden_strike")
	_check(strike.get("display_name") == "Strike", "warden_strike display_name intact")
	_check(strike.get("owner") == "warden", "warden_strike owner intact")
	_check(strike.get("starting_copies") == 2, "warden_strike starting_copies intact")
	_check(strike.get("effects") == {"damage": 6}, "warden_strike effects intact")
	_check(starter_cards.get_definition("warden_brace").get("effects") == {"block": 7}, "warden_brace effects intact")
	_check(starter_cards.get_definition("warden_shield_bash").get("effects") == {"damage": 8, "weak": 1}, "warden_shield_bash effects intact")

	# The v2 pool still owns its representative IDs, and the new IDs belong only to the v3 catalog.
	for existing_id: String in EXISTING_WARDEN_POOL_IDS:
		_check(warden_pool.has_card(existing_id), "v2 pool still owns " + existing_id)
		_check(warden_pool.get_base_ids().has(existing_id), "v2 pool still lists " + existing_id + " as a base")
		_check(not v3.has_card(existing_id), "v3 catalog does not take over " + existing_id)
		_check(not v3_base_ids.has(existing_id), "v3 base IDs exclude " + existing_id)
	for starter_id: String in EXISTING_STARTER_IDS:
		_check(starter_cards.has_card(starter_id), "starter catalog still owns " + starter_id)
		_check(not v3.has_card(starter_id), "v3 catalog does not take over starter " + starter_id)
		_check(not v3_base_ids.has(starter_id), "v3 base IDs exclude starter " + starter_id)

	var expected_plus: Dictionary = _expected_plus_records()
	for v3_id: String in v3_all_ids:
		_check(not warden_pool.has_card(v3_id), "v2 pool does not contain v3 card " + v3_id)
		_check(not starter_cards.has_card(v3_id), "starter catalog does not contain v3 card " + v3_id)
	for plus_id: String in expected_plus:
		_check(v3.has_card(plus_id), "v3 plus exists: " + plus_id)

	# The authored starting deck is untouched and never contains a v3 ID.
	var starter_deck: Array[String] = starter_cards.get_starting_deck()
	_check(not starter_deck.is_empty(), "starting deck is non-empty (precondition)")
	for v3_id: String in v3_all_ids:
		_check(not starter_deck.has(v3_id), "starting deck does not contain v3 card " + v3_id)
	var file: FileAccess = FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "starter_deck.json is readable")
	if file != null:
		var raw: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		_check(raw is Array, "starter_deck.json is an Array")
		if raw is Array:
			_check(not (raw as Array).is_empty(), "starter_deck.json is non-empty (precondition)")
			for v3_id: String in v3_all_ids:
				_check(not (raw as Array).has(v3_id), "starter_deck.json does not contain v3 card " + v3_id)


func _test_not_in_reward_draws() -> void:
	var v3: V3WardenPoolCards = _get_catalog()
	var v3_all_ids: Array[String] = v3.get_all_card_ids()
	_check(not v3_all_ids.is_empty(), "v3 catalog has IDs to check (precondition)")

	# The live reward candidate list still comes from the v2 authored pools only.
	var candidates: Array[Dictionary] = RunPoolCardRewardOffers.get_authored_base_candidates()
	_check(not candidates.is_empty(), "authored reward candidates are non-empty (precondition)")
	var candidate_ids: Dictionary = {}
	for record: Dictionary in candidates:
		candidate_ids[String(record.get("id", ""))] = true
	for v3_id: String in v3_all_ids:
		_check(not candidate_ids.has(v3_id), "reward candidates exclude v3 card " + v3_id)
	for existing_id: String in EXISTING_WARDEN_POOL_IDS:
		_check(candidate_ids.has(existing_id), "reward candidates still include " + existing_id)

	# A real seeded reward draw never offers a v3 ID.
	var run_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	run_rng.seed = 255031
	var generated: Dictionary = RunPoolCardRewardOffers.generate_from_authored_pools(run_rng, ["warden", "seamstress", "tinker"])
	_check(generated.get("ok") == true, "seeded authored reward draw succeeds (precondition)")
	var offers: Array = generated.get("offers", [])
	_check(offers.size() == 3, "seeded authored reward draw offers three cards (precondition)")
	_check(not offers.is_empty(), "seeded authored reward draw returned offers (precondition)")
	for offer: Dictionary in offers:
		var offered_id: String = String(offer.get("id", ""))
		_check(not offered_id.is_empty(), "offered card has an ID (precondition)")
		_check(not v3_all_ids.has(offered_id), "reward draw does not offer v3 card " + offered_id)

	# Fail-closed reward resolution: the v3 IDs are not resolvable until the later wiring task.
	for v3_id: String in v3_all_ids:
		_check(RunPoolCardRewardOffers.resolve_reward_definition(v3_id).is_empty(), "v3 card is not reward-resolvable yet: " + v3_id)
	_check(not RunPoolCardRewardOffers.resolve_reward_definition("warden_hold_the_line").is_empty(), "v2 Warden card still reward-resolvable")
