extends SceneTree
## V3-1 Warden starter-card catalog contract plus the callable Iron Challenge / Iron Taunt slice.
## The catalog assertions below stay data-only. The paid self-play and one-enemy-turn Taunt
## projection are exercised scene-free against real seeded CombatDeck/CombatParty fixtures;
## Guard and Block-based damage remain printed descriptors until their own wiring tasks. No live
## hand, reward, map or app flow is claimed here.

const V3WardenStarterCards = preload("res://data/cards/v3_warden_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const V3WardenPoolCards = preload("res://data/cards/v3_warden_pool_cards.gd")

const HEROES_PATH := "res://data/heroes/starter_party.json"
const TAUNT_FILLERS := ["filler_stitch", "filler_thread", "filler_needle", "filler_ribbon"]
const TAUNT_CARDS := [
	"warden_v3_iron_challenge",
	"warden_v3_iron_challenge_plus",
	"warden_v3_iron_taunt",
	"warden_v3_iron_taunt_plus",
]
const TAUNT_BLOCK := {
	"warden_v3_iron_challenge": 3,
	"warden_v3_iron_challenge_plus": 5,
	"warden_v3_iron_taunt": 4,
	"warden_v3_iron_taunt_plus": 6,
}

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
	_test_taunt_service_catalog()
	_test_shieldwall_chorus_party_all()
	_test_taunt_paid_self_play()
	_test_taunt_projection_for_whole_enemy_turn()
	_test_taunt_expiry_and_following_turn()
	_test_taunt_projection_guards()
	_test_taunt_refusals()
	_test_taunt_refresh_and_replay()
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
## Presence, exact magnitudes and value types only here; the paid Iron Challenge / Iron Taunt
## play and its one-enemy-turn target projection are exercised separately below. Guard and the
## Block-based toss remain printed descriptors.
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


## The callable slice authenticates exactly the two Iron Challenge printings (starter catalog)
## and the two Iron Taunt printings (reward pool), each with its authored Block and Taunt line.
func _test_taunt_service_catalog() -> void:
	var service := CombatWardenV3TauntCards.new()
	var starter := V3WardenStarterCards.new()
	var pool := V3WardenPoolCards.new()
	var expected := {
		"warden_v3_iron_challenge": {"source": starter, "block": 3},
		"warden_v3_iron_challenge_plus": {"source": starter, "block": 5},
		"warden_v3_iron_taunt": {"source": pool, "block": 4},
		"warden_v3_iron_taunt_plus": {"source": pool, "block": 6},
	}
	_check(not service.has_pending_taunt(), "a fresh service arms no Taunt")
	for card_id: String in expected:
		var source: Variant = expected[card_id]["source"]
		var definition: Dictionary = source.get_definition(card_id)
		_check(not definition.is_empty(), card_id + ": authored Taunt record exists")
		_check(definition.get("owner") == "warden", card_id + ": owned by the Warden")
		_check(definition.get("cost") == 1, card_id + ": costs one energy")
		_check(definition.get("target_kind") == "self" and definition.get("to_positions") == [],
			card_id + ": self-targeting with no enemy slot")
		_check(definition.get("from_positions") == [1], card_id + ": printed FROM front seat 1")
		_check(definition.get("effects")
			== {"block": expected[card_id]["block"], "taunt_next_enemy_turn": true},
			card_id + ": own Block plus the next-enemy-turn Taunt payload")
		_check(service.is_supported_card(card_id), card_id + ": service supports the ID")
		_check(service.is_authentic_card(card_id), card_id + ": live catalog still authentic")
	_check(starter.get_definition("warden_v3_iron_challenge").get("starting_copies") == 1
		and starter.get_definition("warden_v3_iron_challenge_plus").get("starting_copies") == 0,
		"only the base Iron Challenge is a starter copy")
	_check(pool.get_definition("warden_v3_iron_taunt").get("reward_eligible") == true
		and pool.get_definition("warden_v3_iron_taunt_plus").get("reward_eligible") == false,
		"only the base Iron Taunt is reward eligible")
	_check(starter.get_definition("warden_v3_iron_challenge").get("upgrade_id")
		== "warden_v3_iron_challenge_plus"
		and starter.get_definition("warden_v3_iron_challenge_plus").get("upgrade_of")
		== "warden_v3_iron_challenge",
		"the starter base/upgrade link is unchanged")
	_check(pool.get_definition("warden_v3_iron_taunt").get("upgrade_id")
		== "warden_v3_iron_taunt_plus"
		and pool.get_definition("warden_v3_iron_taunt_plus").get("upgrade_of")
		== "warden_v3_iron_taunt",
		"the pool base/upgrade link is unchanged")
	# Shieldwall Chorus: genuine pool metadata, upgrade links, party-wide Block + Taunt.
	_check(service.is_supported_card("warden_v3_shieldwall_chorus"),
		"Shieldwall Chorus is a supported service card")
	_check(service.is_authentic_card("warden_v3_shieldwall_chorus"),
		"Shieldwall Chorus authenticates against the pool catalog")
	_check(service.is_supported_card("warden_v3_shieldwall_chorus_plus"),
		"Shieldwall Chorus+ is a supported service card")
	_check(service.is_authentic_card("warden_v3_shieldwall_chorus_plus"),
		"Shieldwall Chorus+ authenticates against the pool catalog")
	var chorus: Dictionary = pool.get_definition("warden_v3_shieldwall_chorus")
	_check(not chorus.is_empty(), "Shieldwall Chorus definition exists in pool")
	_check(chorus.get("display_name") == "Shieldwall Chorus", "Chorus display name")
	_check(chorus.get("cost") == 2, "Chorus costs 2 energy")
	_check(chorus.get("target_kind") == "party_all", "Chorus targets party_all")
	_check(chorus.get("from_positions") == [1, 2, 3], "Chorus from_positions [1,2,3]")
	_check(chorus.get("to_positions") == [], "Chorus has no enemy slot")
	_check(chorus.get("effects") == {"block_all": 4, "taunt_next_enemy_turn": true},
		"Chorus effects: block_all 4 + Taunt")
	_check(chorus.get("rarity") == "uncommon", "Chorus rarity uncommon")
	_check(chorus.get("reward_eligible") == true, "Chorus is reward eligible")
	_check(chorus.get("starting_copies") == 0, "Chorus has 0 starting copies")
	_check(chorus.get("upgrade_id") == "warden_v3_shieldwall_chorus_plus",
		"Chorus upgrade link points to +")
	var chorus_plus: Dictionary = pool.get_definition("warden_v3_shieldwall_chorus_plus")
	_check(not chorus_plus.is_empty(), "Shieldwall Chorus+ definition exists")
	_check(chorus_plus.get("upgrade_of") == "warden_v3_shieldwall_chorus",
		"Chorus+ points back to base")
	_check(chorus_plus.get("reward_eligible") == false, "Chorus+ is not reward eligible")
	_check(chorus_plus.get("cost") == 2, "Chorus+ costs 2 energy")
	_check(chorus_plus.get("effects") == {"block_all": 6, "taunt_next_enemy_turn": true},
		"Chorus+ effects: block_all 6 + Taunt")
	for unsupported in [
		"warden_v3_pot_helm_bonk", "warden_v3_pot_helm_bonk_plus", "warden_v3_shield_catch",
		"warden_v3_rim_toss", "warden_v3_shield_toss", "warden_v3_helmet_rattle",
		"warden_v3_guard_stitch", "warden_v3_rivet_pummel", "warden_v3_buckle_rebound",
		"warden_v3_final_bastion", "warden_strike",
		"warden_v3_iron_challenge_plus_plus", "warden_v3_iron_taunt_ULTRA", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not an Iron Challenge / Iron Taunt printing")
		_check(not service.is_authentic_card(unsupported),
			unsupported + ": never authenticates")
	_check(not service.is_supported_card(5) and not service.is_supported_card(null)
		and not service.is_supported_card(StringName("warden_v3_iron_taunt")),
		"non-string and StringName IDs fail closed")
	# A detached, altered copy of an authored record never rewrites the authoritative catalog.
	var copied: Dictionary = starter.get_definition("warden_v3_iron_challenge")
	copied["effects"]["block"] = 99
	copied["from_positions"] = [1, 2]
	_check(starter.get_definition("warden_v3_iron_challenge").get("effects")
		== {"block": 3, "taunt_next_enemy_turn": true}
		and starter.get_definition("warden_v3_iron_challenge").get("from_positions") == [1],
		"altered copied data leaves the authored record intact")


## Shieldwall Chorus: party-wide Block (4/6) + Taunt, from any seat 1-3, target party_all.
func _test_shieldwall_chorus_party_all() -> void:
	var service := CombatWardenV3TauntCards.new()
	var pool := V3WardenPoolCards.new()
	# Base card: 4 Block to all living heroes, cost 2, Warden can be in any seat.
	for base_id in ["warden_v3_shieldwall_chorus", "warden_v3_shieldwall_chorus_plus"]:
		var deck := _taunt_deck(base_id, 3333)
		var party := _taunt_party()
		# Seed each hero with some Block to prove additive.
		party.gain_block(1, 3)
		party.gain_block(2, 2)
		party.gain_block(3, 1)
		var before := _taunt_snapshot(deck, party, service)
		var result: Dictionary = service.play_card(deck, party, base_id, "party_all", 0)
		_check(result.get("ok") == true, base_id + ": paid party_all succeeds")
		_check(result.get("card_id") == base_id, base_id + ": receipt names card")
		_check(result.get("cost") == 2, base_id + ": receipt names 2 energy")
		_check(result.get("taunt_armed") == true, base_id + ": Taunt armed")
		_check(deck.energy == 1 and deck.combat_state.energy == 1,
			base_id + ": 3 -> 1 shared energy (cost 2)")
		_check(deck.hand.count(base_id) == 0 and deck.hand.size() == 4,
			base_id + ": held copy discarded")
		_check(deck.discard_pile.count(base_id) == 1 and deck.discard_pile.size() == 1,
			base_id + ": exactly one discard")
		# All three living heroes receive the authored Block amount.
		var expected_block: int = 4 if base_id == "warden_v3_shieldwall_chorus" else 6
		_check(party.get_hero(1)["block"] == 3 + expected_block,
			base_id + ": Warden Block 3 + " + str(expected_block))
		_check(party.get_hero(2)["block"] == 2 + expected_block,
			base_id + ": middle hero Block 2 + " + str(expected_block))
		_check(party.get_hero(3)["block"] == 1 + expected_block,
			base_id + ": rear hero Block 1 + " + str(expected_block))
		# Downed third hero gains nothing.
		party.apply_damage(3, 100)
		_check(party.is_downed(3), base_id + ": rear hero genuinely downed")
		var down_before := _taunt_snapshot(deck, party, service)
		var down_result: Dictionary = service.play_card(_taunt_deck(base_id, 4444), party, base_id, "party_all", 0)
		_check(down_result.get("ok") == true, base_id + ": downed ally still casts")
		_check(party.get_hero(1)["block"] == 3 + 3 + expected_block + expected_block,
			base_id + ": Warden gains again with one downed ally")
		_check(party.get_hero(2)["block"] == 2 + 2 + expected_block + expected_block,
			base_id + ": middle hero gains again")
		_check(party.get_hero(3)["block"] == 1 + expected_block,
			base_id + ": downed rear hero stays at its pre-down Block (no addition)")

	# Warden can cast from seat 2 or 3 (from_positions [1,2,3]).
	var moved_party := _moved_party(2)
	var moved_service := CombatWardenV3TauntCards.new()
	var moved_deck := _taunt_deck("warden_v3_shieldwall_chorus", 5555)
	var moved_result: Dictionary = moved_service.play_card(moved_deck, moved_party, "warden_v3_shieldwall_chorus", "party_all", 0)
	_check(moved_result.get("ok") == true, "Chorus from seat 2 succeeds")
	_check(moved_result.get("owner_position") == 2, "Chorus owner is seat 2")

	# Projection: enemy attack at seat 2 redirects to Warden at current seat.
	var proj_service := CombatWardenV3TauntCards.new()
	var proj_party := _taunt_party()
	var proj_deck := _taunt_deck("warden_v3_shieldwall_chorus", 6666)
	_check(proj_service.play_card(proj_deck, proj_party, "warden_v3_shieldwall_chorus", "party_all", 0).get("ok"),
		"projection fixture arms Chorus")
	proj_deck.end_turn()
	var proj_target2 := proj_service.project_attack_target(proj_party, 2)
	_check(proj_target2.get("redirected") == true and proj_target2.get("actual_target_position") == 1,
		"Chorus redirects attack at seat 2 to Warden at seat 1")
	var proj_target3 := proj_service.project_attack_target(proj_party, 3)
	_check(proj_target3.get("redirected") == true and proj_target3.get("actual_target_position") == 1,
		"Chorus redirects attack at seat 3 to Warden at seat 1")

	# Second legal Taunt refresh and complete_enemy_turn expiry.
	var refresh_service := CombatWardenV3TauntCards.new()
	var refresh_party := _taunt_party()
	var refresh_deck := CombatDeck.new([
		"warden_v3_shieldwall_chorus", "warden_v3_shieldwall_chorus_plus",
		TAUNT_FILLERS[0], TAUNT_FILLERS[1], TAUNT_FILLERS[2]], _taunt_rng(7777))
	refresh_deck.start_turn()
	_check(refresh_service.play_card(refresh_deck, refresh_party, "warden_v3_shieldwall_chorus", "party_all", 0).get("ok") == true,
		"refresh: first Chorus arms Taunt")
	_check(refresh_service.play_card(refresh_deck, refresh_party, "warden_v3_shieldwall_chorus_plus", "party_all", 0).get("ok") == true,
		"refresh: second Chorus+ refreshes same phase")
	_check(refresh_service.get_pending_taunt_card_id() == "warden_v3_shieldwall_chorus_plus",
		"latest card ID is the refreshed one")
	refresh_deck.end_turn()
	_check(refresh_service.project_attack_target(refresh_party, 2).get("redirected") == true,
		"refreshed Taunt redirects")
	_check(refresh_service.complete_enemy_turn() == true, "complete_enemy_turn consumes once")
	_check(not refresh_service.has_pending_taunt(), "Taunt expired after complete turn")

	# Refusals for Shieldwall Chorus.
	var ref_service := CombatWardenV3TauntCards.new()
	var ref_party := _taunt_party()
	var ref_deck := _taunt_deck("warden_v3_shieldwall_chorus", 8888)
	# Invalid target kind for party_all card.
	_rejected_taunt(ref_service, ref_deck, ref_party, "warden_v3_shieldwall_chorus", "self", 0,
		"Chorus with self target kind rejected")
	# Nonzero target position for party_all.
	_rejected_taunt(ref_service, ref_deck, ref_party, "warden_v3_shieldwall_chorus", "party_all", 1,
		"Chorus with nonzero target rejected")
	# Wrong seat: old Iron requires seat 1; this card allows any seat, but missing Warden still fails.
	var no_warden_party := CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
		{"id": "apprentice", "max_hp": 20},
	])
	_rejected_taunt(ref_service, _taunt_deck("warden_v3_shieldwall_chorus", 9999), no_warden_party,
		"warden_v3_shieldwall_chorus", "party_all", 0, "Chorus with missing Warden rejected")
	# Insufficient energy (needs 2).
	var short_energy := _taunt_deck("warden_v3_shieldwall_chorus", 7771)
	short_energy.energy = 1
	_rejected_taunt(ref_service, short_energy, ref_party, "warden_v3_shieldwall_chorus", "party_all", 0,
		"Chorus with 1 energy rejected")
	# Overflow: any recipient overflow rejects entire card.
	var overflow_party := _taunt_party()
	overflow_party.gain_block(1, CombatParty.MAX_INT - 1)
	var overflow_deck := _taunt_deck("warden_v3_shieldwall_chorus", 7772)
	var overflow_before := _taunt_snapshot(overflow_deck, overflow_party, ref_service)
	var overflow_result: Dictionary = ref_service.play_card(overflow_deck, overflow_party, "warden_v3_shieldwall_chorus", "party_all", 0)
	_check(overflow_result.get("ok") == false, "Chorus with overflow Block rejected")
	_check(_taunt_snapshot(overflow_deck, overflow_party, ref_service) == overflow_before,
		"overflow refusal mutates nothing")


