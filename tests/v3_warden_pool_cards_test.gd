extends SceneTree
## Deterministic headless test for the standalone V3WardenPoolCards catalog (V3-1).
## Verifies the eight authored v3 Warden base cards and their eight '+' upgrades field by field,
## catalog isolation (unknown/invalid IDs, base lookup, caller mutation) and that the existing v2
## Warden pool, starter cards and live reward draws are untouched. The v3 catalog is deliberately
## NOT wired into combat, rewards, the map or shops yet, so nothing here drives a live card.
##
## The second half covers the scene-free paid resolver for the authored Rivet Pummel base and '+'
## printings (CombatWardenV3RivetCards): authentic two-strike/Block-before-HP receipts, the shared
## Pinned token rule (cross-hero +5 once, same-hero no bonus, no pin on a lethal cast) and
## fail-closed refusals that leave every model, the token map and the seeded RNG untouched.


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
	_test_rivet_catalog_authentication()
	_test_rivet_paid_two_hits()
	_test_rivet_first_hit_lethal()
	_test_rivet_pinned_provenance()
	_test_rivet_status_rounding()
	_test_rivet_rejections()
	_test_rivet_spent_copy_and_energy()
	_test_rivet_seeded_replay()
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


# --- Rivet Pummel paid two-strike/Pinned resolver (scene-free rules slice) -------------------
#
# Every fixture below is a real seeded CombatDeck that genuinely holds the named ID (never a
# fabricated status-only receipt), a real authored starter CombatParty, shipped run_enemies.json
# records, and one shared CombatPinned token map. No app, hand, reward or mounted wiring is claimed
# here: the resolver is the callable rules layer that a later task routes the live hand into.

const RIVET_ID := "warden_v3_rivet_pummel"
const RIVET_PLUS_ID := "warden_v3_rivet_pummel_plus"
const RIVET_FILLERS := ["filler_stitch", "filler_thread", "filler_needle", "filler_ribbon", "filler_twig"]
const RIVET_HEROES_PATH := "res://data/heroes/starter_party.json"
const RIVET_ENEMIES_PATH := "res://data/enemies/run_enemies.json"

var _rivet_enemy_cache: Array[Dictionary] = []


