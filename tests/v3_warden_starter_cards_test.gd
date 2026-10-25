extends SceneTree
## V3-1 Warden starter-card catalog contract.
## Catalog data only: no live party, reward, hand, deck or combat behavior is assumed or claimed
## here. Guard / Block-based damage / Taunt are printed descriptors until a later wiring task.

const V3WardenStarterCards = preload("res://data/cards/v3_warden_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const V3WardenPoolCards = preload("res://data/cards/v3_warden_pool_cards.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_each_base_and_upgrade()
	_test_look_descriptors()
	_test_starter_projection()
	_test_detached_records()
	_test_invalid_and_upgraded_ids()
	_test_deterministic_and_rng_free()
	_test_existing_catalogs_unchanged()
	_test_not_reward_offered()
	if failures.is_empty():
		print("v3_warden_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_warden_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Literal, independent expectations for each of the four authored base/"+" pairs.
func _cases() -> Dictionary:
	return {
		"warden_v3_pot_helm_bonk": {
			"name": "Pot Helm Bonk", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 4, "weak": 1},
			"plus_cost": 1, "plus_effects": {"damage": 6, "weak": 1}},
		"warden_v3_shield_catch": {
			"name": "Shield Catch", "cost": 1,
			"from": [1, 2], "target": "ally_single", "to": [],
			"effects": {"block": 4, "guard_next_hit": true},
			"plus_cost": 1, "plus_effects": {"block": 6, "guard_next_hit": true}},
		"warden_v3_rim_toss": {
			"name": "Rim Toss", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage_equal_to_owner_block": true},
			"plus_cost": 1,
			"plus_effects": {"damage_equal_to_owner_block": true, "bonus_damage": 2}},
		"warden_v3_iron_challenge": {
			"name": "Iron Challenge", "cost": 1,
			"from": [1], "target": "self", "to": [],
			"effects": {"block": 3, "taunt_next_enemy_turn": true},
			"plus_cost": 1, "plus_effects": {"block": 5, "taunt_next_enemy_turn": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "warden",
		"cost": spec["plus_cost"] if upgraded else spec["cost"],
		"from_positions": spec["from"],
		"target_kind": spec["target"],
		"to_positions": spec["to"],
		"effects": spec["plus_effects"] if upgraded else spec["effects"],
		"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
		"starting_copies": 0 if upgraded else 1,
		"reward_eligible": false,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


func _test_each_base_and_upgrade() -> void:
	var catalog := V3WardenStarterCards.new()
	var cases: Dictionary = _cases()
	_check(cases.size() == 4, "exactly four authored base cases are enumerated")
	var art_paths: Array[String] = []
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(catalog.has_card(base_id), base_id + " is authored")
		_check(catalog.has_card(plus_id), plus_id + " is authored")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + "_plus is not authored")
		_check(base_id.begins_with("warden_v3_"), base_id + " carries the v3 Warden prefix")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("owner") == "warden", card_id + " is owned by the Warden")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has an effect dictionary")
			_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
				and record.get("reward_eligible") == false, card_id + " is never reward eligible")
			_check(not record.has("rarity"), card_id + " carries no reward rarity")
			_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
				card_id + " shares its base illustration path")
			_check(record.get("cost") == 1, card_id + " costs one energy")
			var effects: Dictionary = record.get("effects")
			_check(effects.size() == expected["effects"].size(),
				card_id + " prints exactly the documented effects")
			# Authored legality: every named slot is one of the three party positions.
			for position: Variant in record.get("from_positions"):
				_check(position is int and int(position) >= 1 and int(position) <= 3,
					card_id + " FROM position is one of 1..3: " + str(position))
			for position: Variant in record.get("to_positions"):
				_check(position is int and int(position) >= 1 and int(position) <= 3,
					card_id + " TO position is one of 1..3: " + str(position))
			_check(not record.get("from_positions").is_empty(),
				card_id + " declares at least one legal FROM slot")
			if record.get("target_kind") == "enemy_single":
				_check(not record.get("to_positions").is_empty(),
					card_id + " names at least one enemy slot")
			else:
				_check(record.get("to_positions").is_empty(),
					card_id + " names no enemy slot for a non-enemy target")
		_check(catalog.get_definition(base_id).get("starting_copies") == 1,
			base_id + " starts with one copy")
		_check(catalog.get_definition(plus_id).get("starting_copies") == 0,
			plus_id + " adds no starting copy")
		_check(not catalog.get_definition(base_id).has("upgrade_of"),
			base_id + " is not itself an upgrade")
		_check(catalog.get_definition(base_id).get("upgrade_id") == plus_id,
			base_id + " carries its own upgrade link")
		_check(not catalog.get_definition(plus_id).has("upgrade_id"),
			plus_id + " has no onward upgrade link")
		_check(catalog.get_definition(plus_id).get("upgrade_of") == base_id,
			plus_id + " names its base")
		_check(catalog.get_definition(base_id).get("illustration_path")
			== catalog.get_definition(plus_id).get("illustration_path"),
			base_id + " base and upgrade share one illustration path")
		art_paths.append(str(catalog.get_definition(base_id).get("illustration_path")))
	for path: String in art_paths:
		_check(art_paths.count(path) == 1, path + " is unique to its own starter")