## AC1: for each of the four authentic printings, one paid self play spends exactly one energy,
## discards exactly the one held copy, adds its own printed Block and arms one pending Taunt.
func _test_taunt_paid_self_play() -> void:
	for card_id: String in TAUNT_CARDS:
		var service := CombatWardenV3TauntCards.new()
		var party := _taunt_party()
		var gain: int = TAUNT_BLOCK[card_id]
		_check(party.gain_block(1, 2), card_id + ": Warden seeded with two Block")
		_check(party.gain_block(2, 5) and party.gain_block(3, 7),
			card_id + ": companions seeded with their own Block")
		party._heroes[0]["statuses"] = {"weak": 1}
		party._heroes[1]["statuses"] = {"weak": 2}
		party._heroes[2]["statuses"] = {"exposed": 1, "bleed": 1}
		var deck := _taunt_deck(card_id, 20261028 + TAUNT_CARDS.find(card_id))
		var before := _taunt_snapshot(deck, party, service)
		var warden_before: Dictionary = party.get_hero(1)
		var companion_before: Dictionary = party.get_hero(2)
		var rear_before: Dictionary = party.get_hero(3)

		var result: Dictionary = service.play_card(deck, party, card_id, "self", 1)
		_check(result.get("ok") == true, card_id + ": paid self play succeeds")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			card_id + ": receipt names the card and its one energy")
		_check(result.get("owner_position") == 1, card_id + ": the Warden is the owner")
		_check(result.get("block_gained") == gain
			and result.get("block") == 2 + gain,
			card_id + ": receipt reports exactly the printed Block")
		_check(deck.energy == 2 and deck.combat_state.energy == 2,
			card_id + ": 3 -> 2 shared energy")
		_check(deck.hand.count(card_id) == 0 and deck.hand.size() == 4,
			card_id + ": the only held copy left the hand")
		_check(deck.discard_pile.count(card_id) == 1 and deck.discard_pile.size() == 1,
			card_id + ": exactly one copy reached the discard pile")
		_check(party.get_hero(1)["block"] == warden_before["block"] + gain,
			card_id + ": additive Block landed on the Warden")
		_check(party.get_hero(1)["hp"] == warden_before["hp"]
			and party.get_hero(1).get("statuses", {}) == {"weak": 1},
			card_id + ": the Warden's HP and status map are unchanged")
		_check(party.get_hero(2) == companion_before and party.get_hero(3) == rear_before,
			card_id + ": both companions keep HP, Block and statuses")
		_check(service.has_pending_taunt() and service.get_pending_taunt_card_id() == card_id,
			card_id + ": exactly one next-enemy-turn Taunt is armed")

		var expected: Dictionary = before.duplicate(true)
		expected["energy"] -= 1
		expected["state_energy"] -= 1
		var expected_hand: Array = expected["hand"]
		expected_hand.erase(card_id)
		var expected_discard: Array = expected["discard"]
		expected_discard.append(card_id)
		var expected_heroes: Array = expected["heroes"]
		expected_heroes[0]["block"] = int(expected_heroes[0]["block"]) + gain
		expected["taunt_pending"] = true
		expected["taunt_card_id"] = card_id
		_check(_taunt_snapshot(deck, party, service) == expected,
			card_id + ": exact hand/piles/energy/party/Taunt and untouched RNG")
		_check(_taunt_snapshot(deck, party, service)["rng_state"] == before["rng_state"],
			card_id + ": the play consumes no seeded RNG draws")