## AC1: only the two authored records are supported, and both still print exactly their catalog
## line: cost 2, FROM [1,2], TO [1,2], two separate hits of 3/4, pinned true, reward-only.
func _test_rivet_catalog_authentication() -> void:
	var catalog: V3WardenPoolCards = _get_catalog()
	var service := _rivet_service()
	var expected := {
		RIVET_ID: {"display_name": "Rivet Pummel", "damage": 3, "eligible": true},
		RIVET_PLUS_ID: {"display_name": "Rivet Pummel+", "damage": 4, "eligible": false},
	}
	for card_id: String in expected:
		var line: Dictionary = expected[card_id]
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), card_id + ": authored catalog record exists")
		_check(definition.get("id") == card_id, card_id + ": id matches its key")
		_check(definition.get("display_name") == line["display_name"], card_id + ": display name")
		_check(definition.get("owner") == "warden", card_id + ": owner is the Warden")
		_check(definition.get("cost") == 2, card_id + ": cost is exactly 2")
		_check(definition.get("from_positions") == [1, 2], card_id + ": FROM is exactly 1-2")
		_check(definition.get("to_positions") == [1, 2], card_id + ": TO is exactly 1-2 (no third slot)")
		_check(definition.get("target_kind") == "enemy_single", card_id + ": targets one enemy")
		_check(definition.get("effects") == {"damage": line["damage"], "hits": 2, "pinned": true},
			card_id + ": exact two-hit pinned effect line")
		_check(definition.get("starting_copies") == 0, card_id + ": reward-only, zero starting copies")
		_check(definition.get("rarity") == "uncommon", card_id + ": rarity is uncommon")
		_check(definition.get("reward_eligible") == line["eligible"],
			card_id + ": authored reward eligibility")
		_check(definition.get("illustration_path")
			== "res://assets/paper/cards/warden_v3_rivet_pummel.png", card_id + ": shared art path")
		_check(service.is_supported_card(card_id), card_id + ": the resolver authenticates the ID")

	_check(catalog.get_definition(RIVET_ID).get("upgrade_id") == RIVET_PLUS_ID,
		"the base points at its authored plus")
	_check(catalog.get_definition(RIVET_PLUS_ID).get("upgrade_of") == RIVET_ID,
		"the plus points back at its base")
	_check(catalog.get_definition(RIVET_ID).get("effects")
		!= catalog.get_definition(RIVET_PLUS_ID).get("effects"),
		"the plus differs from the base in printed damage")

	# Unrelated Warden v3 reward cards, other heroes, v2 cards and malformed IDs are unsupported.
	for unsupported: String in ["warden_v3_shield_toss", "warden_v3_shield_toss_plus",
			"warden_v3_helmet_rattle", "warden_v3_helmet_rattle_plus", "warden_v3_guard_stitch",
			"warden_v3_iron_taunt", "warden_v3_buckle_rebound", "warden_v3_shieldwall_chorus",
			"warden_v3_final_bastion", "warden_v3_rivet_pummel_ultra",
			"warden_v3_rivet_pummel_plus_plus", "warden_hold_the_line", "warden_strike",
			"seamstress_prick", "tinker_pop_shot", "WARDEN_V3_RIVET_PUMMEL", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not a Rivet Pummel printing for this resolver")
	_check(not service.is_supported_card(5) and not service.is_supported_card(null)
		and not service.is_supported_card({}), "non-string IDs are never supported")

	# A rewritten catalog record for an otherwise valid, genuinely held ID is refused: a green
	# unsupported-ID check alone would not prove catalog authentication.
	var forged_cost := V3WardenPoolCards.new()
	forged_cost._definitions[RIVET_ID]["cost"] = 1
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "forged one-cost record", "catalog_mismatch",
		CombatWardenV3RivetCards.new(forged_cost))
	var forged_damage := V3WardenPoolCards.new()
	forged_damage._definitions[RIVET_ID]["effects"] = {"damage": 9, "hits": 2, "pinned": true}
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "forged nine-damage record", "catalog_mismatch",
		CombatWardenV3RivetCards.new(forged_damage))
	var forged_pin := V3WardenPoolCards.new()
	forged_pin._definitions[RIVET_PLUS_ID]["effects"] = {"damage": 4, "hits": 2}
	_rivet_rejected(_rivet_deck(RIVET_PLUS_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_PLUS_ID, 1, "forged unpinned plus record", "catalog_mismatch",
		CombatWardenV3RivetCards.new(forged_pin))


## AC2: base and plus each pay 2 energy, discard exactly one held copy, land two independently
## observed strikes with Block overflow into HP, keep every other actor and the RNG untouched, and
## pin the surviving target for the Warden.
func _test_rivet_paid_two_hits() -> void:
	for card_id: String in [RIVET_ID, RIVET_PLUS_ID]:
		var printed: int = 3 if card_id == RIVET_ID else 4
		var party := _rivet_party()
		var enemies := _rivet_enemies(["scissor_crab", "button_guard"])
		var pins := _rivet_pinned()
		_check(enemies.gain_block(1, 2), card_id + ": target really holds two Block")
		_check(enemies.gain_block(2, 4), card_id + ": bystander really holds four Block")
		_check(enemies.apply_statuses({2: {"weak": 2}}),
			card_id + ": bystander really carries its own Weak 2")
		var bystander_before: Dictionary = enemies.get_enemy(2)
		var target_hp_before: int = int(enemies.get_enemy(1)["hp"])
		var deck := _rivet_deck(card_id)
		var before := _rivet_models(deck, party, enemies, pins)
		var result: Dictionary = _rivet_service().play_card(deck, party, enemies, pins, card_id, 1)

		_check(result.get("ok") == true and result.get("reason") == "applied",
			card_id + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 2
			and result.get("energy_spent") == 2, card_id + ": receipt names the card and its two energy")
		_check(result.get("owner_position") == 1 and result.get("target_position") == 1,
			card_id + ": receipt reports the real Warden and target slots")

		var hits: Array = result.get("hits", [])
		_check(hits.size() == 2 and result.get("hit_count") == 2,
			card_id + ": two independently resolved hits")
		if hits.size() == 2:
			_check(hits[0].get("hit") == 0 and hits[1].get("hit") == 1,
				card_id + ": hits are reported in strike order")
			_check(hits[0].get("base_damage") == printed and hits[0].get("damage") == printed
				and hits[0].get("pin_bonus") == 0,
				card_id + ": the first strike is exactly the printed damage")
			_check(hits[0].get("block_absorbed") == 2 and hits[0].get("hp_loss") == printed - 2,
				card_id + ": the first strike spends the target's Block before HP")
			_check(hits[1].get("base_damage") == printed and hits[1].get("damage") == printed,
				card_id + ": the second strike is its own printed damage, never one aggregate")
			_check(hits[1].get("block_absorbed") == 0 and hits[1].get("hp_loss") == printed,
				card_id + ": the spent Block cannot absorb the second strike")
			_check(hits[0].get("pin_consumed") == false and hits[1].get("pin_consumed") == false,
				card_id + ": no token existed to consume")
		_check(result.get("pinned") == true and result.get("pinner") == "warden"
			and pins.pinner_for_enemy(1) == "warden",
			card_id + ": the surviving target is pinned with Warden provenance")
		_check(pins.bonus_for_attack(enemies, 1, "warden") == 0,
			card_id + ": the Warden's own pin is worth no bonus to the Warden")
		_check(result.get("target_slain") == false
			and result.get("target_hp") == target_hp_before - (printed - 2) - printed
			and result.get("target_block") == 0,
			card_id + ": receipt reports the real surviving target state")

		var expected_hand: Array = before["hand"].duplicate()
		expected_hand.remove_at(expected_hand.find(card_id))
		var expected_discard: Array = before["discard"].duplicate()
		expected_discard.append(card_id)
		_check(deck.hand == expected_hand and deck.discard_pile == expected_discard,
			card_id + ": discards exactly one copy and preserves every other card")
		_check(deck.energy == 1 and deck.hand.size() == before["hand"].size() - 1,
			card_id + ": pays exactly two of three energy")
		_check(enemies.get_enemy(2) == bystander_before,
			card_id + ": the other foe keeps HP, Block and statuses")
		_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
			card_id + ": the cast draws no seeded RNG")
		_check(_rivet_models(deck, party, enemies, pins)
			== _rivet_expected_success(before, card_id, 1, 2, (printed - 2) + printed, "warden"),
			card_id + ": exactly one charge, one discard, two hits and one Warden pin")

	# FROM 1-2: the authentic card also plays from the middle seat onto the second foe slot.
	var moved_party := _rivet_moved_party(2)
	var moved_enemies := _rivet_enemies(["fray_scavenger", "button_guard"])
	var moved_pins := _rivet_pinned()
	var moved_deck := _rivet_deck(RIVET_ID, 913)
	var moved: Dictionary = _rivet_service().play_card(moved_deck, moved_party, moved_enemies,
		moved_pins, RIVET_ID, 2)
	_check(moved.get("ok") == true and moved.get("owner_position") == 2
		and moved.get("target_position") == 2, "the middle seat plays onto the second foe slot")
	_check((moved.get("hits") as Array).size() == 2 and moved.get("pinner") == "warden"
		and moved_pins.pinner_for_enemy(2) == "warden",
		"the middle-seat cast resolves both hits and pins its own target")
	_check(moved_pins.pinner_for_enemy(1) == "", "only the chosen slot is pinned")


