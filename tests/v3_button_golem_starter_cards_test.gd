extends SceneTree
## V3-1 Button Golem starter-card catalog contract plus the callable Block-paid Pop Button
## resolver. The catalogs stay descriptor-only and nothing here claims live hand, party-picker,
## reward or map wiring: these cases drive the scene-free combat rules layer directly with real
## CombatDeck/CombatParty/CombatEnemies state.

const ButtonGolemStarterCards = preload("res://data/cards/button_golem_starter_cards.gd")
const ButtonGolemRewardCards = preload("res://data/cards/button_golem_pool_cards.gd")
const PopResolver = preload("res://scripts/combat_button_golem_pop_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")

## The four authentic Pop Button printings, each with its own catalog and printed damage.
const POP_PRINTINGS := {
	"button_golem_starter_loose_pop": {"catalog": "starter", "damage": 9},
	"button_golem_starter_loose_pop_plus": {"catalog": "starter", "damage": 11},
	"button_golem_pop_button": {"catalog": "pool", "damage": 9},
	"button_golem_pop_button_plus": {"catalog": "pool", "damage": 12},
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
	_test_pop_printings()
	_test_pop_paid_resolution()
	_test_pop_blocked_enemy_and_accumulation()
	_test_pop_status_adjusted_hit()
	_test_pop_refusals()
	_test_pop_replay()
	if failures.is_empty():
		print("v3_button_golem_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_button_golem_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Literal, independent expectations for each of the four authored base/"+" pairs.
func _cases() -> Dictionary:
	return {
		"button_golem_starter_button_fist": {
			"name": "Button Fist", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 5, "block_self": 2},
			"plus_cost": 1, "plus_effects": {"damage": 7, "block_self": 3}},
		"button_golem_starter_loose_pop": {
			"name": "Loose Button Pop", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"spend_block": 5, "damage": 9, "buttons_popped": 1},
			"plus_cost": 1, "plus_effects": {"spend_block": 5, "damage": 11, "buttons_popped": 1}},
		"button_golem_starter_threadwheel_roll": {
			"name": "Threadwheel Roll", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"swap_with_ally": 1, "block_self": 5},
			"plus_cost": 1, "plus_effects": {"swap_with_ally": 1, "block_self": 7}},
		"button_golem_starter_seam_resew": {
			"name": "Seam Re-Sew", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block_per_button_popped": 1},
			"plus_cost": 1, "plus_effects": {"block_per_button_popped": 1, "block": 2}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "button_golem",
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
	var catalog := ButtonGolemStarterCards.new()
	var cases: Dictionary = _cases()
	_check(cases.size() == 4, "exactly four authored base cases are enumerated")
	# Each base and its upgrade stand alone: no shared illustration or ID collisions.
	var art_paths: Array[String] = []
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(catalog.has_card(base_id), base_id + " is authored")
		_check(catalog.has_card(plus_id), plus_id + " is authored")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + "_plus is not authored")
		_check(base_id.begins_with("button_golem_starter_"), base_id + " carries the starter prefix")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("owner") == "button_golem", card_id + " is owned by button_golem")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has an effect dictionary")
			_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
				and record.get("reward_eligible") == false, card_id + " is never reward eligible")
			_check(not record.has("rarity"), card_id + " carries no reward rarity")
			_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
				card_id + " shares its base illustration path")
			var effects: Dictionary = record.get("effects")
			_check(effects.size() == expected["effects"].size(),
				card_id + " prints exactly the documented effects")
			for key: String in expected["effects"]:
				_check(typeof(effects.get(key)) == TYPE_INT,
					card_id + " effect " + key + " is an integer magnitude")
		_check(catalog.get_definition(base_id).get("starting_copies") == 1,
			base_id + " starts with one copy")
		_check(catalog.get_definition(plus_id).get("starting_copies") == 0,
			plus_id + " adds no starting copy")
		_check(not catalog.get_definition(base_id).has("upgrade_of"),
			base_id + " is not itself an upgrade")
		_check(not catalog.get_definition(plus_id).has("upgrade_id"),
			plus_id + " has no onward upgrade link")
		_check(catalog.get_definition(base_id).get("illustration_path")
			== catalog.get_definition(plus_id).get("illustration_path"),
			base_id + " base and upgrade share one illustration path")
		art_paths.append(str(catalog.get_definition(base_id).get("illustration_path")))
	for path: String in art_paths:
		_check(art_paths.count(path) == 1, path + " is unique to its own starter")