## The printed look descriptors: a pot-helmet Weak bonk, a huge shield raised over one ally
## (Guard), a shield-rim toss reading the Warden's own Block, and an iron challenge (Taunt).
## Presence, exact magnitudes and value types only; nothing here claims live resolution.
func _test_look_descriptors() -> void:
	var catalog := V3WardenStarterCards.new()
	var pool := V3WardenPoolCards.new()
	for suffix: String in ["", "_plus"]:
		var bonk: Dictionary = catalog.get_definition("warden_v3_pot_helm_bonk" + suffix)
		var bonk_effects: Dictionary = bonk.get("effects")
		_check(bonk.get("target_kind") == "enemy_single" and bonk.get("to_positions") == [1, 2],
			"Pot Helm Bonk rattles one front enemy" + suffix)
		_check(bonk.get("from_positions") == [1, 2],
			"Pot Helm Bonk swings from the front or middle slot" + suffix)
		_check(bonk_effects.get("damage") is int and bonk_effects.get("weak") is int,
			"Pot Helm Bonk prints integer damage and Weak" + suffix)
		_check(bonk_effects.get("weak") == 1,
			"Pot Helm Bonk Weakens by exactly one" + suffix)
		_check(bonk_effects.size() == 2 and not bonk_effects.has("block"),
			"Pot Helm Bonk only rattles the foe; it does not Block" + suffix)

		var catch: Dictionary = catalog.get_definition("warden_v3_shield_catch" + suffix)
		var catch_effects: Dictionary = catch.get("effects")
		_check(catch.get("target_kind") == "ally_single" and catch.get("to_positions") == [],
			"Shield Catch covers one living ally without naming an enemy slot" + suffix)
		_check(catch.get("from_positions") == [1, 2],
			"Shield Catch is raised from the front or middle slot" + suffix)
		_check(catch_effects.get("block") is int,
			"Shield Catch prints integer Block for the chosen ally" + suffix)
		_check(catch_effects.get("guard_next_hit") is bool
			and catch_effects.get("guard_next_hit") == true,
			"Shield Catch carries the one-use Guard descriptor" + suffix)
		_check(not catch_effects.has("damage") and not catch_effects.has("taunt_next_enemy_turn"),
			"Shield Catch neither strikes nor taunts" + suffix)
		_check(not catch_effects.has("block_self"),
			"Shield Catch shields the ally, not only the Warden" + suffix)

		var rim: Dictionary = catalog.get_definition("warden_v3_rim_toss" + suffix)
		var rim_effects: Dictionary = rim.get("effects")
		_check(rim.get("target_kind") == "enemy_single" and rim.get("to_positions") == [1, 2, 3],
			"Rim Toss can be hurled at any enemy slot" + suffix)
		_check(rim.get("from_positions") == [1, 2],
			"Rim Toss is thrown from the front or middle slot" + suffix)
		_check(rim_effects.get("damage_equal_to_owner_block") is bool
			and rim_effects.get("damage_equal_to_owner_block") == true,
			"Rim Toss reads the Warden's current Block at resolution" + suffix)
		_check(not rim_effects.has("damage"),
			"Rim Toss has no flat damage key" + suffix)
		_check(not rim_effects.has("block") and not rim_effects.has("block_spend"),
			"Rim Toss neither gains nor spends Block" + suffix)

		var challenge: Dictionary = catalog.get_definition("warden_v3_iron_challenge" + suffix)
		var challenge_effects: Dictionary = challenge.get("effects")
		_check(challenge.get("target_kind") == "self" and challenge.get("to_positions") == [],
			"Iron Challenge targets the Warden itself" + suffix)
		_check(challenge.get("from_positions") == [1],
			"Iron Challenge is banged from the front slot only" + suffix)
		_check(challenge_effects.get("block") is int,
			"Iron Challenge prints integer Block for the Warden" + suffix)
		_check(challenge_effects.get("taunt_next_enemy_turn") is bool
			and challenge_effects.get("taunt_next_enemy_turn") == true,
			"Iron Challenge carries the Taunt descriptor" + suffix)
		_check(not challenge_effects.has("guard_next_hit") and not challenge_effects.has("damage"),
			"Iron Challenge neither guards an ally nor strikes" + suffix)

	_check(catalog.get_definition("warden_v3_pot_helm_bonk").get("effects").get("damage") == 4
		and catalog.get_definition("warden_v3_pot_helm_bonk_plus").get("effects").get("damage") == 6,
		"Pot Helm Bonk damage is four then six")
	_check(catalog.get_definition("warden_v3_pot_helm_bonk_plus").get("effects").get("weak") == 1,
		"Pot Helm Bonk+ keeps Weak one")
	_check(catalog.get_definition("warden_v3_shield_catch").get("effects").get("block") == 4
		and catalog.get_definition("warden_v3_shield_catch_plus").get("effects").get("block") == 6,
		"Shield Catch Block is four then six")
	_check(catalog.get_definition("warden_v3_rim_toss").get("effects")
		== {"damage_equal_to_owner_block": true},
		"base Rim Toss is only a Block-based hit")
	_check(catalog.get_definition("warden_v3_rim_toss_plus").get("effects").get("bonus_damage") == 2,
		"Rim Toss+ adds exactly two bonus damage")
	_check(catalog.get_definition("warden_v3_iron_challenge").get("effects").get("block") == 3
		and catalog.get_definition("warden_v3_iron_challenge_plus").get("effects").get("block") == 5,
		"Iron Challenge Block is three then five")
	for suffix: String in ["", "_plus"]:
		_check(catalog.get_definition("warden_v3_iron_challenge" + suffix)
			.get("effects").get("block") > 0,
			"Iron Challenge grants real Block" + suffix)

	# Rim Toss reuses the descriptor language of the already-authored v3 Warden reward Shield Toss.
	var reward_toss: Dictionary = pool.get_definition("warden_v3_shield_toss")
	var reward_toss_plus: Dictionary = pool.get_definition("warden_v3_shield_toss_plus")
	_check(not reward_toss.is_empty() and not reward_toss_plus.is_empty(),
		"existing v3 Warden Shield Toss reward pair is authored (precondition)")
	_check(reward_toss.get("effects").has("damage_equal_to_owner_block")
		and catalog.get_definition("warden_v3_rim_toss").get("effects")
			.has("damage_equal_to_owner_block"),
		"Rim Toss shares Shield Toss's Block-based damage descriptor")
	_check(reward_toss_plus.get("effects").has("bonus_damage")
		and catalog.get_definition("warden_v3_rim_toss_plus").get("effects")
			.has("bonus_damage"),
		"Rim Toss+ shares Shield Toss+'s bonus-damage descriptor")