## AC2: a lethal first strike omits the second hit and adds no new pin.
func _test_rivet_first_hit_lethal() -> void:
	for card_id: String in [RIVET_ID, RIVET_PLUS_ID]:
		var printed: int = 3 if card_id == RIVET_ID else 4
		var party := _rivet_party()
		var enemies := _rivet_enemies(["pin_skitter"])
		var pins := _rivet_pinned()
		var full_hp: int = int(enemies.get_enemy(1)["hp"])
		_check(full_hp > printed, card_id + ": fixture foe starts above one printed strike")
		_check(enemies.apply_damage(1, full_hp - printed),
			card_id + ": the foe is whittled through the real damage path")
		_check(enemies.get_enemy(1)["hp"] == printed and not enemies.is_slain(1),
			card_id + ": the target is alive on exactly one printed strike of HP")
		var deck := _rivet_deck(card_id)
		var before := _rivet_models(deck, party, enemies, pins)
		var result: Dictionary = _rivet_service().play_card(deck, party, enemies, pins, card_id, 1)
		var hits: Array = result.get("hits", [])
		_check(result.get("ok") == true and hits.size() == 1 and result.get("hit_count") == 1,
			card_id + ": a lethal first strike omits the second hit")
		if hits.size() == 1:
			_check(hits[0].get("damage") == printed and hits[0].get("hp_loss") == printed
				and hits[0].get("block_absorbed") == 0,
				card_id + ": the single landed strike is lethal")
		_check(enemies.is_slain(1) and result.get("target_slain") == true,
			card_id + ": the target is really slain in its original slot")
		_check(result.get("pinned") == false and result.get("pinner") == ""
			and pins.pinner_for_enemy(1) == "",
			card_id + ": a slain target is never pinned after the strikes")
		_check(_rivet_models(deck, party, enemies, pins)
			== _rivet_expected_success(before, card_id, 1, 0, printed, ""),
			card_id + ": exactly one paid cast, one hit and no new token")