## AC2: the same pending Taunt redirects several targetable attacks in the SAME next enemy turn,
## leaves one already aimed at the Warden alone, preserves each action's numbers and mutates
## nothing while projecting.
func _test_taunt_projection_for_whole_enemy_turn() -> void:
	var service := CombatWardenV3TauntCards.new()
	var party := _taunt_party()
	var deck := _taunt_deck("warden_v3_iron_challenge")
	_check(service.play_card(deck, party, "warden_v3_iron_challenge").get("ok") == true,
		"projection fixture arms its Taunt")
	_check(deck.end_turn() and not deck.turn_active,
		"the player turn really ends into the next enemy turn")
	var before := _taunt_snapshot(deck, party, service)

	var first := service.project_attack_target(party, 2)
	var second := service.project_attack_target(party, 3)
	var repeated := service.project_attack_target(party, 2)
	var on_warden := service.project_attack_target(party, 1)
	_check(first.get("ok") == true and first.get("eligible") == true
		and first.get("redirected") == true
		and first.get("announced_target_position") == 2
		and first.get("actual_target_position") == 1,
		"the first ally-targeted attack of the phase aims at the Warden")
	_check(second.get("ok") == true and second.get("redirected") == true
		and second.get("announced_target_position") == 3
		and second.get("actual_target_position") == 1,
		"a later attack in the same phase also aims at the Warden, not only the first")
	_check(repeated == first, "each attack is projected independently and identically")
	_check(on_warden.get("ok") == true and on_warden.get("eligible") == true
		and on_warden.get("redirected") == false
		and on_warden.get("actual_target_position") == 1,
		"an attack already aimed at the Warden stays there")
	_check(service.has_pending_taunt(), "projection alone never consumes the Taunt")
	_check(_taunt_snapshot(deck, party, service) == before,
		"projection mutates no party, deck, Taunt or RNG state")

	var attack_a: Dictionary = {"type": "attack", "enemy_position": 1,
		"target_position": 3, "amount": 7}
	var projected_a: Dictionary = service.project_enemy_action(party, attack_a)
	_check(projected_a.get("ok") == true and projected_a.get("targetable") == true
		and projected_a.get("redirected") == true
		and projected_a["action"].get("target_position") == 1,
		"a whole announced attack projects onto the Warden's seat")
	_check(attack_a.get("target_position") == 3,
		"the caller's announced action is never rewritten")
	var multi: Dictionary = {"type": "attack", "enemy_position": 2,
		"target_position": 2, "amount": 4, "hits": 2}
	var projected_multi: Dictionary = service.project_enemy_action(party, multi)
	_check(projected_multi["action"].get("target_position") == 1
		and projected_multi["action"].get("amount") == 4
		and projected_multi["action"].get("hits") == 2,
		"Taunt changes the seat, never the damage, hit count or ownership")

	# Non-targeted beats stay entirely outside this contract: same detached action, no redirect.
	for action: Dictionary in [
		{"type": "block", "amount": 5},
		{"type": "buff", "amount": 2},
		{"type": "debuff", "target_position": 3, "amount": 1, "status": "weak"},
		{"type": "shove", "target_position": 2, "amount": 0, "direction": 1},
		{"type": "snip_block", "target_position": 3, "amount": 0},
	]:
		var beat: Dictionary = service.project_enemy_action(party, action)
		_check(beat.get("ok") == true and beat.get("targetable") == false
			and beat.get("redirected") == false and beat["action"] == action,
			str(action.get("type")) + " is returned unchanged and never redirected")
	_check(service.has_pending_taunt()
		and _taunt_snapshot(deck, party, service) == before,
		"non-targeted actions leave the pending Taunt and every actor untouched")