## The dedicated hero projection: each named base exactly once, never an upgrade and never a
## reward card. No shared catalog total or ordering premise is imposed on other catalogs; the
## active three-hero deck is checked separately against its authored membership.
func _test_starter_projection() -> void:
	var catalog := V3WardenStarterCards.new()
	var starter_cards := StarterCards.new()
	var pool := V3WardenPoolCards.new()
	var cases: Dictionary = _cases()
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	_check(not starter_ids.is_empty() and not deck.is_empty(),
		"starter projection is populated before counting")
	_check(starter_ids.size() == 4,
		"this hero's own starter projection names its four authored bases")
	_check(deck.size() == 4,
		"this hero's own starting deck holds one copy of each authored base")
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		_check(starter_ids.count(base_id) == 1, base_id + " appears once in get_starter_ids")
		_check(deck.count(base_id) == 1, base_id + " appears once in the dedicated starting deck")
		_check(not starter_ids.has(plus_id), plus_id + " is not a starter id")
		_check(not deck.has(plus_id), plus_id + " is not in the dedicated starting deck")
		_check(not starter_ids.has(base_id + "_plus_plus"),
			base_id + " proposes no forged plus-of-plus starter")
	for id: String in starter_ids:
		_check(cases.has(id), id + " in get_starter_ids is one of the four authored bases")
	for id: String in deck:
		_check(cases.has(id), id + " in the dedicated deck is one of the four authored bases")
	_check(starter_ids == deck, "starter ids and dedicated starting deck agree")
	var all_ids: Array[String] = catalog.get_all_card_ids()
	for id: String in all_ids:
		_check(cases.has(id) or cases.has(id.trim_suffix("_plus")),
			id + " belongs to one of the four authored pairs")
		_check(catalog.has_card(id), id + " is discoverable through has_card")
	for base_id: String in cases:
		_check(all_ids.has(base_id) and all_ids.has(base_id + "_plus"),
			base_id + " base and upgrade are both discoverable")
	# No ID may collide with the separate v3 Warden reward pool or the active starter catalog.
	for pool_id: String in pool.get_all_card_ids():
		_check(not catalog.has_card(pool_id), pool_id + " is a reward card, not a starter")
		_check(not starter_ids.has(pool_id), pool_id + " is not in the starter projection")
		_check(not deck.has(pool_id), pool_id + " is not in the dedicated starting deck")
	for active_id: String in starter_cards.get_all_card_ids():
		_check(not catalog.has_card(active_id),
			active_id + " belongs to the active starter catalog, not this one")
		_check(not starter_ids.has(active_id),
			active_id + " is not proposed as a v3 Warden starter")