## The printed look descriptors: a clipping fist with self Block, a 5-Block Pop Button hit with
## one popped button, an ally swap that Blocks the Golem, and per-popped-button Block.
## Presence and exact magnitudes only; nothing here claims live combat resolution.
func _test_look_descriptors() -> void:
	var catalog := ButtonGolemStarterCards.new()
	for suffix: String in ["", "_plus"]:
		var fist: Dictionary = catalog.get_definition("button_golem_starter_button_fist" + suffix)
		_check(fist.get("target_kind") == "enemy_single" and fist.get("to_positions") == [1, 2],
			"Button Fist clips a front enemy" + suffix)
		_check(fist.get("from_positions") == [1, 2],
			"Button Fist swings from the front or middle slot" + suffix)
		_check(fist.get("effects").has("damage") and fist.get("effects").has("block_self"),
			"Button Fist prints damage plus self Block" + suffix)
		_check(not fist.get("effects").has("block"),
			"Button Fist never shields the chosen enemy" + suffix)

		var pop: Dictionary = catalog.get_definition("button_golem_starter_loose_pop" + suffix)
		_check(pop.get("target_kind") == "enemy_single" and pop.get("to_positions") == [1, 2],
			"Loose Button Pop hits one front enemy" + suffix)
		_check(pop.get("effects").get("spend_block") == 5,
			"Loose Button Pop requires exactly five Block" + suffix)
		_check(pop.get("effects").get("buttons_popped") == 1,
			"Loose Button Pop counts one popped button" + suffix)
		_check(pop.get("effects").size() == 3,
			"Loose Button Pop prints no extra descriptor" + suffix)
		_check(not pop.get("effects").has("block_per_button_popped"),
			"Loose Button Pop does not scale on earlier pops" + suffix)

		var roll: Dictionary = catalog.get_definition("button_golem_starter_threadwheel_roll" + suffix)
		_check(roll.get("target_kind") == "ally_single" and roll.get("to_positions") == [],
			"Threadwheel Roll picks one living ally without a slot target" + suffix)
		_check(roll.get("from_positions") == [1, 2, 3],
			"Threadwheel Roll can roll from any slot" + suffix)
		_check(roll.get("effects").get("swap_with_ally") == 1,
			"Threadwheel Roll swaps with exactly one ally" + suffix)
		_check(roll.get("effects").has("block_self") and not roll.get("effects").has("block"),
			"Threadwheel Roll awards Block to the Golem, not the selected ally" + suffix)
		_check(roll.get("effects").size() == 2,
			"Threadwheel Roll prints no extra descriptor" + suffix)

		var resew: Dictionary = catalog.get_definition("button_golem_starter_seam_resew" + suffix)
		_check(resew.get("target_kind") == "self" and resew.get("to_positions") == [],
			"Seam Re-Sew targets the Golem itself" + suffix)
		_check(resew.get("from_positions") == [1, 2, 3],
			"Seam Re-Sew works from any slot" + suffix)
		_check(resew.get("effects").get("block_per_button_popped") == 1,
			"Seam Re-Sew grants one Block per popped button" + suffix)
		_check(not resew.get("effects").has("buttons_popped")
			and not resew.get("effects").has("spend_block"),
			"Seam Re-Sew never creates or spends a button count" + suffix)
	_check(catalog.get_definition("button_golem_starter_button_fist").get("effects").get("damage") == 5
		and catalog.get_definition("button_golem_starter_button_fist_plus").get("effects").get("damage") == 7,
		"Button Fist damage is five then seven")
	_check(catalog.get_definition("button_golem_starter_button_fist").get("effects").get("block_self") == 2
		and catalog.get_definition("button_golem_starter_button_fist_plus").get("effects").get("block_self") == 3,
		"Button Fist self Block is two then three")
	# v3 Pop Button is exactly spend 5 Block for 9 damage; the upgrade only raises the damage.
	_check(catalog.get_definition("button_golem_starter_loose_pop").get("effects")
		== {"spend_block": 5, "damage": 9, "buttons_popped": 1},
		"base Loose Button Pop preserves v3 Pop Button spend five for nine")
	_check(catalog.get_definition("button_golem_starter_loose_pop_plus").get("effects")
		== {"spend_block": 5, "damage": 11, "buttons_popped": 1},
		"Loose Button Pop+ raises only the damage")
	_check(catalog.get_definition("button_golem_starter_threadwheel_roll").get("effects").get("block_self") == 5
		and catalog.get_definition("button_golem_starter_threadwheel_roll_plus").get("effects").get("block_self") == 7,
		"Threadwheel Roll self Block is five then seven")
	_check(catalog.get_definition("button_golem_starter_seam_resew_plus").get("effects")
		== {"block_per_button_popped": 1, "block": 2},
		"Seam Re-Sew+ adds exactly two flat Block")
	_check(catalog.get_definition("button_golem_starter_seam_resew").get("effects")
		== {"block_per_button_popped": 1},
		"base Seam Re-Sew has no flat Block")
	for suffix: String in ["", "_plus"]:
		for base_id: String in ["button_golem_starter_button_fist",
				"button_golem_starter_loose_pop", "button_golem_starter_threadwheel_roll",
				"button_golem_starter_seam_resew"]:
			_check(catalog.get_definition(base_id + suffix).get("cost") == 1,
				base_id + " costs one energy" + suffix)


## The dedicated hero projection: each named base exactly once, never an upgrade and never a
## reward card. No shared catalog total or ordering premise; the active three-hero deck is
## checked separately against its authored membership.
func _test_starter_projection() -> void:
	var catalog := ButtonGolemStarterCards.new()
	var cases: Dictionary = _cases()
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	_check(not starter_ids.is_empty() and not deck.is_empty(),
		"starter projection is populated before counting")
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		_check(starter_ids.count(base_id) == 1, base_id + " appears once in get_starter_ids")
		_check(deck.count(base_id) == 1, base_id + " appears once in the dedicated starting deck")
		_check(not starter_ids.has(plus_id), plus_id + " is not a starter id")
		_check(not deck.has(plus_id), plus_id + " is not in the dedicated starting deck")
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
		_check(id.begins_with("button_golem_starter_"),
			id + " never collides with the independent reward pool")
	for base_id: String in cases:
		_check(all_ids.has(base_id) and all_ids.has(base_id + "_plus"),
			base_id + " base and upgrade are both discoverable")
	# An independently queued reward pool would use non-starter IDs; none may resolve here.
	for reward_id: String in ["button_golem_pop_button", "button_golem_button_fist",
			"button_golem_loose_pop", "button_golem_threadwheel_roll",
			"button_golem_seam_resew", "button_golem_reward_pop_button"]:
		_check(not catalog.has_card(reward_id), reward_id + " is not a starter card")
		_check(not starter_ids.has(reward_id), reward_id + " is not a starter id")
		_check(not deck.has(reward_id), reward_id + " is not in the dedicated starting deck")