## AC2: the shared Pinned rule is reused, never reimplemented. An earlier other-hero pin boosts
## only the first strike and is consumed once; an existing Warden pin gives no bonus; a lethal
## cross-hero cast spends the old token and lays nothing new.
func _test_rivet_pinned_provenance() -> void:
	var party := _rivet_party()
	var enemies := _rivet_enemies(["scissor_crab"])
	var pins := _rivet_pinned()
	_check(pins.pin_enemy(enemies, 1, "seamstress"),
		"the shared token really starts on another hero")
	_check(pins.pinner_for_enemy(1) == "seamstress"
		and pins.bonus_for_attack(enemies, 1, "warden") == 5,
		"the cross-hero token is worth its +5 to the Warden (precondition)")
	var deck := _rivet_deck(RIVET_ID)
	var before := _rivet_models(deck, party, enemies, pins)
	var result: Dictionary = _rivet_service().play_card(deck, party, enemies, pins, RIVET_ID, 1)
	var hits: Array = result.get("hits", [])
	_check(result.get("ok") == true and hits.size() == 2,
		"the cross-hero cast resolves both strikes")
	if hits.size() == 2:
		_check(hits[0].get("pin_bonus") == 5 and hits[0].get("base_damage") == 8
			and hits[0].get("damage") == 8 and hits[0].get("pin_consumed") == true,
			"the other-hero +5 boosts the first strike and is consumed")
		_check(hits[1].get("pin_bonus") == 0 and hits[1].get("base_damage") == 3
			and hits[1].get("damage") == 3 and hits[1].get("pin_consumed") == false,
			"the consumed token cannot boost the second strike")
	_check(result.get("pinned") == true and pins.pinner_for_enemy(1) == "warden",
		"the surviving target is then pinned by the Warden")
	_check(pins.bonus_for_attack(enemies, 1, "warden") == 0,
		"the freshly laid Warden pin pays no bonus to the Warden")
	_check(_rivet_models(deck, party, enemies, pins)
		== _rivet_expected_success(before, RIVET_ID, 1, 0, 11, "warden"),
		"the cross-hero cast lands 8 + 3 damage and replaces the token once")

	# An existing Warden pin is never a self-bonus and survives this same-hero cast.
	var own_party := _rivet_party()
	var own_enemies := _rivet_enemies(["scissor_crab"])
	var own_pins := _rivet_pinned()
	_check(own_pins.pin_enemy(own_enemies, 1, "warden"),
		"the Warden really pinned the target earlier")
	var own_deck := _rivet_deck(RIVET_PLUS_ID, 555)
	var own_before := _rivet_models(own_deck, own_party, own_enemies, own_pins)
	var own: Dictionary = _rivet_service().play_card(own_deck, own_party, own_enemies, own_pins,
		RIVET_PLUS_ID, 1)
	var own_hits: Array = own.get("hits", [])
	_check(own.get("ok") == true and own_hits.size() == 2,
		"the same-hero cast resolves both strikes")
	if own_hits.size() == 2:
		_check(own_hits[0].get("pin_bonus") == 0 and own_hits[0].get("damage") == 4
			and own_hits[0].get("pin_consumed") == false,
			"an existing Warden pin gives no bonus and is not consumed")
		_check(own_hits[1].get("pin_bonus") == 0 and own_hits[1].get("damage") == 4,
			"the second strike also carries no self-bonus")
	_check(own.get("pinned") == true and own_pins.pinner_for_enemy(1) == "warden",
		"the Warden keeps provenance on its own target")
	_check(_rivet_models(own_deck, own_party, own_enemies, own_pins)
		== _rivet_expected_success(own_before, RIVET_PLUS_ID, 1, 0, 8, "warden"),
		"the same-hero cast lands 4 + 4 and leaves the token in place")

	# A lethal cross-hero cast still consumes the old token and lays no new one.
	var lethal_enemies := _rivet_enemies(["pin_skitter"])
	var lethal_pins := _rivet_pinned()
	var lethal_hp: int = int(lethal_enemies.get_enemy(1)["hp"])
	_check(lethal_enemies.apply_damage(1, lethal_hp - 3)
		and lethal_enemies.get_enemy(1)["hp"] == 3,
		"the lethal fixture foe is whittled to three HP")
	_check(lethal_pins.pin_enemy(lethal_enemies, 1, "tinker"),
		"the lethal fixture target really carries another hero's pin")
	var lethal_deck := _rivet_deck(RIVET_ID, 77)
	var lethal := _rivet_service().play_card(lethal_deck, _rivet_party(), lethal_enemies,
		lethal_pins, RIVET_ID, 1)
	var lethal_hits: Array = lethal.get("hits", [])
	_check(lethal.get("ok") == true and lethal_hits.size() == 1,
		"the lethal cross-hero cast lands one strike")
	if lethal_hits.size() == 1:
		_check(lethal_hits[0].get("pin_bonus") == 5 and lethal_hits[0].get("base_damage") == 8,
			"the lethal strike still carries the other hero's +5")
	_check(lethal.get("pinned") == false and lethal_pins.pinner_for_enemy(1) == "",
		"the lethal cast leaves no pin behind")