## AC2: one complete enemy turn consumes the armed Taunt exactly once; the following enemy turn
## keeps the originally announced ally target, and a fresh play arms the next turn again.
func _test_taunt_expiry_and_following_turn() -> void:
	var service := CombatWardenV3TauntCards.new()
	var party := _taunt_party()
	var deck := _taunt_deck("warden_v3_iron_taunt")
	_check(service.play_card(deck, party, "warden_v3_iron_taunt").get("ok") == true,
		"expiry fixture arms Iron Taunt")
	_check(deck.end_turn(), "expiry fixture enters the next enemy turn")
	_check(service.project_attack_target(party, 2).get("redirected") == true,
		"the armed phase really redirects before expiry")
	_check(service.complete_enemy_turn() == true,
		"the whole next enemy turn consumes the armed Taunt once")
	_check(not service.has_pending_taunt() and service.get_pending_taunt_card_id() == "",
		"no pending Taunt remains after that complete phase")
	var later_two := service.project_attack_target(party, 2)
	var later_three := service.project_attack_target(party, 3)
	_check(later_two.get("ok") == true and later_two.get("eligible") == true
		and later_two.get("redirected") == false
		and later_two.get("actual_target_position") == 2,
		"the following enemy turn preserves the announced middle target")
	_check(later_three.get("actual_target_position") == 3
		and later_three.get("redirected") == false,
		"the following enemy turn preserves the announced rear target")
	_check(service.complete_enemy_turn() == false,
		"a following enemy turn expires nothing further")
	# A later legal Taunt arms the next upcoming phase from scratch.
	var rearm := _taunt_deck("warden_v3_iron_taunt_plus", 9174)
	_check(service.play_card(rearm, party, "warden_v3_iron_taunt_plus").get("ok") == true,
		"a later player turn can arm a fresh Taunt")
	_check(service.project_attack_target(party, 3).get("actual_target_position") == 1,
		"the freshly armed Taunt redirects its own next enemy turn")