func _test_detached_records() -> void:
	var catalog := ButtonGolemStarterCards.new()
	var sample: Dictionary = catalog.get_definition("button_golem_starter_loose_pop")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["spend_block"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["starting_copies"] = 99
	var pristine: Dictionary = catalog.get_definition("button_golem_starter_loose_pop")
	_check(pristine.get("effects") == {"spend_block": 5, "damage": 9, "buttons_popped": 1},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [1, 2], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2], "TO arrays are deeply detached")
	_check(pristine.get("id") == "button_golem_starter_loose_pop", "metadata is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")
	var upgraded: Dictionary = catalog.get_definition("button_golem_starter_threadwheel_roll_plus")
	upgraded["effects"]["block_self"] = 900
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	var upgraded_pristine: Dictionary = catalog.get_definition("button_golem_starter_threadwheel_roll_plus")
	_check(upgraded_pristine.get("effects") == {"swap_with_ally": 1, "block_self": 7},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [1, 2, 3], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [], "empty upgrade TO array is detached")
	_check(not upgraded_pristine.get("to_positions").has(900), "empty upgrade TO repopulates empty")
	var resew: Dictionary = catalog.get_definition("button_golem_starter_seam_resew_plus")
	_check(not resew.is_empty(), "flat-Block upgrade fixture loaded")
	if not resew.is_empty():
		_check(resew.get("effects") == {"block_per_button_popped": 1, "block": 2},
			"flat-Block upgrade fixture is intact before mutation")
		resew["effects"]["block"] = 900
		resew["effects"]["block_per_button_popped"] = 900
		var resew_pristine: Dictionary = catalog.get_definition("button_golem_starter_seam_resew_plus")
		_check(resew_pristine.get("effects") == {"block_per_button_popped": 1, "block": 2},
			"flat-Block upgrade effects are detached")
		_check(catalog.get_definition("button_golem_starter_seam_resew").get("effects")
			== {"block_per_button_popped": 1},
			"mutating one record leaves its base untouched")
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(starter_ids.has("button_golem_starter_button_fist")
		and deck.has("button_golem_starter_seam_resew"),
		"projections are populated before mutation")
	starter_ids.clear()
	starter_ids.append("forged_starter")
	deck.clear()
	all_ids.clear()
	_check(catalog.get_starter_ids().has("button_golem_starter_button_fist"),
		"get_starter_ids returns a fresh array")
	_check(catalog.get_starting_deck().has("button_golem_starter_seam_resew"),
		"get_starting_deck returns a fresh array")
	_check(catalog.get_all_card_ids().has("button_golem_starter_button_fist_plus"),
		"get_all_card_ids returns a fresh array")
	_check(not catalog.get_starter_ids().has("forged_starter"),
		"mutated starter id array leaks nothing")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(first_deck == second_deck and first_deck.size() == second_deck.size(),
		"two starting-deck calls agree")
	if not first_deck.is_empty():
		first_deck[0] = "mutated_first"
	_check(second_deck.count("button_golem_starter_button_fist") == 1
		and catalog.get_starting_deck().count("button_golem_starter_button_fist") == 1,
		"each base starter contributes exactly one copy")
	_check(ButtonGolemStarterCards.new().get_definition("button_golem_starter_loose_pop") == pristine,
		"a fresh instance retains the canonical definition")


func _test_invalid_and_upgraded_ids() -> void:
	var catalog := ButtonGolemStarterCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("button_golem_starter_button_fist"),
		"", "button_golem_not_a_card", "button_golem_starter_button_fist+", "forged_starter",
		"button_golem_starter_button_fist_plus_plus",
		"button_golem_starter_seam_resew_plus_plus",
		"button_fist", "starter_button_fist", "button_golem_pop_button",
		"yarn_ranger_needle_nock", "warden_strike"]
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
		_check(catalog.get_definition(catalog.get_upgrade_id(plus_id)).is_empty(),
			plus_id + " resolves no second definition")
		_check(not catalog.get_starter_ids().has(plus_id),
			plus_id + " is not proposed as a starter")
		_check(not catalog.get_starting_deck().has(plus_id),
			plus_id + " is not proposed in the dedicated deck")
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(12) == ""
		and catalog.get_upgrade_id("") == "", "get_upgrade_id fails closed")


func _test_deterministic_and_rng_free() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var before: int = rng.state
	var catalog := ButtonGolemStarterCards.new()
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
	var second := ButtonGolemStarterCards.new()
	_check(first_ids == second.get_all_card_ids(), "catalog enumeration is deterministic")
	_check(first_starters == second.get_starter_ids(), "starter enumeration is deterministic")
	_check(first_deck == second.get_starting_deck(), "starting-deck projection is deterministic")
	_check(first_ids == catalog.get_all_card_ids(), "repeated enumeration is stable")
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(catalog.get_definition("button_golem_starter_loose_pop").get("effects")
		== {"spend_block": 5, "damage": 9, "buttons_popped": 1},
		"lookups leave the catalog pristine")
	_check(rng.state == before, "a second lookup window also consumes no seeded RNG draws")