## AC2: Weak/Exposed use the shared floor-once arithmetic, and legal non-damage tokens are
## admitted without being consumed or dropped from their actor.
func _test_rivet_status_rounding() -> void:
	var status_cases := [
		{"label": "Weak", "hero": {"weak": 1}, "foe": {}, "damage": {3: 2, 4: 3}},
		{"label": "Exposed", "hero": {}, "foe": {"exposed": 2}, "damage": {3: 4, 4: 6}},
		{"label": "Weak and Exposed", "hero": {"weak": 3}, "foe": {"exposed": 1},
			"damage": {3: 3, 4: 4}},
	]
	for status_case: Dictionary in status_cases:
		for card_id: String in [RIVET_ID, RIVET_PLUS_ID]:
			var label: String = status_case["label"] + " " + card_id
			var party := _rivet_party()
			var enemies := _rivet_enemies(["scissor_crab"])
			var pins := _rivet_pinned()
			party._heroes[0]["statuses"] = (status_case["hero"] as Dictionary).duplicate(true)
			enemies._enemies[0]["statuses"] = (status_case["foe"] as Dictionary).duplicate(true)
			var deck := _rivet_deck(card_id, 8081)
			var result: Dictionary = _rivet_service().play_card(deck, party, enemies, pins,
				card_id, 1)
			var printed: int = 3 if card_id == RIVET_ID else 4
			var expected_hit: int = status_case["damage"][printed]
			var hits: Array = result.get("hits", [])
			_check(result.get("ok") == true and hits.size() == 2, label + ": both strikes land")
			if hits.size() == 2:
				_check(hits[0].get("damage") == expected_hit
					and hits[1].get("damage") == expected_hit,
					label + ": both strikes are floored once to " + str(expected_hit))
			_check(party.get_hero(1)["statuses"] == status_case["hero"],
				label + ": the attacker's own statuses are untouched")
			_check(enemies.get_enemy(1)["statuses"] == status_case["foe"],
				label + ": the defender's statuses are untouched")

	# A genuine Dodge on the Warden, Blind on the foe and the literal Fear marker are all legal
	# authoritative state: the paid cast still lands both hits and none of them is spent.
	var token_party := _rivet_party()
	var token_enemies := _rivet_enemies(["scissor_crab"])
	var token_pins := _rivet_pinned()
	token_party._heroes[0]["statuses"] = {"dodge_next_attack": 1, "cannot_buff_next_turn": true,
		"weak": 1}
	token_enemies._enemies[0]["statuses"] = {"blind_next_attack": 1}
	var token_deck := _rivet_deck(RIVET_ID, 4242)
	var token: Dictionary = _rivet_service().play_card(token_deck, token_party, token_enemies,
		token_pins, RIVET_ID, 1)
	var token_hits: Array = token.get("hits", [])
	_check(token.get("ok") == true and token_hits.size() == 2,
		"legal non-damage tokens do not turn a paid cast into a phantom turn")
	if token_hits.size() == 2:
		_check(token_hits[0].get("damage") == 2 and token_hits[1].get("damage") == 2,
			"only the Weak counter adjusts the strikes")
	_check(token_party.get_hero(1)["statuses"]
		== {"dodge_next_attack": 1, "cannot_buff_next_turn": true, "weak": 1},
		"the Warden's Dodge and Fear tokens are neither spent nor dropped")
	_check(token_enemies.get_enemy(1)["statuses"] == {"blind_next_attack": 1},
		"the foe's Blind token is neither spent nor dropped")