## AC2: a torn or missing Warden never attracts attacks, an already-downed announced target is
## never projected into a legal one, and the projection reads the Warden's actual current seat.
func _test_taunt_projection_guards() -> void:
	var service := CombatWardenV3TauntCards.new()
	var party := _taunt_party()
	var deck := _taunt_deck("warden_v3_iron_challenge")
	_check(service.play_card(deck, party, "warden_v3_iron_challenge").get("ok") == true,
		"guard fixture arms its Taunt")
	_check(deck.end_turn(), "guard fixture enters the next enemy turn")

	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"the middle hero is really downed mid-turn")
	var downed_target := service.project_attack_target(party, 2)
	_check(downed_target.get("ok") == true and downed_target.get("eligible") == false
		and downed_target.get("redirected") == false
		and downed_target.get("actual_target_position") == 2,
		"a downed announced target is not projected onto the living Warden")
	var living_target := service.project_attack_target(party, 3)
	_check(living_target.get("redirected") == true
		and living_target.get("actual_target_position") == 1,
		"a living ally attack in the same phase still reaches the Warden")

	_check(party.apply_damage(1, 100) and party.is_downed(1),
		"the Warden is really downed mid-turn")
	var after_torn := service.project_attack_target(party, 3)
	_check(after_torn.get("ok") == true and after_torn.get("redirected") == false
		and after_torn.get("actual_target_position") == 3,
		"no new attack redirects to a downed Warden")
	var torn_warden_target := service.project_attack_target(party, 1)
	_check(torn_warden_target.get("ok") == true
		and torn_warden_target.get("eligible") == false
		and torn_warden_target.get("actual_target_position") == 1,
		"an already-announced attack on the torn Warden keeps its original seat")
	_check(service.has_pending_taunt(),
		"a mid-turn downing does not silently spend the Taunt before turn end")

	# The projection re-reads his actual seat, not a remembered seat 1.
	var shifted := CombatWardenV3TauntCards.new()
	var shifted_party := _taunt_party()
	var shifted_deck := _taunt_deck("warden_v3_iron_taunt", 8801)
	_check(shifted.play_card(shifted_deck, shifted_party, "warden_v3_iron_taunt").get("ok") == true,
		"seat-shift fixture arms its Taunt")
	_check(shifted_deck.end_turn(), "seat-shift fixture enters the next enemy turn")
	_swap_seats(shifted_party, 1, 2)
	_check(shifted_party.get_hero(2).get("id") == "warden",
		"a mid-turn swap really moved the Warden to seat 2")
	var shifted_projection := shifted.project_attack_target(shifted_party, 3)
	_check(shifted_projection.get("redirected") == true
		and shifted_projection.get("actual_target_position") == 2,
		"the projection follows the Warden's actual current seat")

	# A valid party without any Warden never redirects.
	var no_warden := CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
		{"id": "apprentice", "max_hp": 20},
	])
	_check(no_warden.is_valid(), "absent-Warden fixture is a valid party")
	var absent := service.project_attack_target(no_warden, 2)
	_check(absent.get("ok") == true and absent.get("redirected") == false
		and absent.get("actual_target_position") == 2,
		"a missing Warden preserves the announced ally target")
	# Invalid targets and invalid parties fail closed instead of inventing a legal seat.
	for invalid_target: int in [0, -1, 4, 99]:
		_check(service.project_attack_target(_taunt_party(), invalid_target).get("ok") == false,
			"invalid target " + str(invalid_target) + " is not projected")
	_check(service.project_attack_target(null, 2).get("ok") == false,
		"a null party is not projected")
	_check(service.project_attack_target(CombatParty.new([]), 2).get("ok") == false,
		"an invalid party roster is not projected")
	# An unarmed service preserves every announced target.
	var idle := CombatWardenV3TauntCards.new()
	_check(idle.project_attack_target(_taunt_party(), 2).get("actual_target_position") == 2,
		"without an armed Taunt the announced target is preserved")


