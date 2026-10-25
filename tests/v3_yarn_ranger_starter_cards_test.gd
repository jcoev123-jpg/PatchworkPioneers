extends SceneTree
## V3-1 Yarn Ranger starter-card catalog contract.
## Catalog data only: no live party, reward, hand or combat behavior is assumed or claimed here.

const YarnRangerStarterCards = preload("res://data/cards/yarn_ranger_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const YarnRangerPoolCards = preload("res://data/cards/yarn_ranger_pool_cards.gd")

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
		print("v3_yarn_ranger_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_yarn_ranger_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Literal, independent expectations for each of the four authored base/"+" pairs.
func _cases() -> Dictionary:
	return {
		"yarn_ranger_needle_nock": {
			"name": "Needle Nock", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 4, "unravel": 1},
			"plus_cost": 1, "plus_effects": {"damage": 6, "unravel": 2}},
		"yarn_ranger_wool_bolas": {
			"name": "Wool Bolas", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 2, "tangled": 1},
			"plus_cost": 1, "plus_effects": {"damage": 3, "tangled": 2}},
		"yarn_ranger_reel_thread": {
			"name": "Reel Thread", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [2, 3],
			"effects": {"pull_forward": 1},
			"plus_cost": 0, "plus_effects": {"pull_forward": 1}},
		"yarn_ranger_hood_knit": {
			"name": "Hood Knit", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 4, "draw": 1},
			"plus_cost": 1, "plus_effects": {"block": 6, "draw": 1}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "yarn_ranger",
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
	var catalog := YarnRangerStarterCards.new()
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(catalog.has_card(base_id), base_id + " is authored")
		_check(catalog.has_card(plus_id), plus_id + " is authored")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + "_plus is not authored")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
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


## The printed look descriptors: Tangled, pull-forward, Unravel and Block + draw.
## Presence and exact magnitudes only; nothing here claims live combat resolution.
func _test_look_descriptors() -> void:
	var catalog := YarnRangerStarterCards.new()
	for suffix: String in ["", "_plus"]:
		var nock: Dictionary = catalog.get_definition("yarn_ranger_needle_nock" + suffix)
		_check(nock.get("effects").has("unravel"), "Needle Nock prints unravel" + suffix)
		_check(nock.get("target_kind") == "enemy_single", "Needle Nock targets one enemy" + suffix)
		var bolas: Dictionary = catalog.get_definition("yarn_ranger_wool_bolas" + suffix)
		_check(bolas.get("effects").has("tangled"), "Wool Bolas prints tangled" + suffix)
		_check(not bolas.get("effects").has("slow"), "Wool Bolas invents no slow keyword" + suffix)
		var reel: Dictionary = catalog.get_definition("yarn_ranger_reel_thread" + suffix)
		_check(reel.get("effects") == {"pull_forward": 1},
			"Reel Thread prints only pull_forward one" + suffix)
		_check(reel.get("to_positions") == [2, 3],
			"Reel Thread only offers an enemy in slot two or three" + suffix)
		_check(not reel.get("effects").has("tangled"),
			"Reel Thread is not mixed with tangled" + suffix)
		var hood: Dictionary = catalog.get_definition("yarn_ranger_hood_knit" + suffix)
		_check(hood.get("target_kind") == "ally_single" and hood.get("to_positions") == [],
			"Hood Knit shields one living ally" + suffix)
		_check(hood.get("effects").has("block") and hood.get("effects").has("draw"),
			"Hood Knit prints block plus a shared-hand draw" + suffix)
	_check(catalog.get_definition("yarn_ranger_reel_thread_plus").get("cost") == 0,
		"Reel Thread+ is free")
	_check(catalog.get_definition("yarn_ranger_needle_nock").get("effects").get("unravel") == 1
		and catalog.get_definition("yarn_ranger_needle_nock_plus").get("effects").get("unravel") == 2,
		"Needle Nock Unravel is one then two")
	_check(catalog.get_definition("yarn_ranger_wool_bolas").get("effects").get("tangled") == 1
		and catalog.get_definition("yarn_ranger_wool_bolas_plus").get("effects").get("tangled") == 2,
		"Wool Bolas Tangled is one then two")


## The dedicated hero projection: each named base exactly once, never an upgrade.
## No global catalog size or ordering premise; the active three-hero deck is checked separately.
func _test_starter_projection() -> void:
	var catalog := YarnRangerStarterCards.new()
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
	for base_id: String in cases:
		_check(all_ids.has(base_id) and all_ids.has(base_id + "_plus"),
			base_id + " base and upgrade are both discoverable")