## Existing shared catalogs stay exactly as authored; the new starters stay out of the live deck.
func _test_existing_catalogs_unchanged() -> void:
	var starter := StarterCards.new()
	var golem := ButtonGolemStarterCards.new()
	var warden_strike: Dictionary = starter.get_definition("warden_strike")
	_check(not warden_strike.is_empty(), "warden_strike remains authored")
	_check(warden_strike.get("effects") == {"damage": 6}, "warden_strike stays six damage")
	_check(warden_strike.get("starting_copies") == 2, "warden_strike keeps two copies")
	var prick: Dictionary = starter.get_definition("seamstress_prick")
	_check(not prick.is_empty(), "seamstress_prick remains authored")
	_check(prick.get("effects") == {"damage": 3, "bleed": 2}, "seamstress_prick keeps bleed two")
	_check(prick.get("starting_copies") == 2, "seamstress_prick keeps two copies")
	var pop_shot: Dictionary = starter.get_definition("tinker_pop_shot")
	_check(not pop_shot.is_empty(), "tinker_pop_shot remains authored")
	_check(pop_shot.get("effects") == {"damage": 5}, "tinker_pop_shot stays five damage")
	_check(pop_shot.get("starting_copies") == 2, "tinker_pop_shot keeps two copies")
	var active_deck: Array[String] = starter.get_starting_deck()
	_check(active_deck.has("warden_strike") and active_deck.has("seamstress_prick")
		and active_deck.has("tinker_pop_shot"), "active three-hero deck keeps its representatives")
	var raw_json: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored_deck: Variant = JSON.parse_string(raw_json)
	_check(authored_deck is Array, "authored starter deck parses")
	if authored_deck is Array:
		_check(active_deck == authored_deck,
			"active three-hero starting deck still matches its authored membership and order")
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		_check(not starter.has_card(base_id) and not starter.has_card(plus_id),
			base_id + " has not entered StarterCards")
		_check(not active_deck.has(base_id) and not active_deck.has(plus_id),
			base_id + " is absent from the active starting deck")
		if authored_deck is Array:
			_check(not authored_deck.has(base_id) and not authored_deck.has(plus_id),
				base_id + " is absent from the authored starter deck")
		_check(golem.get_definition(base_id).get("reward_eligible") == false
			and golem.get_definition(plus_id).get("reward_eligible") == false,
			base_id + " pair is never reward eligible")
		_check(not golem.get_definition(base_id).has("rarity")
			and not golem.get_definition(plus_id).has("rarity"),
			base_id + " pair carries no pool rarity")
	# Nothing but the four authored bases and their upgrades is exposed by this catalog.
	for id: String in golem.get_all_card_ids():
		_check(cases.has(id) or cases.has(id.trim_suffix("_plus")),
			id + " is one of the four authored starter pairs, never a reward card")


## AC2: the four authentic printings, each authenticated through its own catalog, plus the
## pure supported-card query. Descriptor values are read back, never restated from a fixture.
func _test_pop_printings() -> void:
	var resolver := PopResolver.new()
	var support_candidates := ["button_golem_starter_loose_pop", "button_golem_starter_loose_pop_plus",
		"button_golem_pop_button", "button_golem_pop_button_plus"]
	_check(POP_PRINTINGS.size() == 4, "four distinct Pop Button printings are enumerated")
	for card_id: String in support_candidates:
		_check(POP_PRINTINGS.has(card_id) and resolver.is_supported_card(card_id),
			card_id + " is a resolver-supported Pop printing")
	for card_id: String in POP_PRINTINGS:
		var spec: Dictionary = POP_PRINTINGS[card_id]
		var damage: int = spec["damage"]
		var definition: Dictionary = _pop_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			card_id + " is authentically authored in its own catalog")
		_check(definition.get("owner") == "button_golem", card_id + " is owned by the Golem")
		_check(definition.get("cost") == 1, card_id + " costs exactly one energy")
		_check(definition.get("target_kind") == "enemy_single"
			and definition.get("from_positions") == [1, 2]
			and definition.get("to_positions") == [1, 2],
			card_id + " plays only from hero slots 1-2 against enemy slots 1-2")
		_check(definition.get("effects").get("damage") == damage,
			card_id + " prints exactly " + str(damage) + " damage")
		if spec["catalog"] == "starter":
			_check(definition.get("effects").get("spend_block") == 5
				and definition.get("effects").get("buttons_popped") == 1,
				card_id + " spends five owner Block and counts one popped button")
		else:
			_check(definition.get("effects").get("require_owner_block") == 5
				and definition.get("effects").get("spend_owner_block") == 5
				and definition.get("effects").get("buttons_popped_gain") == 1,
				card_id + " requires/spends five owner Block and gains one popped button")
	# Aliases, upgrades of upgrades, other heroes' cards and malformed values are not printings.
	for rejected in ["button_golem_starter_loose_pop_plus_plus", "button_golem_loose_pop",
			"button_golem_starter_button_fist", "button_golem_starter_seam_resew",
			"button_golem_sew_on", "warden_strike", "", "button_golem_pop_button_plus_plus"]:
		_check(not resolver.is_supported_card(rejected),
			str(rejected) + " is not a Pop Button printing")
	for malformed in [null, 0, 3.5, false, [], {}, StringName("button_golem_pop_button")]:
		_check(not resolver.is_supported_card(malformed),
			"malformed card id is not a Pop Button printing: " + str(malformed))


