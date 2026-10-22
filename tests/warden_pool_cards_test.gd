extends SceneTree
## Deterministic headless test for WardenPoolCards catalog (D2-1).
## Validates the twelve base cards and twelve '+' upgrades, isolation, and StarterCards integrity.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_base_card_definitions()
	_test_upgraded_card_definitions()
	_test_mutation_isolation()
	_test_unknown_and_invalid_ids()
	_test_starter_cards_and_deck_unaffected()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("warden_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("warden_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _get_catalog() -> WardenPoolCards:
	return WardenPoolCards.new()


func _expected_base_records() -> Dictionary:
	return {
		"warden_hold_the_line": {
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
		"warden_pinning_jab": {
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
		"warden_heavy_thimble": {
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
		"warden_patch_guard": {
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
		"warden_quick_darn": {
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
		"warden_brass_buckle": {
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
		"warden_draw_fire": {
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
		"warden_seam_breaker": {
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
		"warden_iron_hem": {
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
		"warden_counter_stitch": {
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
		"warden_bastion_quilt": {
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
		"warden_pin_and_pound": {
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
	}


func _expected_plus_records() -> Dictionary:
	return {
		"warden_hold_the_line_plus": {
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
		"warden_pinning_jab_plus": {
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
		"warden_heavy_thimble_plus": {
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
		"warden_patch_guard_plus": {
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
		"warden_quick_darn_plus": {
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
		"warden_brass_buckle_plus": {
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
		"warden_draw_fire_plus": {
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
		"warden_seam_breaker_plus": {
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
		"warden_iron_hem_plus": {
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
		"warden_counter_stitch_plus": {
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
		"warden_bastion_quilt_plus": {
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
		"warden_pin_and_pound_plus": {
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


func _test_base_card_definitions() -> void:
	var catalog: WardenPoolCards = _get_catalog()
	var expected_table: Dictionary = _expected_base_records()
	var base_ids: Array[String] = catalog.get_base_ids()

	var common_count: int = 0
	var uncommon_count: int = 0
	var rare_count: int = 0

	for card_id: String in expected_table:
		var expected: Dictionary = expected_table[card_id]
		_check(catalog.has_card(card_id), "catalog has base card " + card_id)
		_check(base_ids.has(card_id), "get_base_ids includes " + card_id)

		var def: Dictionary = catalog.get_definition(card_id)
		_check(not def.is_empty(), "definition for " + card_id + " is not empty")
		_check(def.get("id") == card_id, card_id + " matching id")
		_check(def.get("display_name") == expected["display_name"], card_id + " display_name")
		_check(def.get("owner") == "warden", card_id + " owner is warden")
		_check(def.get("cost") == expected["cost"], card_id + " cost")
		_check(def.get("from_positions") == expected["from_positions"], card_id + " from_positions")
		_check(def.get("target_kind") == expected["target_kind"], card_id + " target_kind")
		_check(def.get("to_positions") == expected["to_positions"], card_id + " to_positions")
		_check(def.get("effects") == expected["effects"], card_id + " effects")
		_check(def.get("illustration_path") == expected["illustration_path"], card_id + " illustration_path")
		_check(def.get("starting_copies") == 0, card_id + " starting_copies is 0")
		_check(def.get("rarity") == expected["rarity"], card_id + " rarity")
		_check(def.get("reward_eligible") == true, card_id + " reward_eligible is true")
		_check(def.get("upgrade_id") == expected["upgrade_id"], card_id + " upgrade_id matches plus ID")
		_check(catalog.get_upgrade_id(card_id) == expected["upgrade_id"], card_id + " get_upgrade_id resolves plus ID")

		var rarity: String = def.get("rarity", "")
		if rarity == "common":
			common_count += 1
		elif rarity == "uncommon":
			uncommon_count += 1
		elif rarity == "rare":
			rare_count += 1

	_check(common_count == 6, "precisely 6 common base cards in expected table")
	_check(uncommon_count == 4, "precisely 4 uncommon base cards in expected table")
	_check(rare_count == 2, "precisely 2 rare base cards in expected table")


func _test_upgraded_card_definitions() -> void:
	var catalog: WardenPoolCards = _get_catalog()
	var expected_base: Dictionary = _expected_base_records()
	var expected_plus: Dictionary = _expected_plus_records()
	var base_ids: Array[String] = catalog.get_base_ids()

	for base_id: String in expected_base:
		var plus_id: String = catalog.get_upgrade_id(base_id)
		_check(not plus_id.is_empty(), base_id + " has valid upgrade_id")
		_check(expected_plus.has(plus_id), plus_id + " is in expected plus table")

		var expected: Dictionary = expected_plus[plus_id]
		var base_def: Dictionary = catalog.get_definition(base_id)
		var plus_def: Dictionary = catalog.get_definition(plus_id)

		_check(catalog.has_card(plus_id), "catalog has upgraded card " + plus_id)
		_check(not base_ids.has(plus_id), "plus ID " + plus_id + " is not in get_base_ids")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " has no further upgrade")

		_check(plus_def.get("id") == plus_id, plus_id + " id")
		_check(plus_def.get("display_name") == expected["display_name"], plus_id + " display_name")
		_check(plus_def.get("display_name") == base_def.get("display_name") + "+", plus_id + " display_name appends '+'")
		_check(plus_def.get("owner") == "warden", plus_id + " owner is warden")
		_check(plus_def.get("from_positions") == base_def.get("from_positions"), plus_id + " preserves from_positions")
		_check(plus_def.get("target_kind") == base_def.get("target_kind"), plus_id + " preserves target_kind")
		_check(plus_def.get("to_positions") == base_def.get("to_positions"), plus_id + " preserves to_positions")
		_check(plus_def.get("rarity") == base_def.get("rarity"), plus_id + " preserves rarity")
		_check(plus_def.get("starting_copies") == 0, plus_id + " starting_copies is 0")
		_check(plus_def.get("reward_eligible") == false, plus_id + " reward_eligible is false")
		_check(plus_def.get("upgrade_of") == base_id, plus_id + " upgrade_of points to base ID")
		_check(plus_def.get("illustration_path") == base_def.get("illustration_path"), plus_id + " illustration_path points to base card image")
		_check(plus_def.get("effects") == expected["effects"], plus_id + " exact effects match")

		# Check cost: Iron Hem+ is 1 instead of 2 (explicit exception); all other cards preserve cost.
		if base_id == "warden_iron_hem":
			_check(base_def.get("cost") == 2, "warden_iron_hem base cost is 2")
			_check(plus_def.get("cost") == 1, "warden_iron_hem_plus cost is 1 (explicit exception)")
			_check(plus_def.get("effects").get("block") == 14, "warden_iron_hem_plus retains 14 Block")
		else:
			_check(plus_def.get("cost") == base_def.get("cost"), plus_id + " preserves cost")

	# Specific checks for key effect mechanics
	var pin_pound_plus: Dictionary = catalog.get_definition("warden_pin_and_pound_plus")
	_check(pin_pound_plus.get("effects").get("damage") == 12, "Pin and Pound+ damage 12")
	_check(pin_pound_plus.get("effects").get("hits") == 2, "Pin and Pound+ two hits preserved")

	var draw_fire_plus: Dictionary = catalog.get_definition("warden_draw_fire_plus")
	_check(draw_fire_plus.get("effects").get("block") == 8, "Draw Fire+ block 8")
	_check(draw_fire_plus.get("effects").get("guarding") == true, "Draw Fire+ guarding flag preserved")
	_check(draw_fire_plus.get("effects").get("duration") == "until_next_turn", "Draw Fire+ until_next_turn duration preserved")

	var counter_stitch_plus: Dictionary = catalog.get_definition("warden_counter_stitch_plus")
	_check(counter_stitch_plus.get("effects").get("block") == 7, "Counter-stitch+ block 7")
	_check(counter_stitch_plus.get("effects").get("thorns") == 4, "Counter-stitch+ thorns 4")
	_check(counter_stitch_plus.get("effects").get("duration") == "until_next_turn", "Counter-stitch+ until_next_turn duration preserved")

	var pinning_jab_plus: Dictionary = catalog.get_definition("warden_pinning_jab_plus")
	_check(pinning_jab_plus.get("effects").get("damage") == 6, "Pinning Jab+ damage 6")
	_check(pinning_jab_plus.get("effects").get("pinned") == true, "Pinning Jab+ pinned flag preserved")

	var bastion_quilt_plus: Dictionary = catalog.get_definition("warden_bastion_quilt_plus")
	_check(bastion_quilt_plus.get("effects").get("block_all") == 13, "Bastion Quilt+ block_all 13")

	var seam_breaker_plus: Dictionary = catalog.get_definition("warden_seam_breaker_plus")
	_check(seam_breaker_plus.get("effects").get("damage") == 10, "Seam Breaker+ damage 10")
	_check(seam_breaker_plus.get("effects").get("unravel") == 6, "Seam Breaker+ unravel 6")


func _test_mutation_isolation() -> void:
	var catalog: WardenPoolCards = _get_catalog()

	# Mutating top-level properties in returned dictionary
	var def1: Dictionary = catalog.get_definition("warden_hold_the_line")
	def1["display_name"] = "Corrupted Name"
	def1["cost"] = 99
	var def2: Dictionary = catalog.get_definition("warden_hold_the_line")
	_check(def2.get("display_name") == "Hold the Line", "catalog definition protected from display_name mutation")
	_check(def2.get("cost") == 1, "catalog definition protected from cost mutation")

	# Mutating nested effects dictionary
	var def3: Dictionary = catalog.get_definition("warden_hold_the_line")
	var effects3: Dictionary = def3.get("effects", {})
	effects3["block"] = 9999
	effects3["other_ally_block"] = 9999
	effects3["injected_key"] = true
	var def4: Dictionary = catalog.get_definition("warden_hold_the_line")
	var effects4: Dictionary = def4.get("effects", {})
	_check(effects4.get("block") == 5, "nested effects block protected from mutation")
	_check(effects4.get("other_ally_block") == 2, "nested effects other_ally_block protected from mutation")
	_check(not effects4.has("injected_key"), "nested effects protected from key injection")

	# Mutating nested positions arrays
	var def5: Dictionary = catalog.get_definition("warden_pin_and_pound")
	var from_pos: Array = def5.get("from_positions", [])
	from_pos.clear()
	var to_pos: Array = def5.get("to_positions", [])
	to_pos.append(999)
	var def6: Dictionary = catalog.get_definition("warden_pin_and_pound")
	_check(def6.get("from_positions") == [1], "nested from_positions protected from mutation")
	_check(def6.get("to_positions") == [1, 2, 3], "nested to_positions protected from mutation")

	# Mutating get_base_ids array
	var base_ids1: Array[String] = catalog.get_base_ids()
	base_ids1.clear()
	base_ids1.append("fake_card")
	var base_ids2: Array[String] = catalog.get_base_ids()
	_check(not base_ids2.is_empty(), "get_base_ids protected from clear")
	_check(not base_ids2.has("fake_card"), "get_base_ids protected from injection")
	_check(base_ids2.has("warden_hold_the_line"), "get_base_ids retains original base cards after caller mutation")


func _test_unknown_and_invalid_ids() -> void:
	var catalog: WardenPoolCards = _get_catalog()

	_check(catalog.get_definition("nonexistent_id").is_empty(), "get_definition on nonexistent ID returns empty dictionary")
	_check(catalog.get_definition("").is_empty(), "get_definition on empty ID returns empty dictionary")
	_check(catalog.get_definition(null).is_empty(), "get_definition on null returns empty dictionary")
	_check(catalog.get_definition(123).is_empty(), "get_definition on int returns empty dictionary")

	_check(not catalog.has_card("nonexistent_id"), "has_card on nonexistent ID returns false")
	_check(not catalog.has_card(""), "has_card on empty string returns false")
	_check(not catalog.has_card(null), "has_card on null returns false")
	_check(not catalog.has_card(123), "has_card on int returns false")

	_check(catalog.get_upgrade_id("nonexistent_id") == "", "get_upgrade_id on nonexistent ID returns empty string")
	_check(catalog.get_upgrade_id("") == "", "get_upgrade_id on empty string returns empty string")
	_check(catalog.get_upgrade_id(null) == "", "get_upgrade_id on null returns empty string")
	_check(catalog.get_upgrade_id(123) == "", "get_upgrade_id on int returns empty string")


func _test_starter_cards_and_deck_unaffected() -> void:
	var starter_catalog: StarterCards = StarterCards.new()
	var warden_pool: WardenPoolCards = _get_catalog()

	# Verify Warden starters in StarterCards are untouched
	var strike: Dictionary = starter_catalog.get_definition("warden_strike")
	_check(strike.get("display_name") == "Strike", "warden_strike display_name intact")
	_check(strike.get("owner") == "warden", "warden_strike owner intact")
	_check(strike.get("starting_copies") == 2, "warden_strike starting_copies is 2")

	var brace: Dictionary = starter_catalog.get_definition("warden_brace")
	_check(brace.get("display_name") == "Brace", "warden_brace display_name intact")
	_check(brace.get("owner") == "warden", "warden_brace owner intact")
	_check(brace.get("starting_copies") == 1, "warden_brace starting_copies is 1")

	var shield_bash: Dictionary = starter_catalog.get_definition("warden_shield_bash")
	_check(shield_bash.get("display_name") == "Shield Bash", "warden_shield_bash display_name intact")
	_check(shield_bash.get("owner") == "warden", "warden_shield_bash owner intact")
	_check(shield_bash.get("starting_copies") == 1, "warden_shield_bash starting_copies is 1")

	# Total starting deck is twelve across all heroes
	var starter_deck: Array[String] = starter_catalog.get_starting_deck()
	_check(starter_deck.size() == 12, "starting deck total remains 12")

	# Verify starter_deck.json
	var file: FileAccess = FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "starter_deck.json readable")
	if file != null:
		var raw: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		_check(raw is Array, "starter_deck.json is Array")
		if raw is Array:
			_check(raw.size() == 12, "starter_deck.json has 12 entries")
			for pool_base_id: String in warden_pool.get_base_ids():
				_check(not raw.has(pool_base_id), "starter_deck.json does not contain pool card " + pool_base_id)
				var plus_id: String = warden_pool.get_upgrade_id(pool_base_id)
				_check(not raw.has(plus_id), "starter_deck.json does not contain upgraded pool card " + plus_id)

	# StarterCards must NOT contain any of the pool cards
	for pool_base_id: String in warden_pool.get_base_ids():
		_check(not starter_catalog.has_card(pool_base_id), "StarterCards has no pool card " + pool_base_id)
		var plus_id: String = warden_pool.get_upgrade_id(pool_base_id)
		_check(not starter_catalog.has_card(plus_id), "StarterCards has no pool plus card " + plus_id)