func _test_detached_records() -> void:
	var catalog := V3WardenStarterCards.new()
	var sample: Dictionary = catalog.get_definition("warden_v3_pot_helm_bonk")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["weak"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["display_name"] = "Mutated"
	sample["cost"] = 99
	sample["starting_copies"] = 99
	var pristine: Dictionary = catalog.get_definition("warden_v3_pot_helm_bonk")
	_check(pristine.get("effects") == {"damage": 4, "weak": 1},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [1, 2], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2], "TO arrays are deeply detached")
	_check(pristine.get("id") == "warden_v3_pot_helm_bonk", "metadata is detached")
	_check(pristine.get("display_name") == "Pot Helm Bonk", "display name is detached")
	_check(pristine.get("cost") == 1, "cost is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")
	var upgraded: Dictionary = catalog.get_definition("warden_v3_shield_catch_plus")
	_check(not upgraded.is_empty(), "upgrade mutation fixture loaded")
	if upgraded.is_empty():
		return
	upgraded["effects"]["block"] = 900
	upgraded["effects"]["guard_next_hit"] = false
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	var upgraded_pristine: Dictionary = catalog.get_definition("warden_v3_shield_catch_plus")
	_check(upgraded_pristine.get("effects") == {"block": 6, "guard_next_hit": true},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [1, 2], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [], "empty upgrade TO array is detached")
	_check(not upgraded_pristine.get("to_positions").has(900), "empty upgrade TO repopulates empty")
	var rim_plus: Dictionary = catalog.get_definition("warden_v3_rim_toss_plus")
	_check(not rim_plus.is_empty(), "Block-based upgrade fixture loaded")
	if not rim_plus.is_empty():
		_check(rim_plus.get("effects")
			== {"damage_equal_to_owner_block": true, "bonus_damage": 2},
			"Block-based upgrade fixture is intact before mutation")
		rim_plus["effects"].erase("damage_equal_to_owner_block")
		rim_plus["effects"]["damage"] = 900
		var rim_pristine: Dictionary = catalog.get_definition("warden_v3_rim_toss_plus")
		_check(rim_pristine.get("effects")
			== {"damage_equal_to_owner_block": true, "bonus_damage": 2},
			"Block-based upgrade effects resist caller erase and injection")
		_check(catalog.get_definition("warden_v3_rim_toss").get("effects")
			== {"damage_equal_to_owner_block": true},
			"mutating one record leaves its base untouched")
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(starter_ids.has("warden_v3_iron_challenge") and deck.has("warden_v3_shield_catch"),
		"projections are populated before mutation")
	starter_ids.clear()
	starter_ids.append("forged_starter")
	deck.clear()
	all_ids.clear()
	_check(catalog.get_starter_ids().has("warden_v3_iron_challenge"),
		"get_starter_ids returns a fresh array")
	_check(catalog.get_starting_deck().has("warden_v3_shield_catch"),
		"get_starting_deck returns a fresh array")
	_check(catalog.get_all_card_ids().has("warden_v3_rim_toss_plus"),
		"get_all_card_ids returns a fresh array")
	_check(not catalog.get_starter_ids().has("forged_starter"),
		"mutated starter id array leaks nothing")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(first_deck == second_deck and first_deck.size() == second_deck.size(),
		"two starting-deck calls agree")
	if not first_deck.is_empty():
		first_deck[0] = "mutated_first"
	_check(second_deck.count("warden_v3_pot_helm_bonk") == 1
		and catalog.get_starting_deck().count("warden_v3_pot_helm_bonk") == 1,
		"each base starter contributes exactly one copy")
	_check(V3WardenStarterCards.new().get_definition("warden_v3_pot_helm_bonk") == pristine,
		"a fresh instance retains the canonical definition")