## AC1/AC2: one paid play per printing. Real deck, real party, real enemies; every other
## field is compared so a stray write cannot hide behind the headline numbers.
func _test_pop_paid_resolution() -> void:
	for card_id: String in POP_PRINTINGS:
		_play_pop_success(card_id, POP_PRINTINGS[card_id]["damage"])


func _play_pop_success(card_id: String, damage: int) -> void:
	var deck := _pop_deck([card_id])
	var party := _pop_party()
	_check(party.gain_block(1, 8), card_id + ": the Golem holds eight Block before payment")
	var enemies := _pop_enemies([40, 40])
	var before := _pop_snapshot(deck, party, enemies)
	var receipt := PopResolver.new().play_card(deck, party, enemies, card_id, 1)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		card_id + ": the paid play resolves")
	_check(receipt.get("damage") == damage, card_id + ": the hit is the printed " + str(damage))
	_check(receipt.get("cost") == 1 and receipt.get("block_spent") == 5,
		card_id + ": one energy and exactly five owner Block were paid")
	_check(deck.energy == before["energy"] - 1 and deck.combat_state.energy == before["state_energy"] - 1,
		card_id + ": exactly one energy left the deck state")
	_check(deck.hand.is_empty() and deck.discard_pile.size() == 1
		and deck.discard_pile[0] == card_id,
		card_id + ": exactly one held copy moved to the discard pile")
	_check(deck.draw_pile.is_empty() and deck.turn_active,
		card_id + ": no card was drawn, duplicated or the turn ended")
	var golem: Dictionary = party.get_hero(1)
	_check(golem.get("block") == 3, card_id + ": exactly five Block were removed from the Golem")
	_check(golem.get("buttons_popped") == 1,
		card_id + ": exactly one button was popped for this combat")
	_check(receipt.get("buttons_popped") == 1, card_id + ": the receipt reports that count")
	var enemy: Dictionary = enemies.get_enemy(1)
	_check(enemy.get("hp") == 40 - damage and enemy.get("block") == 0,
		card_id + ": the unblocked target lost exactly " + str(damage) + " HP")
	_check(receipt.get("block_absorbed") == 0 and receipt.get("hp_loss") == damage,
		card_id + ": ordinary Block-before-HP outcome is reported")
	var expected_golem: Dictionary = before["heroes"][0].duplicate(true)
	expected_golem["block"] = 3
	expected_golem["buttons_popped"] = 1
	_check(party.get_hero(1) == expected_golem,
		card_id + ": only Block and the popped-button count changed on the Golem")
	_check(party.get_hero(2) == before["heroes"][1] and party.get_hero(3) == before["heroes"][2],
		card_id + ": the other two heroes are untouched")
	var expected_enemy: Dictionary = before["foes"][0].duplicate(true)
	expected_enemy["hp"] = 40 - damage
	_check(enemies.get_enemy(1) == expected_enemy,
		card_id + ": the target keeps every other field")
	_check(enemies.get_enemy(2) == before["foes"][1],
		card_id + ": the unselected enemy is untouched")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		card_id + ": the paid play consumes no seeded RNG draw")


## AC2: enemy Block absorbs before HP and the Pop still counts; a second authentic paid card
## accumulates a second button on the same battle roster only.
func _test_pop_blocked_enemy_and_accumulation() -> void:
	var deck := _pop_deck(["button_golem_starter_loose_pop", "button_golem_pop_button"])
	_check(deck.hand.size() == 2, "both authentic printings are held")
	var party := _pop_party()
	_check(party.gain_block(1, 10), "the Golem holds ten Block")
	var enemies := _pop_enemies([40])
	_check(enemies.gain_block(1, 20), "the enemy holds twenty Block")
	var resolver := PopResolver.new()
	var first := resolver.play_card(deck, party, enemies, "button_golem_starter_loose_pop", 1)
	_check(first.get("ok") == true, "a fully blocked Pop still resolves")
	_check(first.get("damage") == 9 and first.get("block_absorbed") == 9
		and first.get("hp_loss") == 0,
		"enemy Block absorbs the whole first hit before HP")
	_check(enemies.get_enemy(1).get("hp") == 40 and enemies.get_enemy(1).get("block") == 11,
		"first hit leaves HP intact and reduces enemy Block by nine")
	_check(party.get_hero(1).get("block") == 5,
		"the Golem still spends exactly five of its own Block")
	_check(party.get_hero(1).get("buttons_popped") == 1,
		"a fully absorbed Pop still counts one button")
	_check(deck.energy == 2 and deck.hand.size() == 1
		and deck.discard_pile == ["button_golem_starter_loose_pop"],
		"the first copy is discarded and the second stays held")
	var second := resolver.play_card(deck, party, enemies, "button_golem_pop_button", 1)
	_check(second.get("ok") == true and second.get("damage") == 9
		and second.get("block_absorbed") == 9 and second.get("hp_loss") == 0,
		"the second authentic paid card resolves and is fully absorbed")
	_check(party.get_hero(1).get("buttons_popped") == 2,
		"a second successful Pop accumulates a second button on this combat")
	_check(party.get_hero(1).get("block") == 0,
		"the second Pop spends the remaining five Block")
	_check(deck.energy == 1 and deck.hand.is_empty() and deck.discard_pile.size() == 2,
		"the second copy is discarded as well")
	_check(enemies.get_enemy(1).get("hp") == 40 and enemies.get_enemy(1).get("block") == 2,
		"two absorbed pops never reach enemy HP")
	var fresh := _pop_party()
	_check(not fresh.get_hero(1).has("buttons_popped"),
		"a fresh CombatParty inherits no popped-button count")
	_check(fresh.get_hero(1).get("block") == 0, "a fresh CombatParty starts with no Block")
	_check(party.start_player_turn() and party.get_hero(1).get("buttons_popped") == 2,
		"the per-combat count survives the next turn boundary")
	# An explicitly stored zero is the same as an absent counter.
	var zeroed := CombatParty.new([
		{"id": "button_golem", "max_hp": 44, "buttons_popped": 0},
		{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26}])
	_check(zeroed.is_valid() and zeroed.get_hero(1).get("buttons_popped") == 0
		and zeroed.gain_block(1, 5), "explicit-zero fixture stores zero and holds five Block")
	var zero_receipt := resolver.play_card(_pop_deck(["button_golem_pop_button"]), zeroed,
		_pop_enemies([40]), "button_golem_pop_button", 1)
	_check(zero_receipt.get("ok") == true and zeroed.get_hero(1).get("buttons_popped") == 1,
		"an absent or explicit-zero counter is incremented to exactly one")