## AC3: every invalid paid request fails closed without touching hand, piles, energy, Block,
## the pending Taunt or the injected RNG.
func _test_taunt_refusals() -> void:
	var service := CombatWardenV3TauntCards.new()
	var card := "warden_v3_iron_challenge"
	var foreign := _taunt_deck("warden_v3_pot_helm_bonk")
	_rejected_taunt(service, foreign, _taunt_party(), "warden_v3_pot_helm_bonk", "self", 0,
		"foreign Warden card")
	var deck := _taunt_deck(card)
	var party := _taunt_party()
	_rejected_taunt(service, deck, party, "warden_v3_iron_taunt", "self", 0,
		"authentic but unheld pool ID")
	_rejected_taunt(service, deck, party, "warden_v3_iron_challenge_plus", "self", 0,
		"authentic but unheld upgrade")
	_rejected_taunt(service, deck, party, "warden_v3_iron_challenge_plus_plus", "self", 0,
		"forged plus-of-plus ID")
	_rejected_taunt(service, deck, party, "warden_v3_iron_challenge_ULTRA", "self", 0,
		"forged uppercase ID")
	_rejected_taunt(service, deck, party, "", "self", 0, "empty card ID")
	_rejected_taunt(service, deck, party, StringName(card), "self", 0, "StringName card ID")
	_rejected_taunt(service, deck, party, 5, "self", 0, "numeric card ID")

	# This self card never accepts an enemy or ally target, nor another hero seat.
	_rejected_taunt(service, deck, party, card, "enemy_single", 1, "enemy-target request")
	_rejected_taunt(service, deck, party, card, "enemy_single", 2, "enemy-target middle request")
	_rejected_taunt(service, deck, party, card, "ally_single", 2, "ally-target request")
	_rejected_taunt(service, deck, party, card, "self", 2, "wrong self target (middle seat)")
	_rejected_taunt(service, deck, party, card, "self", 3, "wrong self target (rear seat)")
	_rejected_taunt(service, deck, party, card, "self", -1, "negative self target")

	var short := _taunt_deck(card, 5511)
	_check(short.try_spend_energy(3) and short.energy == 0 and short.hand.has(card),
		"no-energy fixture is genuinely broke while holding the card")
	_rejected_taunt(service, short, _taunt_party(), card, "self", 0, "no energy")

	var inactive := _taunt_deck(card, 5512)
	inactive.combat_state.end_player_turn()
	inactive.combat_state.energy = CombatState.TURN_ENERGY
	_check(not inactive.turn_active and inactive.hand.has(card) and inactive.energy == 3,
		"inactive-turn fixture holds the card and full energy but no active turn")
	_rejected_taunt(service, inactive, _taunt_party(), card, "self", 0, "inactive turn")

	var torn := _taunt_party()
	_check(torn.apply_damage(1, 40) and torn.is_downed(1),
		"torn-Warden fixture is genuinely downed")
	_rejected_taunt(service, _taunt_deck(card, 5513), torn, card, "self", 0, "downed Warden")
	_rejected_taunt(service, _taunt_deck(card, 5514), _moved_party(2), card, "self", 0,
		"Warden moved to seat 2")
	var no_warden := CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
		{"id": "apprentice", "max_hp": 20},
	])
	_rejected_taunt(service, _taunt_deck(card, 5515), no_warden, card, "self", 0,
		"Warden absent from the party")

	var full := _taunt_party()
	full._heroes[0]["block"] = CombatParty.MAX_INT
	_rejected_taunt(service, _taunt_deck(card, 5516), full, card, "self", 0,
		"no remaining Block capacity")
	var corrupt := _taunt_party()
	corrupt._heroes[0]["block"] = "nine"
	_rejected_taunt(service, _taunt_deck(card, 5517), corrupt, card, "self", 0,
		"malformed Warden Block state")
	var over_healed := _taunt_party()
	over_healed._heroes[0]["hp"] = 41
	_rejected_taunt(service, _taunt_deck(card, 5518), over_healed, card, "self", 0,
		"Warden HP above maximum")

	# Null and invalid containers fail closed too.
	var service_only := _taunt_snapshot(null, null, service)
	_check(service.play_card(null, party, card).get("ok") == false, "null deck is refused")
	_check(service.play_card(deck, null, card).get("ok") == false, "null party is refused")
	_check(service.play_card(deck, CombatParty.new([]), card).get("ok") == false,
		"invalid party roster is refused")
	_check(_taunt_snapshot(null, null, service) == service_only,
		"null/invalid container refusals mutate no Taunt state")

	# A refusal never clears an already-armed Taunt.
	var armed := CombatWardenV3TauntCards.new()
	var armed_deck := _taunt_deck("warden_v3_iron_taunt", 5519)
	_check(armed.play_card(armed_deck, party, "warden_v3_iron_taunt").get("ok") == true,
		"armed-refusal fixture really arms a Taunt")
	_rejected_taunt(armed, armed_deck, party, "warden_v3_iron_taunt", "self", 0,
		"replay of the already-discarded copy")
	_check(armed.has_pending_taunt()
		and armed.get_pending_taunt_card_id() == "warden_v3_iron_taunt",
		"a refused replay leaves the armed Taunt intact")