## AC3: without the genuine affordable held copy, a living correctly positioned Warden, a legal
## living target or valid supplied status/token state, the cast is refused before any mutation.
func _test_rivet_rejections() -> void:
	# Unsupported and unrelated IDs, even when genuinely held.
	_rivet_rejected(_rivet_deck("warden_v3_shield_toss"), _rivet_party(),
		_rivet_enemies(["scissor_crab"]), _rivet_pinned(), "warden_v3_shield_toss", 1,
		"held unrelated Warden v3 card", "unsupported_card")
	_rivet_rejected(_rivet_deck("seamstress_prick"), _rivet_party(),
		_rivet_enemies(["scissor_crab"]), _rivet_pinned(), "seamstress_prick", 1,
		"held non-Warden card", "unsupported_card")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), "warden_v3_rivet_pummel_ultra", 1, "invalid Rivet-like ID",
		"unsupported_card")

	# The genuine base is not held: only its plus is in the seeded hand.
	_rivet_rejected(_rivet_deck(RIVET_PLUS_ID), _rivet_party(),
		_rivet_enemies(["scissor_crab"]), _rivet_pinned(), RIVET_ID, 1,
		"the base is not in the hand", "card_not_held")

	# Insufficient energy through a genuine spend off the shared energy pool.
	var drained := _rivet_deck(RIVET_ID)
	_check(drained.try_spend_energy(2) and drained.energy == 1,
		"energy fixture really holds only one energy")
	_rivet_rejected(drained, _rivet_party(), _rivet_enemies(["scissor_crab"]), _rivet_pinned(),
		RIVET_ID, 1, "one energy cannot pay two", "insufficient_energy")

	# A downed Warden cannot swing.
	var downed_party := _rivet_party()
	var warden_hp: int = int(downed_party.get_hero(1)["hp"])
	_check(downed_party.apply_damage(1, warden_hp) and downed_party.get_hero(1)["hp"] == 0,
		"caster fixture really downed the Warden")
	_rivet_rejected(_rivet_deck(RIVET_ID), downed_party, _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "a downed Warden cannot swing", "owner_torn")

	# Out of position: FROM is printed as 1-2 only.
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_moved_party(3),
		_rivet_enemies(["scissor_crab"]), _rivet_pinned(), RIVET_ID, 1,
		"the back seat is not a printed FROM slot", "invalid_owner_position")

	# Dead, illegal and missing target slots (a two-foe battle, so the fight is still live).
	var dead_enemies := _rivet_enemies(["scissor_crab", "button_guard"])
	_check(dead_enemies.apply_damage(1, int(dead_enemies.get_enemy(1)["hp"]))
		and dead_enemies.is_slain(1), "target fixture really slew the foe in slot one")
	_check(not dead_enemies.is_victorious(), "the dead-target fixture still has a living foe")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), dead_enemies, _rivet_pinned(),
		RIVET_ID, 1, "a slain target cannot be struck", "dead_target")
	var won_enemies := _rivet_enemies(["scissor_crab"])
	_check(won_enemies.apply_damage(1, int(won_enemies.get_enemy(1)["hp"]))
		and won_enemies.is_victorious(), "victory fixture really slew the whole roster")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), won_enemies, _rivet_pinned(),
		RIVET_ID, 1, "a won battle refuses further casts", "invalid_roster")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(),
		_rivet_enemies(["scissor_crab", "button_guard", "spool_stalker"]), _rivet_pinned(),
		RIVET_ID, 3, "slot three is outside the printed TO line", "invalid_target")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 0, "slot zero is not a target", "invalid_target")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 2, "a second slot that does not exist", "invalid_target")

	# An inactive shared turn cannot pay for anything.
	var idle := CombatDeck.new([RIVET_ID, RIVET_FILLERS[0], RIVET_FILLERS[1], RIVET_FILLERS[2],
		RIVET_FILLERS[3]], _rivet_rng(19))
	_check(not idle.turn_active, "idle fixture really has no active turn")
	_rivet_rejected(idle, _rivet_party(), _rivet_enemies(["scissor_crab"]), _rivet_pinned(),
		RIVET_ID, 1, "no active turn", "inactive_turn")

	# Missing or non-authoritative shared Pinned state.
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		null, RIVET_ID, 1, "no shared Pinned authority", "invalid_pinned_authority")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		["warden"], RIVET_ID, 1, "a plain Array is not the shared Pinned authority",
		"invalid_pinned_authority")

	# Malformed authoritative status state on the caster or the foe.
	var bad_negative := _rivet_party()
	bad_negative._heroes[0]["statuses"] = {"weak": -1}
	_rivet_rejected(_rivet_deck(RIVET_ID), bad_negative, _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "negative attacker counter", "malformed_statuses")
	var bad_dodge := _rivet_party()
	bad_dodge._heroes[0]["statuses"] = {"dodge_next_attack": 2}
	_rivet_rejected(_rivet_deck(RIVET_ID), bad_dodge, _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "non-canonical Dodge token", "malformed_statuses")
	var bad_fear := _rivet_party()
	bad_fear._heroes[0]["statuses"] = {"cannot_buff_next_turn": 1}
	_rivet_rejected(_rivet_deck(RIVET_ID), bad_fear, _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "Fear must be the literal boolean true",
		"malformed_statuses")
	var bad_foe := _rivet_enemies(["scissor_crab"])
	bad_foe._enemies[0]["statuses"] = {"unknown_status": 1}
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), bad_foe, _rivet_pinned(),
		RIVET_ID, 1, "unknown defender status key", "malformed_statuses")
	var bad_foe_count := _rivet_enemies(["scissor_crab"])
	bad_foe_count._enemies[0]["statuses"] = {"weak": "two"}
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), bad_foe_count, _rivet_pinned(),
		RIVET_ID, 1, "non-int defender counter", "malformed_statuses")

	# Corrupt shared token maps fail closed before payment.
	var bad_slot := _rivet_pinned()
	bad_slot._pinner_by_position[9] = "seamstress"
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		bad_slot, RIVET_ID, 1, "token on a slot that does not exist", "malformed_pinned")
	var bad_pinner := _rivet_pinned()
	bad_pinner._pinner_by_position[1] = 7
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		bad_pinner, RIVET_ID, 1, "non-string pinner identity", "malformed_pinned")
	var unknown_pinner := _rivet_pinned()
	unknown_pinner._pinner_by_position[1] = "gargoyle"
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), _rivet_enemies(["scissor_crab"]),
		unknown_pinner, RIVET_ID, 1, "unknown pinner identity", "malformed_pinned")

	# Null and invalid models.
	_rivet_rejected(null, _rivet_party(), _rivet_enemies(["scissor_crab"]), _rivet_pinned(),
		RIVET_ID, 1, "null deck", "invalid_request")
	_rivet_rejected(_rivet_deck(RIVET_ID), null, _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "null party", "invalid_request")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), null, _rivet_pinned(), RIVET_ID, 1,
		"null enemies", "invalid_request")
	_rivet_rejected(_rivet_deck(RIVET_ID), CombatParty.new([]),
		_rivet_enemies(["scissor_crab"]), _rivet_pinned(), RIVET_ID, 1, "invalid party roster",
		"invalid_roster")
	_rivet_rejected(_rivet_deck(RIVET_ID), _rivet_party(), CombatEnemies.new([]),
		_rivet_pinned(), RIVET_ID, 1, "invalid enemy roster", "invalid_roster")

	# A Warden-free party has no legal caster at all.
	var no_warden: Array = [{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26},
		{"id": "rag_duelist", "max_hp": 28}]
	var no_warden_party := CombatParty.new(no_warden)
	_check(no_warden_party.is_valid(), "Warden-free fixture really builds a valid party")
	_rivet_rejected(_rivet_deck(RIVET_ID), no_warden_party, _rivet_enemies(["scissor_crab"]),
		_rivet_pinned(), RIVET_ID, 1, "no Warden in the party", "owner_missing")