func _test_invalid_and_upgraded_ids() -> void:
	var catalog := V3WardenStarterCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {},
		StringName("warden_v3_pot_helm_bonk"), "", "warden_v3_not_a_card",
		"warden_v3_pot_helm_bonk+", "forged_starter",
		"warden_v3_pot_helm_bonk_plus_plus", "warden_v3_shield_catch_plus_plus",
		"warden_v3_rim_toss_plus_plus", "warden_v3_iron_challenge_plus_plus",
		"pot_helm_bonk", "v3_warden_pot_helm_bonk", "warden_strike",
		"warden_v3_shield_toss", "warden_v3_shield_toss_plus",
		"warden_v3_guard_stitch", "warden_v3_iron_taunt",
		"yarn_ranger_needle_nock", "button_golem_starter_button_fist"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(),
			"invalid id returns no definition: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))
	# Upgraded records exist but are terminal: no second upgrade, no starter membership.
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		var plus_record: Dictionary = catalog.get_definition(plus_id)
		_check(not plus_record.is_empty(), plus_id + " is a real record")
		_check(plus_record.get("upgrade_of") == base_id, plus_id + " points back to its base")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(catalog.get_upgrade_id(plus_id + "_plus") == "",
			plus_id + " has no forged plus-of-plus upgrade")
		_check(catalog.get_definition(catalog.get_upgrade_id(plus_id)).is_empty(),
			plus_id + " resolves no second definition")
		_check(not catalog.get_starter_ids().has(plus_id),
			plus_id + " is not proposed as a starter")
		_check(not catalog.get_starting_deck().has(plus_id),
			plus_id + " is not proposed in the dedicated deck")
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(12) == ""
		and catalog.get_upgrade_id("") == "" and catalog.get_upgrade_id([]) == "",
		"get_upgrade_id fails closed on non-string and empty IDs")
	_check(catalog.get_definition(12).is_empty() and catalog.has_card(12) == false,
		"numeric IDs fail closed on definition and membership")
	_check(not catalog.has_card(StringName("warden_v3_rim_toss")) and
		catalog.get_definition(StringName("warden_v3_rim_toss")).is_empty(),
		"StringName IDs are rejected rather than coerced")


