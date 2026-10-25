extends SceneTree
## V3-1 Button Golem starter-card catalog contract.
## Catalog data only: no live party, reward, hand, deck or combat behavior is assumed or claimed here.
## The 5-Block Pop precondition, popped-button counter, ally swap and per-button Block are printed
## descriptors until a later wiring task.

const ButtonGolemStarterCards = preload("res://data/cards/button_golem_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")

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