## AC3: a cast consumes its only held copy and its energy, so a second attempt must fail without
## touching anything, and a held copy with one energy left is refused rather than played free.
func _test_rivet_spent_copy_and_energy() -> void:
	var deck := CombatDeck.new([RIVET_ID, RIVET_FILLERS[0], RIVET_FILLERS[1], RIVET_FILLERS[2],
		RIVET_FILLERS[3]], _rivet_rng(6101))
	_check(deck.start_turn() and deck.energy == 3 and deck.hand.size() == 5
		and deck.hand.count(RIVET_ID) == 1,
		"single-copy fixture draws exactly one authentic copy and three energy")
	var party := _rivet_party()
	var enemies := _rivet_enemies(["scissor_crab"])
	var pins := _rivet_pinned()
	var once: Dictionary = _rivet_service().play_card(deck, party, enemies, pins, RIVET_ID, 1)
	_check(once.get("ok") == true and (once.get("hits") as Array).size() == 2,
		"the single held copy really plays both strikes")
	var spent := _rivet_models(deck, party, enemies, pins)
	_check(deck.energy == 1 and deck.discard_pile.count(RIVET_ID) == 1
		and not deck.hand.has(RIVET_ID),
		"the cast spent two energy and moved exactly one copy to the discard")
	_rivet_rejected(deck, party, enemies, pins, RIVET_ID, 1,
		"a second attempt after spending the only copy", "card_not_held")
	_check(_rivet_models(deck, party, enemies, pins) == spent,
		"the second attempt leaves the paid state exactly as it was")

	# A genuinely held copy with only one energy left is refused, not silently free.
	var full := CombatDeck.new([RIVET_ID, RIVET_ID, RIVET_ID, RIVET_ID, RIVET_ID], _rivet_rng(6102))
	_check(full.start_turn() and full.energy == 3 and full.hand.count(RIVET_ID) == 5,
		"multi-copy fixture really holds five copies and three energy")
	var full_party := _rivet_party()
	var full_enemies := _rivet_enemies(["scissor_crab"])
	var full_pins := _rivet_pinned()
	var first: Dictionary = _rivet_service().play_card(full, full_party, full_enemies, full_pins,
		RIVET_ID, 1)
	_check(first.get("ok") == true and full.energy == 1 and full.hand.count(RIVET_ID) == 4,
		"the first of five copies is paid for from real energy")
	var one_left := _rivet_models(full, full_party, full_enemies, full_pins)
	_rivet_rejected(full, full_party, full_enemies, full_pins, RIVET_ID, 1,
		"a held two-cost copy with one energy", "insufficient_energy")
	_check(_rivet_models(full, full_party, full_enemies, full_pins) == one_left,
		"the energy refusal changes no card, energy, hero, enemy, pin or RNG state")


## The same seed and the same request sequence produce identical state and receipts.
func _test_rivet_seeded_replay() -> void:
	var first := _rivet_replay_run(8642)
	var second := _rivet_replay_run(8642)
	_check(first == second, "seeded replay produces an identical final state and receipts")
	_check(first["rng_state"] == second["rng_state"],
		"seeded replay leaves both runs on the same run RNG state")
	var results: Array = first["results"]
	_check(results.size() == 3 and results[0].get("ok") == true
		and (results[0].get("hits") as Array).size() == 2,
		"seeded replay lands the authentic two-strike cast")
	_check(results[1].get("ok") == false and results[1].get("reason") == "card_not_held"
		and results[2].get("ok") == false
		and results[2].get("reason") == "insufficient_energy",
		"seeded replay keeps both genuine refusals")


func _rivet_replay_run(seed_value: int) -> Dictionary:
	var party := _rivet_party()
	var enemies := _rivet_enemies(["scissor_crab", "button_guard"])
	var pins := _rivet_pinned()
	var deck := _rivet_deck(RIVET_ID, seed_value)
	var service := _rivet_service()
	var results: Array = []
	results.append(service.play_card(deck, party, enemies, pins, RIVET_ID, 1))
	results.append(service.play_card(deck, party, enemies, pins, RIVET_PLUS_ID, 1))
	results.append(service.play_card(deck, party, enemies, pins, RIVET_ID, 2))
	var snapshot := _rivet_models(deck, party, enemies, pins)
	snapshot["results"] = results
	return snapshot


func _rivet_service() -> CombatWardenV3RivetCards:
	return CombatWardenV3RivetCards.new()


func _rivet_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real five-card hand from six cards, so at least one copy of the named ID is genuinely held.
func _rivet_deck(card_id: String, seed_value: int = 6452) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, RIVET_FILLERS[0], RIVET_FILLERS[1],
		RIVET_FILLERS[2], RIVET_FILLERS[3]]
	var deck := CombatDeck.new(ids, _rivet_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) >= 1,
		card_id + ": real seeded five-card hand genuinely holds the copy")
	return deck


func _rivet_party() -> CombatParty:
	var raw: String = FileAccess.get_file_as_string(RIVET_HEROES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array
		and (parsed as Array).size() == CombatParty.PARTY_SIZE,
		"real authored starter party file supplies all three heroes")
	if not parsed is Array or (parsed as Array).size() != CombatParty.PARTY_SIZE:
		return CombatParty.new([])
	for hero in parsed:
		if hero is Dictionary and hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(parsed)
	_check(party.is_valid() and party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("hp") == 40,
		"valid real CombatParty with the 40-HP Warden in the front seat")
	return party