func _test_deterministic_and_rng_free() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var before: int = rng.state
	var catalog := V3WardenStarterCards.new()
	var first_ids: Array[String] = catalog.get_all_card_ids()
	var first_starters: Array[String] = catalog.get_starter_ids()
	var first_deck: Array[String] = catalog.get_starting_deck()
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		catalog.get_definition(base_id)
		catalog.get_definition(base_id + "_plus")
		catalog.has_card(base_id)
		catalog.has_card(base_id + "_plus")
		catalog.get_upgrade_id(base_id)
		catalog.get_upgrade_id(base_id + "_plus")
		catalog.get_definition(base_id + "_plus_plus")
	var second := V3WardenStarterCards.new()
	_check(first_ids == second.get_all_card_ids(), "catalog enumeration is deterministic")
	_check(first_starters == second.get_starter_ids(), "starter enumeration is deterministic")
	_check(first_deck == second.get_starting_deck(), "starting-deck projection is deterministic")
	_check(first_ids == catalog.get_all_card_ids(), "repeated enumeration is stable")
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(catalog.get_definition("warden_v3_pot_helm_bonk").get("effects")
		== {"damage": 4, "weak": 1}, "lookups leave the catalog pristine")
	_check(rng.state == before, "a second lookup window also consumes no seeded RNG draws")