## AC1/AC3: one real Weak/Exposed/Tangled case per shared-arithmetic shape. The expected
## numbers are both literal and the shared CombatStatuses result, so neither is copied.
func _test_pop_status_adjusted_hit() -> void:
	var rules := CombatStatuses.new()
	var cases := [
		{"card": "button_golem_starter_loose_pop", "weak": 1, "exposed": 0,
			"tangled": 0, "damage": 6},
		{"card": "button_golem_pop_button_plus", "weak": 0, "exposed": 2,
			"tangled": 0, "damage": 18},
		{"card": "button_golem_starter_loose_pop_plus", "weak": 0, "exposed": 0,
			"tangled": 1, "damage": 13},
		{"card": "button_golem_pop_button_plus", "weak": 1, "exposed": 1,
			"tangled": 0, "damage": 13},
	]
	for entry: Dictionary in cases:
		var card_id: String = entry["card"]
		var printed: int = POP_PRINTINGS[card_id]["damage"]
		var attacker_statuses: Dictionary = {}
		if entry["weak"] > 0:
			attacker_statuses["weak"] = entry["weak"]
		var defender_statuses: Dictionary = {}
		if entry["exposed"] > 0:
			defender_statuses["exposed"] = entry["exposed"]
		if entry["tangled"] > 0:
			defender_statuses["tangled"] = entry["tangled"]
		var label := "%s with %s vs %s" % [card_id, str(attacker_statuses),
			str(defender_statuses)]
		var expected: int = rules.adjusted_attack_damage(
			printed, attacker_statuses, defender_statuses)
		_check(expected == entry["damage"],
			label + ": shared CombatStatuses arithmetic gives " + str(entry["damage"]))
		var deck := _pop_deck([card_id])
		var party := _pop_party()
		_check(party.gain_block(1, 5), label + ": the Golem holds exactly five Block")
		party._heroes[0]["statuses"] = attacker_statuses
		var enemies := _pop_enemies_with_statuses(defender_statuses)
		_check(enemies.get_enemy(1).get("statuses", {}) == defender_statuses,
			label + ": the authoritative enemy carries those statuses")
		var receipt := PopResolver.new().play_card(deck, party, enemies, card_id, 1)
		_check(receipt.get("ok") == true, label + ": paid play resolves")
		_check(receipt.get("damage") == expected and receipt.get("hp_loss") == expected,
			label + ": status-adjusted damage reaches HP")
		_check(enemies.get_enemy(1).get("hp") == 60 - expected,
			label + ": enemy HP follows the adjusted attack")
		_check(party.get_hero(1).get("buttons_popped") == 1,
			label + ": a status-adjusted Pop counts one button")