## A genuine adjacent swap through the real position rules, not a hand-built roster.
func _rivet_moved_party(position: int) -> CombatParty:
	var party := _rivet_party()
	var move_id := "fixture_rivet_warden_forward"
	var moving := CombatDeck.new([move_id, move_id, move_id], _rivet_rng(346))
	_check(moving.start_turn(), "position fixture begins a legitimate shared turn")
	var definition := {"id": move_id, "owner": "warden", "cost": 0,
		"from_positions": [1, 2, 3], "action_kind": "adjacent_swap", "direction": 1}
	for step in range(position - 1):
		_check(CombatPositionSwaps.play_move_card(moving, party, move_id, definition),
			"actual adjacent move shifts the Warden to " + str(step + 2))
	_check(party.get_hero(position).get("id") == "warden"
		and party.get_hero(position).get("position") == position,
		"Warden identity is really at actual slot " + str(position))
	return party


func _rivet_pinned() -> CombatPinned:
	return CombatPinned.new()


func _rivet_enemies(ids: Array) -> CombatEnemies:
	var definitions: Array = []
	for enemy_id: String in ids:
		definitions.append(_rivet_enemy_record(enemy_id))
	var enemies := CombatEnemies.new(definitions)
	var actual: Array = []
	for record in enemies.get_enemies():
		actual.append(record.get("id"))
	_check(enemies.is_valid() and actual == ids,
		"real run_enemies.json roster " + str(ids))
	return enemies


func _rivet_enemy_record(enemy_id: String) -> Dictionary:
	for record in _rivet_enemy_catalog():
		if record.get("id") == enemy_id:
			return record.duplicate(true)
	_check(false, "shipped run_enemies.json contains " + enemy_id)
	return {}


func _rivet_enemy_catalog() -> Array[Dictionary]:
	if not _rivet_enemy_cache.is_empty():
		return _rivet_enemy_cache
	var raw: String = FileAccess.get_file_as_string(RIVET_ENEMIES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array and not (parsed as Array).is_empty(),
		"shipped run_enemies.json catalog loads")
	if not parsed is Array:
		return []
	for entry in parsed:
		if not entry is Dictionary:
			continue
		var record: Dictionary = entry.duplicate(true)
		var max_hp: Variant = record.get("max_hp")
		if max_hp is float and max_hp == floor(max_hp):
			record["max_hp"] = int(max_hp)
		_rivet_enemy_cache.append(record)
	return _rivet_enemy_cache


## A rejection must report no hit, no spend and no pin, and leave every mutable model plus the
## shared token map exactly as it was.
func _rivet_rejected(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: Variant, card_id: String, target_position: int, label: String,
		expected_reason: String = "", service: CombatWardenV3RivetCards = null) -> void:
	var resolver: CombatWardenV3RivetCards = service if service != null else _rivet_service()
	var before := _rivet_models(deck, party, enemies, pinned)
	var result: Dictionary = resolver.play_card(deck, party, enemies, pinned, card_id,
		target_position)
	_check(result.get("ok") == false, label + ": rejected")
	if not expected_reason.is_empty():
		_check(result.get("reason") == expected_reason,
			label + ": refused for " + expected_reason + " (got " + str(result.get("reason")) + ")")
	var hits: Variant = result.get("hits")
	_check(hits is Array and (hits as Array).is_empty() and result.get("hit_count") == 0
		and result.get("pinned") == false and result.get("energy_spent") == 0,
		label + ": refusal reports no hit, no spend and no pin")
	_check(_rivet_models(deck, party, enemies, pinned) == before,
		label + ": every model and the shared token map are unchanged")


## The whole model snapshot a refusal must preserve: both rosters, all four piles, energy, turn
## flags, the shared token map and the seeded RNG.
func _rivet_models(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: Variant) -> Dictionary:
	var result: Dictionary = {}
	if party != null:
		result["heroes"] = party.get_heroes()
	if enemies != null:
		result["enemies"] = enemies.get_enemies()
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["exhausted"] = deck.exhausted.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		if deck.combat_state != null:
			result["state_energy"] = deck.combat_state.energy
			result["state_turn"] = deck.combat_state.player_turn_active
		if deck._rng != null:
			result["rng_state"] = deck._rng.state
			result["rng_seed"] = deck._rng.seed
	if pinned is CombatPinned:
		var authority: CombatPinned = pinned
		result["pins"] = authority._pinner_by_position.duplicate(true)
	return result


## The single-transaction expected state: two energy, one discarded held copy, the summed
## Block/HP change on the original target and the token map after the cast.
func _rivet_expected_success(before: Dictionary, card_id: String, target_position: int,
		block_absorbed: int, hp_loss: int, pinner_after: String) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 2
	expected["state_energy"] -= 2
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var enemy: Dictionary = expected["enemies"][target_position - 1]
	enemy["block"] -= block_absorbed
	enemy["hp"] -= hp_loss
	var pins: Dictionary = expected["pins"]
	if pinner_after.is_empty():
		pins.erase(target_position)
	else:
		pins[target_position] = pinner_after
	return expected