## Existing shared catalogs stay exactly as authored; the new starters stay out of the live deck,
## out of the Warden hero definition and out of the separate v3 Warden reward pool.
func _test_existing_catalogs_unchanged() -> void:
	var catalog := V3WardenStarterCards.new()
	var starter := StarterCards.new()
	var pool := V3WardenPoolCards.new()
	var cases: Dictionary = _cases()

	# The unchanged original Warden starter numbers (Strike x2, Brace x1, Shield Bash x1).
	var strike: Dictionary = starter.get_definition("warden_strike")
	_check(not strike.is_empty(), "warden_strike remains authored (precondition)")
	_check(strike.get("display_name") == "Strike", "warden_strike keeps its name")
	_check(strike.get("effects") == {"damage": 6}, "warden_strike stays six damage")
	_check(strike.get("cost") == 1 and strike.get("from_positions") == [1, 2]
		and strike.get("target_kind") == "enemy_single" and strike.get("to_positions") == [1, 2],
		"warden_strike keeps its authored cost and slots")
	_check(strike.get("starting_copies") == 2, "warden_strike keeps two copies")
	var brace: Dictionary = starter.get_definition("warden_brace")
	_check(not brace.is_empty(), "warden_brace remains authored (precondition)")
	_check(brace.get("effects") == {"block": 7}, "warden_brace stays seven Block")
	_check(brace.get("starting_copies") == 1, "warden_brace keeps one copy")
	var bash: Dictionary = starter.get_definition("warden_shield_bash")
	_check(not bash.is_empty(), "warden_shield_bash remains authored (precondition)")
	_check(bash.get("effects") == {"damage": 8, "weak": 1},
		"warden_shield_bash stays eight damage with Weak one")
	_check(bash.get("cost") == 2 and bash.get("from_positions") == [1]
		and bash.get("to_positions") == [1], "warden_shield_bash keeps its authored cost and slot")
	_check(bash.get("starting_copies") == 1, "warden_shield_bash keeps one copy")

	var active_deck: Array[String] = starter.get_starting_deck()
	_check(not active_deck.is_empty(), "active starting deck is populated (precondition)")
	_check(active_deck.count("warden_strike") == 2, "active deck holds Warden Strike twice")
	_check(active_deck.count("warden_brace") == 1, "active deck holds Brace once")
	_check(active_deck.count("warden_shield_bash") == 1, "active deck holds Shield Bash once")
	var raw_json: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored_deck: Variant = JSON.parse_string(raw_json)
	_check(authored_deck is Array, "authored starter deck parses (precondition)")
	if authored_deck is Array:
		_check(active_deck == authored_deck,
			"active three-hero starting deck still matches its authored membership and order")
		_check((authored_deck as Array).count("warden_strike") == 2,
			"authored starter deck still names Warden Strike twice")
		_check((authored_deck as Array).count("warden_brace") == 1,
			"authored starter deck still names Brace once")
		_check((authored_deck as Array).count("warden_shield_bash") == 1,
			"authored starter deck still names Shield Bash once")

	# The separate v3 Warden reward catalog keeps its authored records exactly.
	var reward_ids: Array[String] = pool.get_all_card_ids()
	_check(not reward_ids.is_empty(), "v3 Warden reward pool is populated (precondition)")
	var snapshot: Dictionary = {}
	for reward_id: String in reward_ids:
		snapshot[reward_id] = pool.get_definition(reward_id)
	_check(pool.has_card("warden_v3_shield_toss"), "Shield Toss stays a v3 Warden reward")
	_check(pool.has_card("warden_v3_guard_stitch"), "Guard Stitch stays a v3 Warden reward")
	_check(pool.has_card("warden_v3_iron_taunt"), "Iron Taunt stays a v3 Warden reward")
	# Exercise the new catalog, then prove the reward pool is byte-for-byte unchanged.
	for base_id: String in cases:
		catalog.get_definition(base_id)
		catalog.get_definition(base_id + "_plus")
		catalog.get_upgrade_id(base_id)
	_check(catalog.get_definition("warden_v3_shield_toss").is_empty(),
		"the starter catalog does not serve a reward card")
	for reward_id: String in snapshot:
		_check(pool.get_definition(reward_id) == snapshot[reward_id],
			"v3 Warden reward record unchanged: " + reward_id)
	for reward_id: String in reward_ids:
		_check(not catalog.has_card(reward_id),
			"starter catalog never overlaps reward id " + reward_id)
	# New authoring is unique: no starter ID exists in either older catalog or the authored deck.
	for base_id: String in cases:
		for card_id: String in [base_id, base_id + "_plus"]:
			_check(not starter.has_card(card_id), card_id + " has not entered StarterCards")
			_check(not active_deck.has(card_id), card_id + " is absent from the active deck")
			if authored_deck is Array:
				_check(not (authored_deck as Array).has(card_id),
					card_id + " is absent from the authored starter deck")
			_check(not pool.has_card(card_id), card_id + " is absent from the reward pool")
			_check(catalog.get_definition(card_id).get("reward_eligible") == false,
				card_id + " is never reward eligible")
			_check(not catalog.get_definition(card_id).has("rarity"),
				card_id + " carries no pool rarity")

	# The Warden hero definition itself is untouched.
	var party_raw: String = FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var party: Variant = JSON.parse_string(party_raw)
	_check(party is Array, "starter party parses (precondition)")
	var warden_found: bool = false
	if party is Array:
		for hero: Variant in party:
			if hero is Dictionary and hero.get("id") == "warden":
				warden_found = true
				_check(hero.get("name") == "Warden", "Warden hero keeps its name")
				_check(hero.get("max_hp") == 40, "Warden hero keeps 40 max HP")
	_check(warden_found, "Warden is authored in the starter party")


## Until the later wiring task, the live reward routing cannot offer or resolve these starters.
func _test_not_reward_offered() -> void:
	var catalog := V3WardenStarterCards.new()
	var cases: Dictionary = _cases()
	var candidates: Array = RunPoolCardRewardOffers.get_authored_base_candidates()
	_check(not candidates.is_empty(), "authored reward candidates are non-empty (precondition)")
	var candidate_ids: Dictionary = {}
	for record: Variant in candidates:
		if record is Dictionary:
			candidate_ids[String(record.get("id", ""))] = true
	_check(candidate_ids.has("warden_hold_the_line"),
		"reward candidates still include an existing Warden card (precondition)")
	for base_id: String in cases:
		for card_id: String in [base_id, base_id + "_plus"]:
			_check(not candidate_ids.has(card_id), "reward candidates exclude " + card_id)
			_check(RunPoolCardRewardOffers.resolve_reward_definition(card_id).is_empty(),
				"starter is not reward-resolvable yet: " + card_id)
	_check(not RunPoolCardRewardOffers.resolve_reward_definition("warden_hold_the_line").is_empty(),
		"an existing Warden reward card is still reward-resolvable (precondition)")