## AC3: every malformed or unpayable request refuses with a complete before/after snapshot.
func _test_pop_refusals() -> void:
	_expect_pop_refusal("non-Pop starter card held",
		_pop_deck(["warden_strike"]), _pop_party_with_block(), _pop_enemies([30, 30]),
		"warden_strike", 1, "unsupported_card")
	_expect_pop_refusal("other Button Golem card held",
		_pop_deck(["button_golem_starter_button_fist"]), _pop_party_with_block(),
		_pop_enemies([30, 30]), "button_golem_starter_button_fist", 1, "unsupported_card")
	_expect_pop_refusal("supported printing not in hand",
		_pop_deck(["button_golem_starter_loose_pop"]), _pop_party_with_block(),
		_pop_enemies([30, 30]), "button_golem_pop_button", 1, "card_not_held")
	var inactive := _pop_inactive_deck("button_golem_starter_loose_pop")
	_expect_pop_refusal("inactive turn", inactive, _pop_party_with_block(),
		_pop_enemies([30, 30]), "button_golem_starter_loose_pop", 1, "inactive_turn")
	var broke := _pop_deck(["button_golem_starter_loose_pop"])
	_check(broke.try_spend_energy(3) and broke.energy == 0 and broke.hand.size() == 1,
		"energy-short fixture is genuinely broke and still holds the card")
	_expect_pop_refusal("insufficient energy", broke, _pop_party_with_block(),
		_pop_enemies([30, 30]), "button_golem_starter_loose_pop", 1, "insufficient_energy")
	_expect_pop_refusal("only four owner Block",
		_pop_deck(["button_golem_starter_loose_pop"]), _pop_party_with_block(4),
		_pop_enemies([30, 30]), "button_golem_starter_loose_pop", 1, "insufficient_block")
	var torn := _pop_party_with_block()
	_check(torn.apply_damage(1, 400) and torn.is_downed(1),
		"torn-owner fixture has a genuinely downed Golem")
	_expect_pop_refusal("torn Golem", _pop_deck(["button_golem_starter_loose_pop"]), torn,
		_pop_enemies([30, 30]), "button_golem_starter_loose_pop", 1, "owner_torn")
	var back := _pop_party(["warden", "tinker", "button_golem"])
	_check(back.gain_block(3, 8) and back.get_hero(3).get("id") == "button_golem"
		and not back.is_downed(3), "back-slot fixture has a living Golem in slot 3")
	_expect_pop_refusal("Golem in the back slot",
		_pop_deck(["button_golem_starter_loose_pop"]), back, _pop_enemies([30, 30]),
		"button_golem_starter_loose_pop", 1, "invalid_owner_position")
	_expect_pop_refusal("no Button Golem in the party",
		_pop_deck(["button_golem_starter_loose_pop"]), _pop_party(["warden", "seamstress", "tinker"]),
		_pop_enemies([30, 30]), "button_golem_starter_loose_pop", 1, "owner_missing")
	for bad_target in [0, 3, -1, 99]:
		_expect_pop_refusal("target outside hero-selected enemy slots: " + str(bad_target),
			_pop_deck(["button_golem_starter_loose_pop"]), _pop_party_with_block(),
			_pop_enemies([30, 30, 30]), "button_golem_starter_loose_pop", bad_target,
			"invalid_target")
	var slain := _pop_enemies([30, 30])
	_check(slain.apply_damage(1, 400) and slain.is_slain(1),
		"dead-target fixture has a genuinely slain front enemy")
	_expect_pop_refusal("dead selected enemy",
		_pop_deck(["button_golem_starter_loose_pop"]), _pop_party_with_block(), slain,
		"button_golem_starter_loose_pop", 1, "invalid_target")
	var malformed_owner := _pop_party_with_block()
	malformed_owner._heroes[0]["statuses"] = {"weak": "1"}
	_check(malformed_owner.get_hero(1)["statuses"] == {"weak": "1"},
		"malformed-owner fixture really stores a string counter")
	_expect_pop_refusal("malformed owner status map",
		_pop_deck(["button_golem_starter_loose_pop"]), malformed_owner, _pop_enemies([30, 30]),
		"button_golem_starter_loose_pop", 1, "malformed_statuses")
	var malformed_enemy := _pop_enemies([30, 30])
	malformed_enemy._enemies[0]["statuses"] = {"tangled": 1.5}
	_check(malformed_enemy.get_enemy(1)["statuses"] == {"tangled": 1.5},
		"malformed-enemy fixture really stores a fractional counter")
	_expect_pop_refusal("malformed enemy status map",
		_pop_deck(["button_golem_starter_loose_pop"]), _pop_party_with_block(),
		malformed_enemy, "button_golem_starter_loose_pop", 1, "malformed_statuses")
	var malformed_count := _pop_party_with_block()
	malformed_count._heroes[0]["buttons_popped"] = "3"
	_expect_pop_refusal("malformed popped-button count",
		_pop_deck(["button_golem_starter_loose_pop"]), malformed_count, _pop_enemies([30, 30]),
		"button_golem_starter_loose_pop", 1, "malformed_button_count")
	_expect_pop_refusal("invalid party", _pop_deck(["button_golem_starter_loose_pop"]),
		CombatParty.new([]), _pop_enemies([30, 30]), "button_golem_starter_loose_pop", 1,
		"invalid_roster")
	_expect_pop_refusal("missing deck", null, _pop_party_with_block(),
		_pop_enemies([30, 30]), "button_golem_starter_loose_pop", 1, "invalid_request")


func _expect_pop_refusal(label: String, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: String, target_position: int,
		reason: String) -> void:
	var before := _pop_snapshot(deck, party, enemies)
	var receipt := PopResolver.new().play_card(deck, party, enemies, card_id, target_position)
	_check(receipt.get("ok") == false, label + ": refused")
	_check(receipt.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(receipt.get("reason")) + ")")
	_check(receipt.get("buttons_popped") == 0 and receipt.get("block_spent") == 0,
		label + ": refusal reports no payment and no button")
	_check(_pop_snapshot(deck, party, enemies) == before,
		label + ": hand, piles, energy, party, enemies and seeded RNG are unchanged")