func _test_detached_records() -> void:
	var catalog := YarnRangerStarterCards.new()
	var sample: Dictionary = catalog.get_definition("yarn_ranger_needle_nock")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["unravel"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["starting_copies"] = 99
	var pristine: Dictionary = catalog.get_definition("yarn_ranger_needle_nock")
	_check(pristine.get("effects") == {"damage": 4, "unravel": 1},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [2, 3], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2, 3], "TO arrays are deeply detached")
	_check(pristine.get("id") == "yarn_ranger_needle_nock", "metadata is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")
	var upgraded: Dictionary = catalog.get_definition("yarn_ranger_hood_knit_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	var upgraded_pristine: Dictionary = catalog.get_definition("yarn_ranger_hood_knit_plus")
	_check(upgraded_pristine.get("effects") == {"block": 6, "draw": 1},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [1, 2, 3], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [], "empty upgrade TO array is detached")
	_check(not upgraded_pristine.get("to_positions").has(900), "empty upgrade TO repopulates empty")
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(starter_ids.has("yarn_ranger_wool_bolas") and deck.has("yarn_ranger_hood_knit"),
		"projections are populated before mutation")
	starter_ids.clear()
	starter_ids.append("forged_starter")
	deck.clear()
	all_ids.clear()
	_check(catalog.get_starter_ids().has("yarn_ranger_wool_bolas"),
		"get_starter_ids returns a fresh array")
	_check(catalog.get_starting_deck().has("yarn_ranger_hood_knit"),
		"get_starting_deck returns a fresh array")
	_check(catalog.get_all_card_ids().has("yarn_ranger_needle_nock_plus"),
		"get_all_card_ids returns a fresh array")
	_check(not catalog.get_starter_ids().has("forged_starter"),
		"mutated starter id array leaks nothing")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(first_deck == second_deck and first_deck.size() == second_deck.size(),
		"two starting-deck calls agree")
	if not first_deck.is_empty():
		first_deck[0] = "mutated_first"
	_check(second_deck.count("yarn_ranger_needle_nock") == 1
		and catalog.get_starting_deck().count("yarn_ranger_needle_nock") == 1,
		"each base starter contributes exactly one copy")
	_check(YarnRangerStarterCards.new().get_definition("yarn_ranger_needle_nock") == pristine,
		"a fresh instance retains the canonical definition")


func _test_invalid_and_upgraded_ids() -> void:
	var catalog := YarnRangerStarterCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("yarn_ranger_needle_nock"),
		"", "yarn_ranger_not_a_card", "yarn_ranger_needle_nock+", "forged_starter",
		"yarn_ranger_needle_nock_plus_plus", "yarn_ranger_hood_knit_plus_plus",
		"yarn_ranger_needle_arrow"]
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
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(12) == ""
		and catalog.get_upgrade_id("") == "", "get_upgrade_id fails closed")


func _test_deterministic_and_rng_free() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var before: int = rng.state
	var catalog := YarnRangerStarterCards.new()
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
	var second := YarnRangerStarterCards.new()
	_check(first_ids == second.get_all_card_ids(), "catalog enumeration is deterministic")
	_check(first_starters == second.get_starter_ids(), "starter enumeration is deterministic")
	_check(first_deck == second.get_starting_deck(), "starting-deck projection is deterministic")
	_check(first_ids == catalog.get_all_card_ids(), "repeated enumeration is stable")
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(catalog.get_definition("yarn_ranger_needle_nock").get("effects")
		== {"damage": 4, "unravel": 1}, "lookups leave the catalog pristine")
	_check(rng.state == before, "a second lookup window also consumes no seeded RNG draws")


## Existing shared catalogs stay exactly as authored; the new starters stay out of rewards.
func _test_existing_catalogs_unchanged() -> void:
	var starter := StarterCards.new()
	var pool := YarnRangerPoolCards.new()
	var yard := YarnRangerStarterCards.new()
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
	var needle_arrow: Dictionary = pool.get_definition("yarn_ranger_needle_arrow")
	_check(not needle_arrow.is_empty(), "Yarn Ranger reward needle_arrow remains authored")
	_check(needle_arrow.get("effects") == {"damage": 5, "unravel": 1},
		"needle_arrow stays five damage with unravel one")
	_check(needle_arrow.get("starting_copies") == 0, "needle_arrow still adds no starting copy")
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
		_check(not pool.has_card(base_id) and not pool.has_card(plus_id),
			base_id + " has not entered the Yarn Ranger reward pool")
		_check(yard.get_definition(base_id).get("reward_eligible") == false
			and yard.get_definition(plus_id).get("reward_eligible") == false,
			base_id + " pair is never reward eligible")
		_check(not yard.get_definition(base_id).has("rarity")
			and not yard.get_definition(plus_id).has("rarity"),
			base_id + " pair carries no pool rarity")
	# The dedicated catalog never exposes the existing reward cards as starters.
	for pool_id: String in pool.get_all_card_ids():
		_check(not yard.has_card(pool_id), pool_id + " is not a Yarn Ranger starter")
		_check(not yard.get_starter_ids().has(pool_id),
			pool_id + " is not in the dedicated starter projection")