## Two legal Taunt cards in the same player turn refresh one upcoming phase; neither stacks damage
## nor extends the armed state to a second enemy turn.
func _test_taunt_refresh_and_replay() -> void:
	var service := CombatWardenV3TauntCards.new()
	var party := _taunt_party()
	var ids: Array[String] = ["warden_v3_iron_challenge", "warden_v3_iron_taunt",
		TAUNT_FILLERS[0], TAUNT_FILLERS[1], TAUNT_FILLERS[2]]
	var deck := CombatDeck.new(ids, _taunt_rng(4471))
	_check(deck.start_turn() and deck.hand.has("warden_v3_iron_challenge")
		and deck.hand.has("warden_v3_iron_taunt") and deck.energy == 3,
		"refresh fixture really holds both Taunt cards and three energy")
	var first: Dictionary = service.play_card(deck, party, "warden_v3_iron_challenge")
	var second: Dictionary = service.play_card(deck, party, "warden_v3_iron_taunt", "self", 1)
	_check(first.get("ok") == true and second.get("ok") == true,
		"both legal Taunt cards resolve in the same player turn")
	_check(party.get_hero(1)["block"] == 3 + 4,
		"each card's own Block really landed, without multiplication")
	_check(deck.energy == 1 and deck.discard_pile.size() == 2,
		"two plays charge two energy and discard two copies")
	_check(service.has_pending_taunt()
		and service.get_pending_taunt_card_id() == "warden_v3_iron_taunt",
		"the latest legal Taunt refreshes the same upcoming phase")
	_check(service.project_attack_target(party, 2).get("actual_target_position") == 1,
		"the refreshed phase redirects to the Warden once")
	_check(service.complete_enemy_turn() == true, "one complete enemy turn consumes the Taunt")
	_check(service.complete_enemy_turn() == false,
		"two Taunt cards never buy an extra enemy turn of redirection")
	_check(service.project_attack_target(party, 2).get("actual_target_position") == 2,
		"the refreshed Taunt is gone on the following enemy turn")
	# With both copies spent, a third play is genuinely unheld, not silently free.
	var spent := _taunt_snapshot(deck, party, service)
	var refused: Dictionary = service.play_card(deck, party, "warden_v3_iron_challenge")
	_check(refused.get("ok") == false and refused.get("block_gained") == 0,
		"a spent Taunt copy cannot be replayed")
	_check(_taunt_snapshot(deck, party, service) == spent,
		"the replay refusal changes no pile, energy, Block, Taunt or RNG")