## AC3: the same seeded sequence replays byte-for-byte, including the per-combat count.
func _test_pop_replay() -> void:
	var first := _pop_scenario(2901793)
	var second := _pop_scenario(2901793)
	_check(first == second, "identical seeds replay the entire paid sequence exactly")
	for receipt: Dictionary in first["receipts"]:
		_check(receipt.get("ok") == true, "replay receipt resolved")
	_check(first["heroes"][0].get("buttons_popped") == 3,
		"replay pops exactly three buttons on one battle roster")
	_check(first["foes"][0].get("hp") == 20 and first["foes"][1].get("hp") == 31,
		"replay applies each adjusted hit to its selected enemy")
	_check(first["energy"] == 0 and first["hand"].is_empty() and first["discard"].size() == 3,
		"replay spends three energy and discards three copies")


func _pop_scenario(seed_value: int) -> Dictionary:
	var deck := _pop_deck(["button_golem_starter_loose_pop", "button_golem_pop_button",
		"button_golem_starter_loose_pop_plus"], seed_value)
	var party := _pop_party()
	_check(party.gain_block(1, 10), "replay fixture grants ten Block")
	var enemies := _pop_enemies([40, 40])
	var resolver := PopResolver.new()
	var receipts: Array = []
	receipts.append(resolver.play_card(deck, party, enemies, "button_golem_starter_loose_pop", 1))
	receipts.append(resolver.play_card(deck, party, enemies, "button_golem_pop_button", 2))
	_check(party.gain_block(1, 5), "replay fixture re-grants five Block")
	receipts.append(resolver.play_card(deck, party, enemies,
		"button_golem_starter_loose_pop_plus", 1))
	var snapshot := _pop_snapshot(deck, party, enemies)
	snapshot["receipts"] = receipts
	return snapshot


func _pop_definition(card_id: String) -> Dictionary:
	var spec: Dictionary = POP_PRINTINGS.get(card_id, {})
	if spec.is_empty():
		return {}
	if spec["catalog"] == "starter":
		return ButtonGolemStarterCards.new().get_definition(card_id)
	return ButtonGolemRewardCards.new().get_definition(card_id)


func _pop_party(order: Array = ["button_golem", "warden", "tinker"]) -> CombatParty:
	var hp := {"button_golem": 44, "warden": 40, "seamstress": 30, "tinker": 26}
	var definitions: Array = []
	for hero_id: String in order:
		definitions.append({"id": hero_id, "max_hp": hp[hero_id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"fixture has three distinct living heroes")
	return party


func _pop_party_with_block(block: int = 8) -> CombatParty:
	var party := _pop_party()
	_check(party.gain_block(1, block),
		"fixture Golem holds " + str(block) + " Block")
	return party


func _pop_enemies(hps: Array[int] = [40, 40]) -> CombatEnemies:
	var definitions: Array = []
	for index in hps.size():
		definitions.append({"id": "foe_%d" % (index + 1), "max_hp": hps[index]})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"fixture has a valid enemy roster")
	return enemies


## One real enemy carrying authored status data from construction, for adjusted-hit cases.
func _pop_enemies_with_statuses(statuses: Dictionary) -> CombatEnemies:
	var definition := {"id": "foe_1", "max_hp": 60}
	if not statuses.is_empty():
		definition["statuses"] = statuses.duplicate(true)
	var enemies := CombatEnemies.new([definition])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 1,
		"fixture has one valid status-carrying enemy")
	return enemies


func _pop_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real seeded CombatDeck that starts the shared three-energy turn with the named cards held.
func _pop_deck(ids: Array, seed_value: int = 2901793) -> CombatDeck:
	var cards: Array[String] = []
	for id: Variant in ids:
		_check(_authored_card(id), str(id) + " is an authentic authored card")
		cards.append(str(id))
	var deck := CombatDeck.new(cards, _pop_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == mini(cards.size(), CombatDeck.TURN_DRAW),
		"seeded real CombatDeck starts a three-energy turn")
	return deck


func _pop_inactive_deck(card_id: String) -> CombatDeck:
	var deck := CombatDeck.new([card_id], _pop_rng(2901793))
	_check(not deck.turn_active and deck.energy == 0 and deck.hand.is_empty()
		and deck.draw_pile.size() == 1,
		"inactive-turn fixture really has not started its turn")
	return deck


func _authored_card(card_id: Variant) -> bool:
	return PopResolver.new().is_supported_card(card_id) \
		or StarterCards.new().has_card(card_id) \
		or ButtonGolemStarterCards.new().has_card(card_id) \
		or ButtonGolemRewardCards.new().has_card(card_id)


## Detached before/after state for refusals: hand, piles, energy, turn, seeded RNG and both rosters.
func _pop_snapshot(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies) -> Dictionary:
	var snapshot: Dictionary = {}
	if deck != null:
		snapshot["draw"] = deck.draw_pile.duplicate(true)
		snapshot["hand"] = deck.hand.duplicate(true)
		snapshot["discard"] = deck.discard_pile.duplicate(true)
		snapshot["turn"] = deck.turn_active
		snapshot["energy"] = deck.energy
		if deck.combat_state != null:
			snapshot["state_turn"] = deck.combat_state.player_turn_active
			snapshot["state_energy"] = deck.combat_state.energy
		if deck._rng != null:
			snapshot["rng_state"] = deck._rng.state
			snapshot["rng_seed"] = deck._rng.seed
	if party != null:
		snapshot["party_valid"] = party.is_valid()
		snapshot["heroes"] = party.get_heroes()
	if enemies != null:
		snapshot["foes"] = enemies.get_enemies()
		snapshot["victory"] = enemies.is_victorious()
	return snapshot