## One non-mutating snapshot of the paid transaction's whole surface.
func _taunt_snapshot(deck: CombatDeck, party: CombatParty,
		service: CombatWardenV3TauntCards) -> Dictionary:
	var result: Dictionary = {}
	if party != null:
		result["heroes"] = party.get_heroes()
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
	if service != null:
		result["taunt_pending"] = service.has_pending_taunt()
		result["taunt_card_id"] = service.get_pending_taunt_card_id()
	return result


func _rejected_taunt(service: CombatWardenV3TauntCards, deck: CombatDeck, party: CombatParty,
		card_id: Variant, target_kind: String, target_position: int, label: String) -> void:
	var before := _taunt_snapshot(deck, party, service)
	var result: Dictionary = service.play_card(deck, party, card_id, target_kind,
		target_position)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("block_gained") == 0 and result.get("taunt_armed") == false,
		label + ": refusal reports no Block and no Taunt")
	_check(_taunt_snapshot(deck, party, service) == before,
		label + ": no energy, hand, pile, party, Taunt or RNG mutation")


func _taunt_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real five-card hand from five cards, so the named ID is genuinely drawn exactly once.
func _taunt_deck(card_id: String, seed_value: int = 20261028) -> CombatDeck:
	var ids: Array[String] = [card_id, TAUNT_FILLERS[0], TAUNT_FILLERS[1],
		TAUNT_FILLERS[2], TAUNT_FILLERS[3]]
	var deck := CombatDeck.new(ids, _taunt_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) == 1,
		card_id + ": real seeded five-card hand holds exactly one copy and three energy")
	return deck


## The real authored three-hero party (Warden 40 HP at seat 1), with no hand-built actors.
func _taunt_party() -> CombatParty:
	var raw: String = FileAccess.get_file_as_string(HEROES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Array or parsed.size() != CombatParty.PARTY_SIZE:
		_check(false, "real authored starter party file supplies all three heroes")
		return CombatParty.new([])
	for hero in parsed:
		if hero is Dictionary and hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(parsed)
	_check(party.is_valid() and party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("max_hp") == 40 and party.get_hero(1).get("hp") == 40,
		"valid real CombatParty with the 40-HP Warden at seat 1")
	return party


## A genuine adjacent swap through the real position rules, not a hand-built roster.
func _moved_party(position: int) -> CombatParty:
	var party := _taunt_party()
	var move_id := "fixture_warden_forward"
	var moving := CombatDeck.new([move_id, move_id, move_id], _taunt_rng(345))
	_check(moving.start_turn(), "position fixture begins a legitimate shared turn")
	var definition := {"id": move_id, "owner": "warden", "cost": 0,
		"from_positions": [1, 2, 3], "action_kind": "adjacent_swap", "direction": 1}
	for _step in range(position - 1):
		_check(CombatPositionSwaps.play_move_card(moving, party, move_id, definition),
			"actual adjacent move shifts the Warden forward")
	_check(party.get_hero(position).get("id") == "warden"
		and party.get_hero(position).get("position") == position,
		"Warden identity is really at actual slot " + str(position))
	return party


## Mid-enemy-turn movement of two authoritative hero records, the same shape the shared enemy
## phase writes when a shove lands. Positions stay 1..3.
func _swap_seats(party: CombatParty, first: int, second: int) -> void:
	var a: Dictionary = party._heroes[first - 1]
	var b: Dictionary = party._heroes[second - 1]
	party._heroes[first - 1] = b
	party._heroes[second - 1] = a
	a["position"] = second
	b["position"] = first
