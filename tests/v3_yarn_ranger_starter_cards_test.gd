extends SceneTree
## V3-1 Yarn Ranger starter-card contract and paid needle-shot service.
## The catalog fixtures below stay data-only; the service-level cases drive real seeded
## CombatDeck/CombatParty/CombatEnemies/CombatUnravel objects to prove the four needle
## printings really damage one target and charge that foe's Unravel gauge. The Purling Barrage
## cases prove the same class resolves its two authentic reward printings as two independent
## paid hits and one post-hit Unravel charge. No live app hand or reward registration is claimed
## here: dispatching a real held card is a separate task.

const YarnRangerStarterCards = preload("res://data/cards/yarn_ranger_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const YarnRangerPoolCards = preload("res://data/cards/yarn_ranger_pool_cards.gd")
const CombatYarnRangerNeedleCards = preload("res://scripts/combat_yarn_ranger_needle_cards.gd")
const CombatDeck = preload("res://scripts/combat_deck.gd")
const CombatParty = preload("res://scripts/combat_party.gd")
const CombatEnemies = preload("res://scripts/combat_enemies.gd")
const CombatUnravel = preload("res://scripts/combat_unravel.gd")

const NEEDLE_NOCK := "yarn_ranger_needle_nock"
const NEEDLE_NOCK_PLUS := "yarn_ranger_needle_nock_plus"
const NEEDLE_ARROW := "yarn_ranger_needle_arrow"
const NEEDLE_ARROW_PLUS := "yarn_ranger_needle_arrow_plus"
const NEEDLE_IDS := [NEEDLE_NOCK, NEEDLE_NOCK_PLUS, NEEDLE_ARROW, NEEDLE_ARROW_PLUS]
const PURLING := "yarn_ranger_purling_barrage"
const PURLING_PLUS := "yarn_ranger_purling_barrage_plus"
const PURLING_IDS := [PURLING, PURLING_PLUS]

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
	_test_needle_catalog_contract()
	_test_needle_paid_play()
	_test_needle_block_and_lethal()
	_test_needle_threshold_and_skip()
	_test_needle_refusals()
	_test_purling_catalog_contract()
	_test_purling_paid_play()
	_test_purling_two_hits_and_lethal()
	_test_purling_unravel_threshold()
	_test_purling_refusals()
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


## AC1: the four authentic needle printings keep their exact authored line in the catalog that
## owns them, resolve to that exact record, and refuse every other ID or tampered definition.
func _test_needle_catalog_contract() -> void:
	var starter := YarnRangerStarterCards.new()
	var pool := YarnRangerPoolCards.new()
	var resolver := CombatYarnRangerNeedleCards.new()
	var expected := {
		NEEDLE_NOCK: {"catalog": "starter", "name": "Needle Nock", "damage": 4, "unravel": 1,
			"copies": 1, "reward": false},
		NEEDLE_NOCK_PLUS: {"catalog": "starter", "name": "Needle Nock+", "damage": 6,
			"unravel": 2, "copies": 0, "reward": false},
		NEEDLE_ARROW: {"catalog": "pool", "name": "Needle Arrow", "damage": 5, "unravel": 1,
			"copies": 0, "reward": true},
		NEEDLE_ARROW_PLUS: {"catalog": "pool", "name": "Needle Arrow+", "damage": 7,
			"unravel": 2, "copies": 0, "reward": false},
	}
	for card_id: String in NEEDLE_IDS:
		var spec: Dictionary = expected[card_id]
		var own_catalog: Dictionary = starter.get_definition(card_id) \
			if spec["catalog"] == "starter" else pool.get_definition(card_id)
		var other_catalog: Dictionary = pool.get_definition(card_id) \
			if spec["catalog"] == "starter" else starter.get_definition(card_id)
		_check(not own_catalog.is_empty(), card_id + " is authored by its own Yarn catalog")
		_check(other_catalog.is_empty(), card_id + " is not duplicated in the other Yarn catalog")
		_check(own_catalog.get("id") == card_id, card_id + " keeps its exact identifier")
		_check(own_catalog.get("display_name") == spec["name"], card_id + " keeps its printed name")
		_check(own_catalog.get("owner") == "yarn_ranger", card_id + " is owned by the Yarn Ranger")
		_check(own_catalog.get("cost") == 1, card_id + " prints one energy")
		_check(own_catalog.get("from_positions") == [2, 3], card_id + " prints FROM seats 2-3")
		_check(own_catalog.get("target_kind") == "enemy_single",
			card_id + " prints a single-enemy target")
		_check(own_catalog.get("to_positions") == [1, 2, 3], card_id + " prints TO slots 1-3")
		var effects: Dictionary = own_catalog.get("effects", {})
		_check(effects == {"damage": spec["damage"], "unravel": spec["unravel"]},
			card_id + " prints exactly " + str(spec["damage"]) + " damage and Unravel "
			+ str(spec["unravel"]))
		_check(effects.size() == 2, card_id + " carries no extra effect key")
		_check(typeof(effects.get("damage")) == TYPE_INT
			and typeof(effects.get("unravel")) == TYPE_INT,
			card_id + " prints integer damage and Unravel values")
		_check(own_catalog.get("starting_copies") == spec["copies"],
			card_id + " keeps its authored starting-copy count")
		_check(own_catalog.get("reward_eligible") == spec["reward"],
			card_id + " keeps its authored reward eligibility")
		if spec["catalog"] == "pool":
			_check(own_catalog.get("rarity") == "common", card_id + " stays a common reward")
		else:
			_check(not own_catalog.has("rarity"), card_id + " carries no pool rarity")
		if card_id.ends_with("_plus"):
			_check(own_catalog.get("upgrade_of") == card_id.trim_suffix("_plus")
				and not own_catalog.has("upgrade_id"),
				card_id + " links back to its one base printing")
		else:
			_check(own_catalog.get("upgrade_id") == card_id + "_plus"
				and not own_catalog.has("upgrade_of"),
				card_id + " links forward to its one upgrade")
		_check(resolver.is_supported_card(card_id), card_id + " is a supported needle card")
		_check(CombatYarnRangerNeedleCards.is_authentic_definition(own_catalog, card_id),
			card_id + " passes the definition authenticator")
		_check(CombatYarnRangerNeedleCards.needle_definition(card_id) == own_catalog,
			card_id + " resolves to its exact detached catalog record")

	# The resolver accepts exactly these four authored IDs; a stray key cannot sneak in.
	for card_id: Variant in CombatYarnRangerNeedleCards.CARDS:
		_check(NEEDLE_IDS.has(card_id), str(card_id) + " is one of the four authored needle IDs")
	for card_id: String in NEEDLE_IDS:
		_check(CombatYarnRangerNeedleCards.CARDS.has(card_id),
			card_id + " is present in the resolver's authored table")

	# Detached: mutating a resolved record cannot rewrite what the next resolution returns.
	var sample := CombatYarnRangerNeedleCards.needle_definition(NEEDLE_NOCK)
	_check(not sample.is_empty(), "needle resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["damage"] = 900
		sample["effects"]["unravel"] = 900
		sample["from_positions"].clear()
		sample["cost"] = 0
		sample["display_name"] = "Forged Nock"
		_check(CombatYarnRangerNeedleCards.needle_definition(NEEDLE_NOCK)
			== starter.get_definition(NEEDLE_NOCK),
			"a mutated needle definition cannot poison later resolutions")

	# Every other Yarn starter/pool card is unrelated, never a needle shot.
	var unrelated: Array = []
	unrelated.append_array(starter.get_all_card_ids())
	unrelated.append_array(pool.get_all_card_ids())
	for card_id: String in NEEDLE_IDS:
		unrelated.erase(card_id)
	_check(not unrelated.is_empty(), "unrelated Yarn cards exist to be refused")
	for other_id: Variant in unrelated:
		_check(CombatYarnRangerNeedleCards.needle_definition(other_id).is_empty(),
			str(other_id) + " does not resolve as a needle card")
		_check(not resolver.is_supported_card(other_id),
			str(other_id) + " is not a supported needle card")
	var forged: Array = ["yarn_ranger_needle_nock+", "yarn_ranger_needle_nock_plus_plus",
		"yarn_ranger_needle_arrow_+", "yarn_ranger_needle_arrow_plus_plus",
		"needle_nock", "needle_arrow", " yarn_ranger_needle_nock",
		"yarn_ranger_needle_nock ", "NEEDLE_NOCK", "", "warden_strike",
		StringName(NEEDLE_NOCK), null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatYarnRangerNeedleCards.needle_definition(other_id).is_empty(),
			"forged or non-string ID never resolves as a needle shot: " + str(other_id))
		_check(not CombatYarnRangerNeedleCards.is_authentic_definition(
			starter.get_definition(NEEDLE_NOCK), other_id),
			"a needle record cannot authenticate under a forged ID: " + str(other_id))

	# Adversarial copies of a real starter record: every altered contract field is refused.
	var nock_record: Dictionary = starter.get_definition(NEEDLE_NOCK)
	_check(not nock_record.is_empty()
		and CombatYarnRangerNeedleCards.is_authentic_definition(nock_record, NEEDLE_NOCK),
		"authenticator positive fixture really is the authored Needle Nock")
	var nock_mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["damage"] = 5,
		func(record: Dictionary) -> void: record["effects"]["damage"] = 4.0,
		func(record: Dictionary) -> void: record["effects"]["damage"] = "4",
		func(record: Dictionary) -> void: record["effects"]["unravel"] = 2,
		func(record: Dictionary) -> void: record["effects"]["unravel"] = 1.0,
		func(record: Dictionary) -> void: record["effects"]["unravel"] = true,
		func(record: Dictionary) -> void: record["effects"].erase("unravel"),
		func(record: Dictionary) -> void: record["effects"]["tangled"] = 1,
		func(record: Dictionary) -> void: record["effects"] = "damage",
		func(record: Dictionary) -> void: record["cost"] = 0,
		func(record: Dictionary) -> void: record["cost"] = 2,
		func(record: Dictionary) -> void: record["cost"] = 1.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["display_name"] = "Needle Nock+",
		func(record: Dictionary) -> void: record["from_positions"] = [1, 2, 3],
		func(record: Dictionary) -> void: record["from_positions"] = ["2", "3"],
		func(record: Dictionary) -> void: record["from_positions"] = "2,3",
		func(record: Dictionary) -> void: record["to_positions"] = [1, 2],
		func(record: Dictionary) -> void: record["target_kind"] = "enemy_all",
		func(record: Dictionary) -> void: record["id"] = NEEDLE_ARROW,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record["upgrade_of"] = NEEDLE_NOCK,
		func(record: Dictionary) -> void: record["starting_copies"] = 2,
		func(record: Dictionary) -> void: record["reward_eligible"] = true,
		func(record: Dictionary) -> void: record["rarity"] = "common",
		func(record: Dictionary) -> void: record.erase("effects"),
		func(record: Dictionary) -> void: record.erase("display_name"),
	]
	for index in range(nock_mutations.size()):
		var tampered: Dictionary = nock_record.duplicate(true)
		nock_mutations[index].call(tampered)
		_check(not CombatYarnRangerNeedleCards.is_authentic_definition(tampered, NEEDLE_NOCK),
			"tampered Needle Nock record " + str(index) + " is refused")

	# The pool reward printing is tampered the same way, including its rarity/eligibility line.
	var arrow_record: Dictionary = pool.get_definition(NEEDLE_ARROW)
	_check(not arrow_record.is_empty()
		and CombatYarnRangerNeedleCards.is_authentic_definition(arrow_record, NEEDLE_ARROW),
		"authenticator positive fixture really is the authored Needle Arrow")
	var arrow_mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["damage"] = 7,
		func(record: Dictionary) -> void: record["effects"]["unravel"] = 2,
		func(record: Dictionary) -> void: record["rarity"] = "uncommon",
		func(record: Dictionary) -> void: record["rarity"] = "rare",
		func(record: Dictionary) -> void: record.erase("rarity"),
		func(record: Dictionary) -> void: record["reward_eligible"] = false,
		func(record: Dictionary) -> void: record["starting_copies"] = 1,
		func(record: Dictionary) -> void: record["upgrade_of"] = NEEDLE_ARROW,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
	]
	for index in range(arrow_mutations.size()):
		var tampered_arrow: Dictionary = arrow_record.duplicate(true)
		arrow_mutations[index].call(tampered_arrow)
		_check(not CombatYarnRangerNeedleCards.is_authentic_definition(
			tampered_arrow, NEEDLE_ARROW),
			"tampered Needle Arrow record " + str(index) + " is refused")

	_check(not CombatYarnRangerNeedleCards.is_authentic_definition(
		starter.get_definition(NEEDLE_NOCK_PLUS), NEEDLE_NOCK),
		"an upgraded record cannot authenticate as its base ID")
	_check(not CombatYarnRangerNeedleCards.is_authentic_definition(
		starter.get_definition(NEEDLE_NOCK), NEEDLE_NOCK_PLUS),
		"a base record cannot authenticate as its upgraded ID")
	_check(not CombatYarnRangerNeedleCards.is_authentic_definition(
		pool.get_definition(NEEDLE_ARROW), NEEDLE_NOCK),
		"a pool record cannot forge a starter identity")
	_check(not CombatYarnRangerNeedleCards.is_authentic_definition(
		starter.get_definition(NEEDLE_NOCK), NEEDLE_ARROW),
		"a starter record cannot forge a pool identity")


## AC1: a genuinely held base/+ Needle Nock or Needle Arrow from seat 2 or 3 pays exactly one
## energy and one discard, deals its printed damage to the chosen living foe and charges that
## foe's bound gauge with its printed Unravel.
func _test_needle_paid_play() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()
	var cases := [
		{"id": NEEDLE_NOCK, "seat": 2, "target": 1, "damage": 4, "unravel": 1},
		{"id": NEEDLE_NOCK_PLUS, "seat": 3, "target": 3, "damage": 6, "unravel": 2},
		{"id": NEEDLE_ARROW, "seat": 3, "target": 2, "damage": 5, "unravel": 1},
		{"id": NEEDLE_ARROW_PLUS, "seat": 2, "target": 1, "damage": 7, "unravel": 2},
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var card_id: String = entry["id"]
		var seat: int = entry["seat"]
		var target: int = entry["target"]
		var damage: int = entry["damage"]
		var printed_unravel: int = entry["unravel"]
		var label: String = card_id + " from seat " + str(seat) + " onto foe " + str(target)
		var party := _needle_party(seat)
		var enemies := _needle_enemies([
			{"max_hp": 30, "hp": 30}, {"max_hp": 30, "hp": 30}, {"max_hp": 30, "hp": 30},
		])
		var unravel := _needle_ledger(enemies, {1: "normal", 2: "normal", 3: "elite"})
		var threshold := 12 if target == 3 else 8
		var deck := _needle_deck([card_id], 20261028 + index)
		_check(deck.hand.count(card_id) == 1, label + ": exactly one authentic copy is held")
		_check(deck.energy == 3 and deck.turn_active, label + ": a real three-energy turn is active")
		_check(unravel.get_snapshot(target) == {"gauge": 0, "threshold": threshold,
			"unravelled": false, "skip_pending": false},
			label + ": the target gauge starts empty at its tier threshold")
		var rng_before: int = deck._rng.state
		var draw_before: Array = deck.draw_pile.duplicate()
		var before := _needle_snapshot(deck, party, enemies, unravel)
		var result: Dictionary = resolver.play_card(deck, party, enemies, unravel, card_id, target)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			label + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == seat, label + ": receipt reports the real owner seat")
		_check(result.get("target_position") == target, label + ": receipt reports the chosen foe")
		_check(result.get("damage") == damage,
			label + ": printed damage " + str(damage) + " (no pre-hit statuses)")
		_check(result.get("block_absorbed") == 0, label + ": an unblocked hit absorbs nothing")
		_check(result.get("hp_loss") == damage, label + ": the printed damage reaches HP")
		_check(result.get("unravel_added") == printed_unravel,
			label + ": receipt reports the printed Unravel count")
		_check(result.get("unravel") == {"gauge": printed_unravel, "threshold": threshold,
			"unravelled": false, "skip_pending": false},
			label + ": the receipt carries the charged gauge snapshot")
		_check(deck.energy == 2, label + ": exactly one of the three energy was spent")
		_check(deck.hand.count(card_id) == 0, label + ": the held copy left the hand")
		_check(deck.discard_pile == [card_id], label + ": exactly one played copy reached discard")
		_check(deck.draw_pile == draw_before, label + ": the shared draw supply is untouched")
		_check(deck.hand.size() == before["hand"].size() - 1,
			label + ": no extra card was drawn into the shared hand")
		_check(deck._rng.state == rng_before, label + ": the deterministic shot consumes no RNG")
		_check(deck.turn_active, label + ": the shared turn is still active")
		_check(enemies.get_enemy(target).get("hp") == 30 - damage,
			label + ": the target lost exactly the printed damage")
		_check(enemies.get_enemy(target).get("block") == 0, label + ": the target gained no Block")
		_check(not enemies.get_enemy(target).has("statuses"),
			label + ": a needle shot adds no unrelated status")
		_check(enemies.get_enemy(target).get("position") == target,
			label + ": the target kept its original slot")
		for position in [1, 2, 3]:
			if position == target:
				continue
			_check(enemies.get_enemy(position).get("hp") == 30
				and not enemies.get_enemy(position).has("statuses"),
				label + ": non-target foe " + str(position) + " is untouched")
			_check(unravel.get_snapshot(position).get("gauge") == 0,
				label + ": non-target gauge " + str(position) + " is untouched")
		_check(party.get_hero(seat).get("id") == "yarn_ranger"
			and party.get_hero(seat).get("hp") == 27,
			label + ": the owner and its HP stay unchanged")
		_check(_needle_snapshot(deck, party, enemies, unravel)
			== _expected_needle(before, card_id, target, damage, printed_unravel),
			label + ": exact hand, piles, energy, turn, party, enemy, gauge and RNG state")
		# A detached receipt is never authority for later state.
		result["damage"] = 99
		result["unravel_added"] = 99
		result["target_position"] = 3
		_check(unravel.get_snapshot(target).get("gauge") == printed_unravel
			and enemies.get_enemy(target).get("hp") == 30 - damage,
			label + ": a mutated receipt cannot change the target or its gauge")
		# A replay of the spent copy fails without another charge or charge of the gauge.
		var replay_before := _needle_snapshot(deck, party, enemies, unravel)
		var replay: Dictionary = resolver.play_card(deck, party, enemies, unravel, card_id, target)
		_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
			label + ": a replayed spent copy is refused")
		_check(_needle_snapshot(deck, party, enemies, unravel) == replay_before,
			label + ": the refused replay changes nothing")


## AC2: the shared attack bridge owns the one damage hit (Block before HP, Weak/Exposed/Tangled
## modifiers and floor rounding), and only a surviving foe receives the printed Unravel.
func _test_needle_block_and_lethal() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()

	# 1. A fully Block-absorbed nonlethal shot still charges the gauge, and pre-hit Tangled boosts
	#    the absorbed damage without being consumed or recalculated.
	var party := _needle_party(2)
	var enemies := _needle_enemies([
		{"max_hp": 30, "hp": 30},
		{"max_hp": 20, "hp": 20, "block": 9, "statuses": {"tangled": 1}},
		{"max_hp": 30, "hp": 30},
	])
	var unravel := _needle_ledger(enemies, {1: "normal", 2: "normal", 3: "normal"})
	_check(unravel.apply_unravel(enemies, 2, 6),
		"fully blocked fixture really charges the target gauge to six")
	var deck := _needle_deck([NEEDLE_NOCK], 41101)
	var before := _needle_snapshot(deck, party, enemies, unravel)
	var blocked: Dictionary = resolver.play_card(deck, party, enemies, unravel, NEEDLE_NOCK, 2)
	_check(blocked.get("ok") == true, "fully blocked: the authentic play still succeeds")
	_check(blocked.get("damage") == 6,
		"fully blocked: four printed plus the target's flat Tangled two")
	_check(blocked.get("block_absorbed") == 6 and blocked.get("hp_loss") == 0,
		"fully blocked: six damage is absorbed and no HP is lost")
	_check(blocked.get("unravel_added") == 1,
		"fully blocked: a nonlethal absorbed hit still adds its printed Unravel")
	_check(enemies.get_enemy(2).get("hp") == 20 and enemies.get_enemy(2).get("block") == 3,
		"fully blocked: HP is untouched and only Block is spent")
	_check(enemies.get_enemy(2).get("statuses") == {"tangled": 1},
		"fully blocked: a needle shot neither rewrites nor consumes Tangled")
	_check(blocked.get("unravel") == {"gauge": 7, "threshold": 8,
		"unravelled": false, "skip_pending": false},
		"fully blocked: the gauge climbs seven of eight without a skip")
	_check(_needle_snapshot(deck, party, enemies, unravel)
		== _expected_needle(before, NEEDLE_NOCK, 2, 6, 1),
		"fully blocked: exact deck, party, enemy, gauge and RNG state")

	# 1b. An upgraded shot fully absorbed too: its larger printed damage and two Unravel still land.
	var plus_party := _needle_party(3)
	var plus_enemies := _needle_enemies([
		{"max_hp": 30, "hp": 30},
		{"max_hp": 30, "hp": 30, "block": 8},
	])
	var plus_unravel := _needle_ledger(plus_enemies, {1: "normal", 2: "elite"})
	_check(plus_unravel.apply_unravel(plus_enemies, 2, 3),
		"upgraded blocked fixture really charges the target gauge to three")
	var plus_deck := _needle_deck([NEEDLE_NOCK_PLUS], 41104)
	var plus_before := _needle_snapshot(plus_deck, plus_party, plus_enemies, plus_unravel)
	var plus_blocked: Dictionary = resolver.play_card(plus_deck, plus_party, plus_enemies,
		plus_unravel, NEEDLE_NOCK_PLUS, 2)
	_check(plus_blocked.get("ok") == true and plus_blocked.get("damage") == 6,
		"upgraded blocked: the printed six of Needle Nock+ is the one hit")
	_check(plus_blocked.get("block_absorbed") == 6 and plus_blocked.get("hp_loss") == 0,
		"upgraded blocked: six damage is absorbed and no HP is lost")
	_check(plus_blocked.get("unravel_added") == 2,
		"upgraded blocked: the printed two Unravel still lands on the survivor")
	_check(plus_enemies.get_enemy(2).get("block") == 2
		and plus_enemies.get_enemy(2).get("hp") == 30,
		"upgraded blocked: only two Block remain and HP is untouched")
	_check(plus_unravel.get_snapshot(2) == {"gauge": 5, "threshold": 12,
		"unravelled": false, "skip_pending": false},
		"upgraded blocked: the elite gauge climbs five of twelve without a skip")
	_check(_needle_snapshot(plus_deck, plus_party, plus_enemies, plus_unravel)
		== _expected_needle(plus_before, NEEDLE_NOCK_PLUS, 2, 6, 2),
		"upgraded blocked: exact deck, party, enemy, gauge and RNG state")

	# 2. A confirmed lethal hit keeps its slot but charges no Unravel at all.
	var lethal_party := _needle_party(3)
	var lethal_enemies := _needle_enemies([
		{"max_hp": 4, "hp": 4},
		{"max_hp": 30, "hp": 30},
	])
	var lethal_unravel := _needle_ledger(lethal_enemies, {1: "normal", 2: "elite"})
	var lethal_deck := _needle_deck([NEEDLE_NOCK], 41102)
	var lethal_before := _needle_snapshot(lethal_deck, lethal_party, lethal_enemies, lethal_unravel)
	var lethal: Dictionary = resolver.play_card(lethal_deck, lethal_party, lethal_enemies,
		lethal_unravel, NEEDLE_NOCK, 1)
	_check(lethal.get("ok") == true and lethal.get("hp_loss") == 4,
		"lethal: the printed four damage resolves")
	_check(lethal.get("unravel_added") == 0, "lethal: a slain foe receives no Unravel")
	_check(lethal_enemies.is_slain(1), "lethal: the front foe is really slain")
	_check(lethal_enemies.get_enemy(1).get("position") == 1,
		"lethal: the slain foe keeps its original nonmoving slot")
	_check(lethal_unravel.get_snapshot(1) == {"gauge": 0, "threshold": 8,
		"unravelled": false, "skip_pending": false},
		"lethal: the slain foe's gauge stays empty and unqueued")
	_check(lethal_enemies.get_enemy(2).get("hp") == 30
		and lethal_unravel.get_snapshot(2).get("gauge") == 0,
		"lethal: the other foe and its gauge are untouched")
	_check(_needle_snapshot(lethal_deck, lethal_party, lethal_enemies, lethal_unravel)
		== _expected_needle(lethal_before, NEEDLE_NOCK, 1, 4, 0),
		"lethal: exact deck, party, enemy, gauge and RNG state")
	_check(not lethal_unravel.apply_unravel(lethal_enemies, 1, 1),
		"lethal: the slain seat refuses a later gauge charge, so none was hidden")

	# 3. Role tokens the damage bridge does not model: a Dodging Yarn Ranger still lands her shot
	#    on a Blind foe, and neither token is spent, ticked or turned into zero damage.
	var token_party := _needle_party(2)
	token_party._heroes[1]["statuses"] = {"weak": 1, "dodge_next_attack": 1}
	var token_enemies := _needle_enemies([
		{"max_hp": 30, "hp": 30,
			"statuses": {"exposed": 1, "tangled": 2, "blind_next_attack": 0, "bleed": 1}},
		{"max_hp": 30, "hp": 30},
	])
	var token_unravel := _needle_ledger(token_enemies, {1: "normal", 2: "normal"})
	var token_deck := _needle_deck([NEEDLE_ARROW], 41103)
	var token_before := _needle_snapshot(token_deck, token_party, token_enemies, token_unravel)
	var token_result: Dictionary = resolver.play_card(token_deck, token_party, token_enemies,
		token_unravel, NEEDLE_ARROW, 1)
	_check(token_result.get("ok") == true and token_result.get("damage") == 7,
		"role tokens: weak/exposed floor to five, then Tangled adds two, not zero")
	_check(token_result.get("hp_loss") == 7, "role tokens: the adjusted damage reaches HP")
	_check(token_party.get_hero(2).get("statuses")
		== {"weak": 1, "dodge_next_attack": 1},
		"role tokens: the attacker's Weak and unused Dodge are untouched")
	_check(token_enemies.get_enemy(1).get("statuses")
		== {"exposed": 1, "tangled": 2, "blind_next_attack": 0, "bleed": 1},
		"role tokens: the defender's statuses and unused Blind are untouched")
	_check(token_unravel.get_snapshot(1).get("gauge") == 1,
		"role tokens: the surviving foe still receives its printed Unravel")
	_check(_needle_snapshot(token_deck, token_party, token_enemies, token_unravel)
		== _expected_needle(token_before, NEEDLE_ARROW, 1, 7, 1),
		"role tokens: exact deck, party, enemy, gauge and RNG state")


## AC3: the helper charges the caller's already-bound ledger, leaves a queued skip and the
## threshold to CombatUnravel's real consumer, and never queues a second skip at the threshold.
func _test_needle_threshold_and_skip() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()
	var party := _needle_party(2)
	var enemies := _needle_enemies([{"max_hp": 40, "hp": 40}])
	var unravel := _needle_ledger(enemies, {1: "normal"})
	_check(unravel.apply_unravel(enemies, 1, 7), "threshold fixture really reaches seven of eight")
	var at_seven: Dictionary = unravel.get_snapshot(1)
	_check(at_seven == {"gauge": 7, "threshold": 8, "unravelled": false, "skip_pending": false},
		"threshold fixture really starts at 7/8 with no pending skip")
	var deck := _needle_deck([NEEDLE_NOCK, NEEDLE_NOCK], 51101)
	_check(deck.hand.count(NEEDLE_NOCK) == 2, "threshold fixture really holds two legal copies")
	var before := _needle_snapshot(deck, party, enemies, unravel)
	var first: Dictionary = resolver.play_card(deck, party, enemies, unravel, NEEDLE_NOCK, 1)
	_check(first.get("ok") == true and first.get("damage") == 4,
		"threshold: the first legal shot resolves its printed four damage")
	_check(first.get("unravel_added") == 1, "threshold: the first shot adds its one Unravel")
	_check(unravel.get_snapshot(1) == {"gauge": 8, "threshold": 8,
		"unravelled": true, "skip_pending": true},
		"threshold: the foe reaches 8/8 and queues exactly one action skip")
	_check(deck.energy == 2 and enemies.get_enemy(1).get("hp") == 36,
		"threshold: one energy and four HP really left")
	_check(_needle_snapshot(deck, party, enemies, unravel)
		== _expected_needle(before, NEEDLE_NOCK, 1, 4, 1),
		"threshold: exact deck, party, enemy, gauge and RNG state")
	var at_eight: Dictionary = unravel.get_snapshot(1)
	# A second full legal play at the threshold must not stack a second skip or raise the line.
	var second_before := _needle_snapshot(deck, party, enemies, unravel)
	var second: Dictionary = resolver.play_card(deck, party, enemies, unravel, NEEDLE_NOCK, 1)
	_check(second.get("ok") == true and second.get("damage") == 4,
		"threshold: a second held copy is still a legal paid shot")
	_check(second.get("unravel_added") == 1,
		"threshold: the ledger accepts the charge request at the threshold")
	_check(deck.energy == 1 and enemies.get_enemy(1).get("hp") == 32,
		"threshold: the second shot spends one energy and four more HP")
	_check(unravel.get_snapshot(1) == at_eight,
		"threshold: no extra gauge, skip or threshold change at 8/8")
	_check(_needle_snapshot(deck, party, enemies, unravel)
		== _expected_needle(second_before, NEEDLE_NOCK, 1, 4, 1),
		"threshold: exact state after the second legal play")
	# The real consumer still finds exactly the one queued skip and resets the gauge once.
	_check(unravel.consume_action_skip(enemies, 1),
		"threshold: the queued skip is still pending for the real consumer")
	_check(unravel.get_snapshot(1) == {"gauge": 0, "threshold": 12,
		"unravelled": false, "skip_pending": false},
		"threshold: normal consumption resets the gauge and raises the line by four")
	_check(not unravel.consume_action_skip(enemies, 1),
		"threshold: the helper had queued exactly one skip, never two")


## AC4: unheld/unknown/foreign IDs, an illegal owner or target, an inactive turn, no energy, a
## malformed roster/status map or an unbound/wrong-roster ledger all refuse before any spend.
func _test_needle_refusals() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()
	var party := _needle_party(2)
	var enemies := _needle_enemies([
		{"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 12},
	])
	var unravel := _needle_ledger(enemies, {1: "normal", 2: "normal", 3: "normal"})
	var deck := _needle_deck([NEEDLE_NOCK], 4455)

	_rejected_needle(resolver, null, party, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_request", "null deck")
	_rejected_needle(resolver, deck, null, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_request", "null party")
	_rejected_needle(resolver, deck, party, null, unravel, NEEDLE_NOCK, 1,
		"invalid_request", "null enemies")
	_rejected_needle(resolver, deck, party, enemies, null, NEEDLE_NOCK, 1,
		"invalid_request", "null ledger")
	var unseeded := _needle_deck([NEEDLE_NOCK], 9001)
	unseeded._rng = null
	_rejected_needle(resolver, unseeded, party, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_request", "deck without a seeded RNG")

	# Inactive turn.
	var inactive := CombatDeck.new([NEEDLE_NOCK, "needle_filler_a"], _needle_rng(12))
	inactive.hand.append(NEEDLE_NOCK)
	_check(not inactive.turn_active and inactive.hand.has(NEEDLE_NOCK),
		"inactive fixture really holds a copy outside a turn")
	_rejected_needle(resolver, inactive, party, enemies, unravel, NEEDLE_NOCK, 1,
		"inactive_turn", "inactive turn")

	# Wrong IDs: unrelated authentic cards, forged spellings and non-strings.
	var unsupported: Array = [NEEDLE_NOCK + "_plus_plus", NEEDLE_NOCK_PLUS + "_plus",
		"yarn_ranger_needle_nock+", "yarn_ranger_needle_nock_ ", "needle_nock",
		"NEEDLE_ARROW", "yarn_ranger_wool_bolas", "yarn_ranger_hood_knit",
		"yarn_ranger_snare_net", "warden_strike", "", StringName(NEEDLE_NOCK), null, 0,
		3.5, false, [], {}]
	for wrong_id: Variant in unsupported:
		_rejected_needle(resolver, deck, party, enemies, unravel, wrong_id, 1,
			"unsupported_card", "unsupported ID " + str(wrong_id))

	# Authentic printings the hand does not hold are still unheld.
	_rejected_needle(resolver, deck, party, enemies, unravel, NEEDLE_NOCK_PLUS, 1,
		"card_not_held", "authentic but unheld Needle Nock+")
	_rejected_needle(resolver, deck, party, enemies, unravel, NEEDLE_ARROW, 1,
		"card_not_held", "authentic but unheld Needle Arrow")
	var no_copy := CombatDeck.new(["needle_filler_a", "needle_filler_b", "needle_filler_c",
		"needle_filler_d", "needle_filler_e"], _needle_rng(77))
	_check(no_copy.start_turn() and not no_copy.hand.has(NEEDLE_NOCK),
		"missing-copy fixture really lacks the card")
	_rejected_needle(resolver, no_copy, party, enemies, unravel, NEEDLE_NOCK, 1,
		"card_not_held", "missing held copy")

	# No energy.
	var poor := _needle_deck([NEEDLE_NOCK], 5566)
	poor.combat_state.energy = 0
	_check(poor.energy == 0 and poor.hand.has(NEEDLE_NOCK),
		"short-energy fixture really holds a copy with no energy")
	_rejected_needle(resolver, poor, party, enemies, unravel, NEEDLE_NOCK, 1,
		"insufficient_energy", "no energy")

	# Illegal target slots: only enemies 1-3 are real recipients.
	for slot: int in [0, 4, -1, 99]:
		_rejected_needle(resolver, deck, party, enemies, unravel, NEEDLE_NOCK, slot,
			"invalid_target", "illegal target slot " + str(slot))
	var dead_target := _needle_enemies([
		{"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 0}, {"max_hp": 12, "hp": 12},
	])
	var dead_ledger := _needle_ledger(dead_target, {1: "normal", 2: "normal", 3: "normal"})
	_rejected_needle(resolver, deck, party, dead_target, dead_ledger, NEEDLE_NOCK, 2,
		"target_downed", "slain target slot")

	# Invalid rosters.
	var short_party := CombatParty.new([{"id": "yarn_ranger", "max_hp": 27}])
	_rejected_needle(resolver, deck, short_party, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_roster", "invalid one-hero party")
	_rejected_needle(resolver, deck, party, CombatEnemies.new([]), unravel, NEEDLE_NOCK, 1,
		"invalid_roster", "invalid empty enemy roster")

	# Owner absent, in the front seat, or downed grants no authority.
	var no_owner := CombatParty.new([{"id": "rag_duelist", "max_hp": 32},
		{"id": "scarecrow", "max_hp": 34}, {"id": "lantern_monk", "max_hp": 30}])
	_check(no_owner.is_valid() and no_owner.get_hero(2).get("id") == "scarecrow",
		"absent-owner fixture is a valid three-hero party with no Yarn Ranger")
	_rejected_needle(resolver, deck, no_owner, enemies, unravel, NEEDLE_NOCK, 1,
		"owner_missing", "absent Yarn Ranger")
	var front := _needle_party(1)
	_check(front.get_hero(1).get("id") == "yarn_ranger" and not front.is_downed(1),
		"front-seat fixture really has a living Yarn Ranger in seat 1")
	_rejected_needle(resolver, deck, front, enemies, unravel, NEEDLE_NOCK, 1,
		"owner_illegal_position", "Yarn Ranger in seat 1")
	var torn := _needle_party(3)
	_check(torn.apply_damage(3, 27) and torn.is_downed(3),
		"torn-owner fixture really has a downed Yarn Ranger")
	_rejected_needle(resolver, deck, torn, enemies, unravel, NEEDLE_NOCK, 1,
		"owner_downed", "downed owner")

	# Malformed party/enemy models and status maps fail closed.
	var duplicate := _needle_party(2)
	duplicate._heroes[2]["id"] = "yarn_ranger"
	_check(duplicate.get_hero(2).get("id") == "yarn_ranger"
		and duplicate.get_hero(3).get("id") == "yarn_ranger",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_needle(resolver, deck, duplicate, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_party", "duplicate hero identity")
	var bad_hp := _needle_party(2)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_needle(resolver, deck, bad_hp, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_party", "malformed hero HP")
	var bad_party_statuses := _needle_party(2)
	bad_party_statuses._heroes[1]["statuses"] = "bad"
	_rejected_needle(resolver, deck, bad_party_statuses, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_party", "malformed party status map")
	var bad_attacker := _needle_party(3)
	bad_attacker._heroes[2]["statuses"] = {"forged": 1}
	_rejected_needle(resolver, deck, bad_attacker, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_party", "unsupported attacker status map")
	var blind_attacker := _needle_party(2)
	blind_attacker._heroes[1]["statuses"] = {"blind_next_attack": 1}
	_rejected_needle(resolver, deck, blind_attacker, enemies, unravel, NEEDLE_NOCK, 1,
		"invalid_statuses", "attacker Blind token belongs to the miss path")
	for malformed: Variant in ["bad", 4, {"tangled": -1}, {"tangled": "2"}, {"forged": 1},
			{"tangled": 1.5}, {"tangled": true}, {1: 2}]:
		var broken := _needle_enemies([
			{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10},
		])
		broken._enemies[1]["statuses"] = malformed
		var broken_ledger := _needle_ledger(broken, {1: "normal", 2: "normal", 3: "normal"})
		_rejected_needle(resolver, deck, party, broken, broken_ledger, NEEDLE_NOCK, 1,
			"invalid_enemies", "malformed target status map " + str(malformed))
	var dodging_target := _needle_enemies([
		{"max_hp": 10, "hp": 10, "statuses": {"dodge_next_attack": 1}},
		{"max_hp": 10, "hp": 10},
	])
	var dodging_ledger := _needle_ledger(dodging_target, {1: "normal", 2: "normal"})
	_rejected_needle(resolver, deck, party, dodging_target, dodging_ledger, NEEDLE_NOCK, 1,
		"invalid_statuses", "defender Dodge token belongs to the evasion path")
	var bad_enemy_hp := _needle_enemies([{"max_hp": 10, "hp": 10}])
	bad_enemy_hp._enemies[0]["hp"] = 99
	var bad_enemy_hp_ledger := _needle_ledger(bad_enemy_hp, {1: "normal"})
	_rejected_needle(resolver, deck, party, bad_enemy_hp, bad_enemy_hp_ledger, NEEDLE_NOCK, 1,
		"invalid_enemies", "malformed enemy HP")
	var bad_enemy_position := _needle_enemies([{"max_hp": 10, "hp": 10}])
	bad_enemy_position._enemies[0]["position"] = 2
	var bad_enemy_position_ledger := _needle_ledger(bad_enemy_position, {1: "normal"})
	_rejected_needle(resolver, deck, party, bad_enemy_position, bad_enemy_position_ledger,
		NEEDLE_NOCK, 1, "invalid_enemies", "malformed enemy slot index")

	# Unbound or wrongly bound ledgers never authorize a paid shot.
	var unbound := CombatUnravel.new()
	_rejected_needle(resolver, deck, party, enemies, unbound, NEEDLE_NOCK, 1,
		"invalid_unravel", "unbound ledger")
	var other_enemies := _needle_enemies([{"max_hp": 12, "hp": 12}])
	var wrong_ledger := _needle_ledger(other_enemies, {1: "normal"})
	_rejected_needle(resolver, deck, party, enemies, wrong_ledger, NEEDLE_NOCK, 1,
		"invalid_unravel", "ledger bound to another roster")

	# A consumed copy cannot be played twice.
	var repeat_enemies := _needle_enemies([{"max_hp": 14, "hp": 14}])
	var repeat_party := _needle_party(2)
	var repeat_ledger := _needle_ledger(repeat_enemies, {1: "normal"})
	var repeat_deck := _needle_deck([NEEDLE_NOCK_PLUS], 8814)
	_check(resolver.play_card(repeat_deck, repeat_party, repeat_enemies, repeat_ledger,
		NEEDLE_NOCK_PLUS, 1).get("ok") == true, "duplicate-play fixture really casts once")
	_check(repeat_deck.energy == 2 and repeat_deck.discard_pile == [NEEDLE_NOCK_PLUS],
		"duplicate-play fixture really spent one energy and discarded the copy")
	var repeat_after := _needle_snapshot(repeat_deck, repeat_party, repeat_enemies, repeat_ledger)
	var replay: Dictionary = resolver.play_card(repeat_deck, repeat_party, repeat_enemies,
		repeat_ledger, NEEDLE_NOCK_PLUS, 1)
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		"replay: the consumed copy is refused")
	_check(_needle_snapshot(repeat_deck, repeat_party, repeat_enemies, repeat_ledger)
		== repeat_after, "replay: the refusal changes no energy, card, HP or gauge")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry_deck := _needle_deck([NEEDLE_ARROW_PLUS], 6123)
	var retry_party := _needle_party(3)
	var retry_enemies := _needle_enemies([{"max_hp": 14, "hp": 14}])
	var retry_ledger := _needle_ledger(retry_enemies, {1: "boss"})
	_rejected_needle(resolver, retry_deck, retry_party, retry_enemies, retry_ledger,
		"yarn_ranger_snare_net", 1, "unsupported_card", "retry: wrong card first")
	_rejected_needle(resolver, retry_deck, retry_party, retry_enemies, retry_ledger,
		NEEDLE_ARROW_PLUS, 0, "invalid_target", "retry: illegal slot second")
	var retry_result: Dictionary = resolver.play_card(retry_deck, retry_party, retry_enemies,
		retry_ledger, NEEDLE_ARROW_PLUS, 1)
	_check(retry_result.get("ok") == true and retry_deck.energy == 2
		and retry_enemies.get_enemy(1).get("hp") == 7
		and retry_ledger.get_snapshot(1).get("gauge") == 2,
		"retry: the authentic play then succeeds exactly once on the boss gauge")
	_check(retry_ledger.get_snapshot(1).get("threshold") == 16,
		"retry: the boss seat keeps the service's own sixteen-point threshold")


## AC1: the two authored Purling Barrage reward printings authenticate only as themselves in
## the Yarn Ranger pool, keep their exact two-energy/two-hit/back-seat line and upgrade link,
## refuse forged or tampered records, and never enter the separate needle-shot table.
func _test_purling_catalog_contract() -> void:
	var starter := YarnRangerStarterCards.new()
	var pool := YarnRangerPoolCards.new()
	var resolver := CombatYarnRangerNeedleCards.new()
	var expected := {
		PURLING: {"name": "Purling Barrage", "damage": 3, "unravel": 1, "reward": true},
		PURLING_PLUS: {"name": "Purling Barrage+", "damage": 4, "unravel": 2,
			"reward": false},
	}
	_check(pool.get_upgrade_id(PURLING) == PURLING_PLUS,
		"Purling Barrage maps to its authored upgrade")
	_check(pool.get_upgrade_id(PURLING_PLUS) == "",
		"Purling Barrage+ cannot upgrade again")
	_check(not pool.has_card(PURLING_PLUS + "_plus"),
		"Purling Barrage+ has no second upgrade")
	for card_id: String in PURLING_IDS:
		var spec: Dictionary = expected[card_id]
		var record: Dictionary = pool.get_definition(card_id)
		_check(not record.is_empty(), card_id + " is authored by the Yarn Ranger pool")
		_check(starter.get_definition(card_id).is_empty(),
			card_id + " is not a Yarn Ranger starter card")
		_check(record.get("id") == card_id, card_id + " keeps its exact identifier")
		_check(record.get("display_name") == spec["name"], card_id + " keeps its printed name")
		_check(record.get("owner") == "yarn_ranger", card_id + " is owned by the Yarn Ranger")
		_check(record.get("cost") == 2, card_id + " prints two energy")
		_check(record.get("from_positions") == [3], card_id + " prints FROM the back seat only")
		_check(record.get("target_kind") == "enemy_single",
			card_id + " prints a single-enemy target")
		_check(record.get("to_positions") == [1, 2, 3], card_id + " prints TO slots 1-3")
		var effects: Dictionary = record.get("effects", {})
		_check(effects == {"damage": spec["damage"], "hit_count": 2,
			"unravel": spec["unravel"]},
			card_id + " prints exactly " + str(spec["damage"]) + " damage per hit, two hits and "
			+ str(spec["unravel"]) + " Unravel")
		_check(effects.size() == 3, card_id + " carries no extra effect key")
		_check(typeof(effects.get("damage")) == TYPE_INT
			and typeof(effects.get("hit_count")) == TYPE_INT
			and typeof(effects.get("unravel")) == TYPE_INT,
			card_id + " prints integer damage, hit count and Unravel values")
		_check(record.get("starting_copies") == 0,
			card_id + " adds no starting copy")
		_check(record.get("reward_eligible") == spec["reward"],
			card_id + " keeps its authored reward eligibility")
		_check(record.get("rarity") == "uncommon", card_id + " stays an uncommon reward")
		if card_id == PURLING:
			_check(record.get("upgrade_id") == PURLING_PLUS and not record.has("upgrade_of"),
				card_id + " links forward to its one upgrade")
		else:
			_check(record.get("upgrade_of") == PURLING and not record.has("upgrade_id"),
				card_id + " links back to its one base printing")
		_check(resolver.is_supported_purling_card(card_id),
			card_id + " is a supported Purling Barrage card")
		_check(CombatYarnRangerNeedleCards.is_authentic_purling_definition(record, card_id),
			card_id + " passes the Purling definition authenticator")
		_check(CombatYarnRangerNeedleCards.purling_definition(card_id) == record,
			card_id + " resolves to its exact detached pool record")
		# The Purling printings stay out of the existing one-hit needle service.
		_check(not resolver.is_supported_card(card_id),
			card_id + " is not a supported needle shot")
		_check(CombatYarnRangerNeedleCards.needle_definition(card_id).is_empty(),
			card_id + " does not resolve as a needle shot")

	_check(CombatYarnRangerNeedleCards.PURLING_CARDS.has(PURLING)
		and CombatYarnRangerNeedleCards.PURLING_CARDS.has(PURLING_PLUS),
		"the resolver table carries both authentic Purling printings")
	for needle_id: String in NEEDLE_IDS:
		_check(not CombatYarnRangerNeedleCards.PURLING_CARDS.has(needle_id),
			needle_id + " is not a Purling Barrage card")

	# Detached: mutating a resolved record cannot rewrite the next resolution.
	var sample := CombatYarnRangerNeedleCards.purling_definition(PURLING)
	_check(not sample.is_empty(), "Purling resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["damage"] = 900
		sample["effects"]["hit_count"] = 9
		sample["effects"]["unravel"] = 900
		sample["from_positions"].clear()
		sample["cost"] = 0
		sample["display_name"] = "Forged Barrage"
		_check(CombatYarnRangerNeedleCards.purling_definition(PURLING)
			== pool.get_definition(PURLING),
			"a mutated Purling definition cannot poison later resolutions")

	# Forged or unrelated IDs never resolve, including the needle printings.
	var forged: Array = [PURLING + "_plus_plus", "yarn_ranger_purling_barrage_+",
		"purling_barrage", "yarn_ranger_Purling_Barrage", " " + PURLING, PURLING + " ",
		PURLING.to_upper(), "", NEEDLE_NOCK, NEEDLE_ARROW_PLUS, "yarn_ranger_snare_net",
		"warden_strike", StringName(PURLING), null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatYarnRangerNeedleCards.purling_definition(other_id).is_empty(),
			"forged or unrelated ID never resolves as Purling Barrage: " + str(other_id))
		_check(not CombatYarnRangerNeedleCards.is_authentic_purling_definition(
			pool.get_definition(PURLING), other_id),
			"a Purling record cannot authenticate under a forged ID: " + str(other_id))

	# Adversarial copies of the base record: every altered contract field is refused.
	var base_record: Dictionary = pool.get_definition(PURLING)
	_check(not base_record.is_empty()
		and CombatYarnRangerNeedleCards.is_authentic_purling_definition(
			base_record, PURLING),
		"authenticator positive fixture really is the authored Purling Barrage")
	var base_mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["damage"] = 4,
		func(record: Dictionary) -> void: record["effects"]["damage"] = 3.0,
		func(record: Dictionary) -> void: record["effects"]["damage"] = "3",
		func(record: Dictionary) -> void: record["effects"]["hit_count"] = 1,
		func(record: Dictionary) -> void: record["effects"]["hit_count"] = 3,
		func(record: Dictionary) -> void: record["effects"]["hit_count"] = 2.0,
		func(record: Dictionary) -> void: record["effects"]["unravel"] = 2,
		func(record: Dictionary) -> void: record["effects"]["unravel"] = true,
		func(record: Dictionary) -> void: record["effects"].erase("hit_count"),
		func(record: Dictionary) -> void: record["effects"].erase("unravel"),
		func(record: Dictionary) -> void: record["effects"]["tangled"] = 1,
		func(record: Dictionary) -> void: record["effects"] = "damage",
		func(record: Dictionary) -> void: record["cost"] = 1,
		func(record: Dictionary) -> void: record["cost"] = 3,
		func(record: Dictionary) -> void: record["cost"] = 2.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["display_name"] = "Purling Barrage+",
		func(record: Dictionary) -> void: record["from_positions"] = [2, 3],
		func(record: Dictionary) -> void: record["from_positions"] = [1, 2, 3],
		func(record: Dictionary) -> void: record["to_positions"] = [1, 2],
		func(record: Dictionary) -> void: record["target_kind"] = "enemy_all",
		func(record: Dictionary) -> void: record["id"] = PURLING_PLUS,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record["upgrade_of"] = PURLING,
		func(record: Dictionary) -> void: record["starting_copies"] = 1,
		func(record: Dictionary) -> void: record["reward_eligible"] = false,
		func(record: Dictionary) -> void: record["rarity"] = "common",
		func(record: Dictionary) -> void: record.erase("rarity"),
		func(record: Dictionary) -> void: record.erase("effects"),
		func(record: Dictionary) -> void: record.erase("display_name"),
	]
	for index in range(base_mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		base_mutations[index].call(tampered)
		_check(not CombatYarnRangerNeedleCards.is_authentic_purling_definition(
			tampered, PURLING),
			"tampered Purling Barrage record " + str(index) + " is refused")

	# The upgraded printing carries its own reward/upgrade line; tampering is refused too.
	var plus_record: Dictionary = pool.get_definition(PURLING_PLUS)
	_check(not plus_record.is_empty()
		and CombatYarnRangerNeedleCards.is_authentic_purling_definition(
			plus_record, PURLING_PLUS),
		"authenticator positive fixture really is the authored Purling Barrage+")
	var plus_mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["damage"] = 3,
		func(record: Dictionary) -> void: record["effects"]["unravel"] = 1,
		func(record: Dictionary) -> void: record["reward_eligible"] = true,
		func(record: Dictionary) -> void: record.erase("upgrade_of"),
		func(record: Dictionary) -> void: record["upgrade_id"] = PURLING_PLUS,
		func(record: Dictionary) -> void: record["rarity"] = "rare",
	]
	for index in range(plus_mutations.size()):
		var tampered_plus: Dictionary = plus_record.duplicate(true)
		plus_mutations[index].call(tampered_plus)
		_check(not CombatYarnRangerNeedleCards.is_authentic_purling_definition(
			tampered_plus, PURLING_PLUS),
			"tampered Purling Barrage+ record " + str(index) + " is refused")

	_check(not CombatYarnRangerNeedleCards.is_authentic_purling_definition(
		pool.get_definition(PURLING_PLUS), PURLING),
		"an upgraded record cannot authenticate as its base ID")
	_check(not CombatYarnRangerNeedleCards.is_authentic_purling_definition(
		pool.get_definition(PURLING), PURLING_PLUS),
		"a base record cannot authenticate as its upgraded ID")
	_check(not CombatYarnRangerNeedleCards.is_authentic_purling_definition(
		pool.get_definition(PURLING), NEEDLE_ARROW),
		"a Purling record cannot forge a needle identity")
	_check(not CombatYarnRangerNeedleCards.is_authentic_definition(
		pool.get_definition(PURLING), PURLING),
		"a Purling record cannot enter the needle authenticator")
	_check(not CombatYarnRangerNeedleCards.is_authentic_purling_definition(
		starter.get_definition(NEEDLE_NOCK), NEEDLE_NOCK),
		"a needle record cannot enter the Purling authenticator")


## AC2: a genuinely held base/+ Purling Barrage from the back seat pays exactly two energy,
## discards exactly one copy and resolves two independent printed-damage hits through the shared
## attack bridge, then charges the printed Unravel once on the surviving target.
func _test_purling_paid_play() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()
	var cases := [
		{"id": PURLING, "target": 1, "damage": 3, "unravel": 1},
		{"id": PURLING_PLUS, "target": 2, "damage": 4, "unravel": 2},
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var card_id: String = entry["id"]
		var target: int = entry["target"]
		var damage: int = entry["damage"]
		var printed_unravel: int = entry["unravel"]
		var threshold := 8 if target == 1 else 12
		var label: String = card_id + " onto foe " + str(target)
		var party := _needle_party(3)
		var enemies := _needle_enemies([
			{"max_hp": 40, "hp": 40}, {"max_hp": 40, "hp": 40}, {"max_hp": 40, "hp": 40},
		])
		var unravel := _needle_ledger(enemies, {1: "normal", 2: "elite", 3: "boss"})
		var deck := _needle_deck([card_id], 20261029 + index)
		_check(deck.hand.count(card_id) == 1, label + ": exactly one authentic copy is held")
		_check(deck.energy == 3 and deck.turn_active,
			label + ": a real three-energy turn is active")
		_check(unravel.get_snapshot(target) == {"gauge": 0, "threshold": threshold,
			"unravelled": false, "skip_pending": false},
			label + ": the target gauge starts empty at its tier threshold")
		var rng_before: int = deck._rng.state
		var draw_before: Array = deck.draw_pile.duplicate()
		var before := _needle_snapshot(deck, party, enemies, unravel)
		var result: Dictionary = resolver.play_purling_barrage(deck, party, enemies, unravel,
			card_id, target)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 2,
			label + ": receipt names the authentic card and its two energy")
		_check(result.get("owner_position") == 3, label + ": receipt reports the real owner seat")
		_check(result.get("target_position") == target,
			label + ": receipt reports the chosen foe")
		_check(result.get("damage_per_hit") == damage and result.get("damage") == damage,
			label + ": printed per-hit damage " + str(damage))
		_check(result.get("hit_count") == 2, label + ": receipt reports both real hits")
		var hits: Array = result.get("hits", [])
		_check(hits.size() == 2, label + ": two per-hit receipts are exposed")
		var total_hp := 0
		for hit_index in range(hits.size()):
			var hit: Dictionary = hits[hit_index]
			_check(hit.get("index") == hit_index + 1, label + ": hit " + str(hit_index + 1)
				+ " keeps its sequence number")
			_check(hit.get("damage") == damage and hit.get("block_absorbed") == 0
				and hit.get("hp_loss") == damage,
				label + ": hit " + str(hit_index + 1) + " deals the full printed damage to HP")
			total_hp += int(hit.get("hp_loss", 0))
		_check(result.get("total_damage") == damage * 2
			and result.get("total_block_absorbed") == 0
			and result.get("total_hp_loss") == damage * 2 and total_hp == damage * 2,
			label + ": both hits really add up")
		_check(result.get("unravel_added") == printed_unravel,
			label + ": receipt reports the one printed Unravel charge")
		_check(result.get("unravel") == {"gauge": printed_unravel, "threshold": threshold,
			"unravelled": false, "skip_pending": false},
			label + ": the receipt carries the once-charged gauge snapshot")
		_check(deck.energy == 1, label + ": exactly two of the three energy were spent")
		_check(deck.combat_state.energy == 1, label + ": the shared combat state agrees")
		_check(deck.hand.count(card_id) == 0, label + ": the held copy left the hand")
		_check(deck.discard_pile == [card_id],
			label + ": exactly one played copy reached discard")
		_check(deck.draw_pile == draw_before, label + ": the shared draw supply is untouched")
		_check(deck.hand.size() == before["hand"].size() - 1,
			label + ": no extra card was drawn into the shared hand")
		_check(deck._rng.state == rng_before, label + ": the deterministic play consumes no RNG")
		_check(deck.turn_active, label + ": the shared turn is still active")
		_check(enemies.get_enemy(target).get("hp") == 40 - damage * 2,
			label + ": the target lost exactly both printed hits")
		_check(enemies.get_enemy(target).get("block") == 0,
			label + ": the target gained no Block")
		_check(not enemies.get_enemy(target).has("statuses"),
			label + ": Purling Barrage adds no unrelated status")
		_check(enemies.get_enemy(target).get("position") == target,
			label + ": the target kept its original slot")
		for position in [1, 2, 3]:
			if position == target:
				continue
			_check(enemies.get_enemy(position).get("hp") == 40
				and not enemies.get_enemy(position).has("statuses"),
				label + ": non-target foe " + str(position) + " is untouched")
			_check(unravel.get_snapshot(position).get("gauge") == 0,
				label + ": non-target gauge " + str(position) + " is untouched")
		_check(party.get_hero(3).get("id") == "yarn_ranger"
			and party.get_hero(3).get("hp") == 27,
			label + ": the owner and its HP stay unchanged")
		_check(_needle_snapshot(deck, party, enemies, unravel)
			== _expected_purling(before, card_id, target, damage, 2, printed_unravel),
			label + ": exact hand, piles, energy, turn, party, enemy, gauge and RNG state")
		# A detached receipt is never authority for later state.
		result["damage"] = 99
		result["hit_count"] = 9
		result["hits"] = []
		result["unravel_added"] = 99
		_check(unravel.get_snapshot(target).get("gauge") == printed_unravel
			and enemies.get_enemy(target).get("hp") == 40 - damage * 2,
			label + ": a mutated receipt cannot change the target or its gauge")
		# A replay of the spent copy fails without another hit or gauge charge.
		var replay_before := _needle_snapshot(deck, party, enemies, unravel)
		var replay: Dictionary = resolver.play_purling_barrage(deck, party, enemies, unravel,
			card_id, target)
		_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
			label + ": a replayed spent copy is refused")
		_check(_needle_snapshot(deck, party, enemies, unravel) == replay_before,
			label + ": the refused replay changes nothing")


## AC2: the shared attack bridge owns each independent hit (Block before HP, Weak/Exposed/Tangled
## modifiers and floor rounding), and a lethal first hit stops the sequence without retargeting.
func _test_purling_two_hits_and_lethal() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()

	# 1. Both hits are status-adjusted separately and each spends Block before HP.
	#    Base 3 with attacker Weak and defender Exposed floors 3.375 to 3, then Tangled adds 2.
	#    Hit one spends five of six Block; hit two spends the last Block and four HP.
	var party := _needle_party(3)
	party._heroes[2]["statuses"] = {"weak": 1}
	var enemies := _needle_enemies([
		{"max_hp": 40, "hp": 40},
		{"max_hp": 40, "hp": 40, "block": 6,
			"statuses": {"exposed": 1, "tangled": 2}},
		{"max_hp": 40, "hp": 40},
	])
	var unravel := _needle_ledger(enemies, {1: "normal", 2: "normal", 3: "normal"})
	var deck := _needle_deck([PURLING], 51111)
	var before := _needle_snapshot(deck, party, enemies, unravel)
	var blocked: Dictionary = resolver.play_purling_barrage(deck, party, enemies, unravel,
		PURLING, 2)
	_check(blocked.get("ok") == true, "status hits: the authentic play succeeds")
	_check(blocked.get("hit_count") == 2, "status hits: both independent hits happen")
	var blocked_hits: Array = blocked.get("hits", [])
	_check(blocked_hits.size() == 2, "status hits: two per-hit receipts are exposed")
	if blocked_hits.size() == 2:
		_check(blocked_hits[0].get("damage") == 5
			and blocked_hits[0].get("block_absorbed") == 5
			and blocked_hits[0].get("hp_loss") == 0,
			"status hits: the first five-damage hit is fully Block-absorbed")
		_check(blocked_hits[1].get("damage") == 5
			and blocked_hits[1].get("block_absorbed") == 1
			and blocked_hits[1].get("hp_loss") == 4,
			"status hits: the second hit spends the last Block then reaches HP")
	_check(blocked.get("total_damage") == 10 and blocked.get("total_block_absorbed") == 6
		and blocked.get("total_hp_loss") == 4,
		"status hits: the receipt totals the two separate hits")
	_check(enemies.get_enemy(2).get("block") == 0 and enemies.get_enemy(2).get("hp") == 36,
		"status hits: the target ends with no Block and four less HP")
	_check(enemies.get_enemy(2).get("statuses") == {"exposed": 1, "tangled": 2},
		"status hits: the defender's statuses are neither rewritten nor consumed")
	_check(party.get_hero(3).get("statuses") == {"weak": 1},
		"status hits: the attacker's Weak is neither rewritten nor consumed")
	_check(blocked.get("unravel_added") == 1
		and unravel.get_snapshot(2).get("gauge") == 1,
		"status hits: the survivor receives its single Unravel after both hits")
	_check(deck.energy == 1 and deck.discard_pile == [PURLING],
		"status hits: two energy and one copy were paid exactly once")
	_check(_needle_snapshot(deck, party, enemies, unravel)
		== _expected_purling(before, PURLING, 2, 5, 2, 1),
		"status hits: exact deck, party, enemy, gauge and RNG state")

	# 2. An upgraded shot still hits twice: base 4 with Exposed 1.5 then Tangled +2 gives eight
	#    per hit, so nine Block only absorbs the first hit.
	var plus_party := _needle_party(3)
	var plus_enemies := _needle_enemies([
		{"max_hp": 40, "hp": 40, "block": 9, "statuses": {"exposed": 1, "tangled": 1}},
		{"max_hp": 40, "hp": 40},
	])
	var plus_unravel := _needle_ledger(plus_enemies, {1: "elite", 2: "normal"})
	var plus_deck := _needle_deck([PURLING_PLUS], 51112)
	var plus_before := _needle_snapshot(plus_deck, plus_party, plus_enemies, plus_unravel)
	var plus_blocked: Dictionary = resolver.play_purling_barrage(plus_deck, plus_party,
		plus_enemies, plus_unravel, PURLING_PLUS, 1)
	_check(plus_blocked.get("ok") == true and plus_blocked.get("hit_count") == 2,
		"upgraded status hits: both printed hits resolve")
	_check(plus_blocked.get("total_damage") == 16
		and plus_blocked.get("total_block_absorbed") == 9
		and plus_blocked.get("total_hp_loss") == 7,
		"upgraded status hits: eight damage per hit against nine Block")
	_check(plus_enemies.get_enemy(1).get("block") == 0
		and plus_enemies.get_enemy(1).get("hp") == 33,
		"upgraded status hits: nine Block spent and seven HP lost")
	_check(plus_blocked.get("unravel_added") == 2
		and plus_unravel.get_snapshot(1).get("gauge") == 2,
		"upgraded status hits: two Unravel added once on the survivor")
	_check(_needle_snapshot(plus_deck, plus_party, plus_enemies, plus_unravel)
		== _expected_purling(plus_before, PURLING_PLUS, 1, 8, 2, 2),
		"upgraded status hits: exact deck, party, enemy, gauge and RNG state")

	# 3. A lethal first hit ends the sequence: no second hit, no retarget, no Unravel.
	var lethal_party := _needle_party(3)
	var lethal_enemies := _needle_enemies([
		{"max_hp": 30, "hp": 30},
		{"max_hp": 3, "hp": 3},
		{"max_hp": 30, "hp": 30},
	])
	var lethal_unravel := _needle_ledger(lethal_enemies, {1: "normal", 2: "elite", 3: "boss"})
	var lethal_deck := _needle_deck([PURLING], 51113)
	var lethal_before := _needle_snapshot(lethal_deck, lethal_party, lethal_enemies, lethal_unravel)
	var lethal: Dictionary = resolver.play_purling_barrage(lethal_deck, lethal_party,
		lethal_enemies, lethal_unravel, PURLING, 2)
	_check(lethal.get("ok") == true and lethal.get("hit_count") == 1,
		"lethal: the first hit kills, so exactly one hit is reported")
	var lethal_hits: Array = lethal.get("hits", [])
	_check(lethal_hits.size() == 1 and lethal_hits[0].get("hp_loss") == 3,
		"lethal: the single hit carries its real HP loss")
	_check(lethal.get("total_damage") == 3 and lethal.get("total_hp_loss") == 3,
		"lethal: no second hit is invented")
	_check(lethal.get("unravel_added") == 0, "lethal: a slain foe receives no Unravel")
	_check(lethal_enemies.is_slain(2), "lethal: the chosen foe is really slain")
	_check(lethal_enemies.get_enemy(2).get("position") == 2,
		"lethal: the slain foe keeps its original nonmoving slot")
	_check(lethal_unravel.get_snapshot(2) == {"gauge": 0, "threshold": 12,
		"unravelled": false, "skip_pending": false},
		"lethal: the slain foe's gauge stays empty and unqueued")
	_check(lethal_enemies.get_enemy(1).get("hp") == 30
		and lethal_enemies.get_enemy(3).get("hp") == 30,
		"lethal: no neighbour is retargeted and the roster is not compacted")
	_check(lethal_unravel.get_snapshot(1).get("gauge") == 0
		and lethal_unravel.get_snapshot(3).get("gauge") == 0,
		"lethal: no other gauge is charged")
	_check(lethal_deck.energy == 1 and lethal_deck.discard_pile == [PURLING],
		"lethal: the two-energy cost and single discard still happened once")
	_check(_needle_snapshot(lethal_deck, lethal_party, lethal_enemies, lethal_unravel)
		== _expected_purling(lethal_before, PURLING, 2, 3, 1, 0),
		"lethal: exact deck, party, enemy, gauge and RNG state")


## AC3: the printing's Unravel is one post-hit charge on the surviving target, adds even when
## every hit was Blocked, and a threshold crossing queues exactly one skip for CombatUnravel's
## real consumer without resetting or raising anything itself.
func _test_purling_unravel_threshold() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()

	# 1. One charge only: from five, the base card reaches six, never seven (once per hit).
	var one_party := _needle_party(3)
	var one_enemies := _needle_enemies([{"max_hp": 40, "hp": 40}])
	var one_unravel := _needle_ledger(one_enemies, {1: "normal"})
	_check(one_unravel.apply_unravel(one_enemies, 1, 5),
		"one-charge fixture really starts at five of eight")
	var one_deck := _needle_deck([PURLING], 61111)
	var one_result: Dictionary = resolver.play_purling_barrage(one_deck, one_party,
		one_enemies, one_unravel, PURLING, 1)
	_check(one_result.get("ok") == true and one_result.get("unravel_added") == 1,
		"one-charge: the base printing reports its single Unravel")
	_check(one_unravel.get_snapshot(1) == {"gauge": 6, "threshold": 8,
		"unravelled": false, "skip_pending": false},
		"one-charge: five plus one is six, proving Unravel is not applied per hit")

	# 2. Normal threshold while every hit is Block-absorbed: the survivor still crosses 8/8 and
	#    queues exactly one skip; consumption stays with CombatUnravel.
	var blocked_party := _needle_party(3)
	var blocked_enemies := _needle_enemies([
		{"max_hp": 40, "hp": 40, "block": 100},
	])
	var blocked_unravel := _needle_ledger(blocked_enemies, {1: "normal"})
	_check(blocked_unravel.apply_unravel(blocked_enemies, 1, 7),
		"normal threshold fixture really starts at seven of eight")
	var blocked_deck := _needle_deck([PURLING], 61112)
	var blocked_before := _needle_snapshot(blocked_deck, blocked_party, blocked_enemies,
		blocked_unravel)
	var blocked_result: Dictionary = resolver.play_purling_barrage(blocked_deck, blocked_party,
		blocked_enemies, blocked_unravel, PURLING, 1)
	_check(blocked_result.get("ok") == true
		and blocked_result.get("total_block_absorbed") == 6
		and blocked_result.get("total_hp_loss") == 0,
		"normal threshold: both hits are fully absorbed by Block")
	_check(blocked_enemies.get_enemy(1).get("hp") == 40
		and blocked_enemies.get_enemy(1).get("block") == 94,
		"normal threshold: the fully blocked target is still alive")
	_check(blocked_result.get("unravel_added") == 1
		and blocked_unravel.get_snapshot(1) == {"gauge": 8, "threshold": 8,
			"unravelled": true, "skip_pending": true},
		"normal threshold: a fully blocked survivor still crosses 8/8 and queues one skip")
	_check(_needle_snapshot(blocked_deck, blocked_party, blocked_enemies, blocked_unravel)
		== _expected_purling(blocked_before, PURLING, 1, 3, 2, 1),
		"normal threshold: exact deck, party, enemy, gauge and RNG state")
	_check(blocked_unravel.consume_action_skip(blocked_enemies, 1),
		"normal threshold: the queued skip is still pending for the real consumer")
	_check(blocked_unravel.get_snapshot(1) == {"gauge": 0, "threshold": 12,
		"unravelled": false, "skip_pending": false},
		"normal threshold: consumption resets the gauge and raises the line by four")
	_check(not blocked_unravel.consume_action_skip(blocked_enemies, 1),
		"normal threshold: only one skip was ever queued")

	# 3. Elite threshold with the upgraded printing: eleven plus two clamps to 12/12, one skip.
	var elite_party := _needle_party(3)
	var elite_enemies := _needle_enemies([{"max_hp": 40, "hp": 40}])
	var elite_unravel := _needle_ledger(elite_enemies, {1: "elite"})
	_check(elite_unravel.apply_unravel(elite_enemies, 1, 11),
		"elite threshold fixture really starts at eleven of twelve")
	var elite_deck := _needle_deck([PURLING_PLUS], 61113)
	var elite_result: Dictionary = resolver.play_purling_barrage(elite_deck, elite_party,
		elite_enemies, elite_unravel, PURLING_PLUS, 1)
	_check(elite_result.get("ok") == true and elite_result.get("unravel_added") == 2,
		"elite threshold: the upgraded printing adds its two Unravel once")
	_check(elite_unravel.get_snapshot(1) == {"gauge": 12, "threshold": 12,
		"unravelled": true, "skip_pending": true},
		"elite threshold: eleven plus two clamps to 12/12 and queues one skip")
	_check(elite_unravel.consume_action_skip(elite_enemies, 1),
		"elite threshold: the one queued skip is still pending")
	_check(elite_unravel.get_snapshot(1).get("threshold") == 16,
		"elite threshold: consumption raises the line to sixteen")
	_check(not elite_unravel.consume_action_skip(elite_enemies, 1),
		"elite threshold: no second skip was queued")

	# 4. Boss threshold: fifteen plus the base one reaches 16/16 and queues exactly one skip.
	var boss_party := _needle_party(3)
	var boss_enemies := _needle_enemies([{"max_hp": 40, "hp": 40}])
	var boss_unravel := _needle_ledger(boss_enemies, {1: "boss"})
	_check(boss_unravel.apply_unravel(boss_enemies, 1, 15),
		"boss threshold fixture really starts at fifteen of sixteen")
	var boss_deck := _needle_deck([PURLING], 61114)
	var boss_result: Dictionary = resolver.play_purling_barrage(boss_deck, boss_party,
		boss_enemies, boss_unravel, PURLING, 1)
	_check(boss_result.get("ok") == true and boss_result.get("unravel_added") == 1,
		"boss threshold: the base printing adds its one Unravel once")
	_check(boss_unravel.get_snapshot(1) == {"gauge": 16, "threshold": 16,
		"unravelled": true, "skip_pending": true},
		"boss threshold: fifteen plus one crosses 16/16 and queues one skip")
	_check(boss_unravel.consume_action_skip(boss_enemies, 1),
		"boss threshold: the one queued skip is still pending")
	_check(boss_unravel.get_snapshot(1).get("threshold") == 20,
		"boss threshold: consumption raises the line to twenty")
	_check(not boss_unravel.consume_action_skip(boss_enemies, 1),
		"boss threshold: no second skip was queued")


## AC4: unheld/foreign/relinked IDs, an illegal owner or target, an inactive turn, no energy, a
## malformed roster/status map or an unbound/wrong-roster ledger all refuse before any spend.
func _test_purling_refusals() -> void:
	var resolver := CombatYarnRangerNeedleCards.new()
	var party := _needle_party(3)
	var enemies := _needle_enemies([
		{"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 12},
	])
	var unravel := _needle_ledger(enemies, {1: "normal", 2: "normal", 3: "normal"})
	var deck := _needle_deck([PURLING], 4456)

	_rejected_purling(resolver, null, party, enemies, unravel, PURLING, 1,
		"invalid_request", "null deck")
	_rejected_purling(resolver, deck, null, enemies, unravel, PURLING, 1,
		"invalid_request", "null party")
	_rejected_purling(resolver, deck, party, null, unravel, PURLING, 1,
		"invalid_request", "null enemies")
	_rejected_purling(resolver, deck, party, enemies, null, PURLING, 1,
		"invalid_request", "null ledger")
	var unseeded := _needle_deck([PURLING], 9002)
	unseeded._rng = null
	_rejected_purling(resolver, unseeded, party, enemies, unravel, PURLING, 1,
		"invalid_request", "deck without a seeded RNG")

	# Inactive turn.
	var inactive := CombatDeck.new([PURLING, "needle_filler_a"], _needle_rng(13))
	inactive.hand.append(PURLING)
	_check(not inactive.turn_active and inactive.hand.has(PURLING),
		"inactive fixture really holds a Purling copy outside a turn")
	_rejected_purling(resolver, inactive, party, enemies, unravel, PURLING, 1,
		"inactive_turn", "inactive turn")

	# Wrong IDs: the needle printings, unrelated authentic cards, forged spellings, non-strings.
	var unsupported: Array = [NEEDLE_NOCK, NEEDLE_NOCK_PLUS, NEEDLE_ARROW, NEEDLE_ARROW_PLUS,
		PURLING + "_plus_plus", PURLING_PLUS + "_plus", "yarn_ranger_purling_barrage_+",
		"purling_barrage", PURLING.to_upper(), PURLING + " ", "yarn_ranger_snare_net",
		"yarn_ranger_unspool", "yarn_ranger_wool_bolas", "warden_strike", "",
		StringName(PURLING), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in unsupported:
		_rejected_purling(resolver, deck, party, enemies, unravel, wrong_id, 1,
			"unsupported_card", "unsupported ID " + str(wrong_id))

	# Authentic printings the hand does not hold are still unheld.
	_rejected_purling(resolver, deck, party, enemies, unravel, PURLING_PLUS, 1,
		"card_not_held", "authentic but unheld Purling Barrage+")
	var no_copy := CombatDeck.new(["needle_filler_a", "needle_filler_b", "needle_filler_c",
		"needle_filler_d", "needle_filler_e"], _needle_rng(78))
	_check(no_copy.start_turn() and not no_copy.hand.has(PURLING),
		"missing-copy fixture really lacks the card")
	_rejected_purling(resolver, no_copy, party, enemies, unravel, PURLING, 1,
		"card_not_held", "missing held copy")

	# No energy: two energy are required, so one short refuses.
	var poor := _needle_deck([PURLING], 5567)
	poor.combat_state.energy = 1
	_check(poor.energy == 1 and poor.hand.has(PURLING),
		"short-energy fixture really holds a copy with only one energy")
	_rejected_purling(resolver, poor, party, enemies, unravel, PURLING, 1,
		"insufficient_energy", "one energy short")
	var broke := _needle_deck([PURLING], 5568)
	broke.combat_state.energy = 0
	_rejected_purling(resolver, broke, party, enemies, unravel, PURLING, 1,
		"insufficient_energy", "no energy")

	# Illegal target slots: only enemies 1-3 are real recipients.
	for slot: int in [0, 4, -1, 99]:
		_rejected_purling(resolver, deck, party, enemies, unravel, PURLING, slot,
			"invalid_target", "illegal target slot " + str(slot))
	var dead_target := _needle_enemies([
		{"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 0}, {"max_hp": 12, "hp": 12},
	])
	var dead_ledger := _needle_ledger(dead_target, {1: "normal", 2: "normal", 3: "normal"})
	_rejected_purling(resolver, deck, party, dead_target, dead_ledger, PURLING, 2,
		"target_downed", "slain target slot")

	# Invalid rosters.
	var short_party := CombatParty.new([{"id": "yarn_ranger", "max_hp": 27}])
	_rejected_purling(resolver, deck, short_party, enemies, unravel, PURLING, 1,
		"invalid_roster", "invalid one-hero party")
	_rejected_purling(resolver, deck, party, CombatEnemies.new([]), unravel, PURLING, 1,
		"invalid_roster", "invalid empty enemy roster")

	# Owner absent, in the front/middle seat, or downed grants no authority.
	var no_owner := CombatParty.new([{"id": "rag_duelist", "max_hp": 32},
		{"id": "scarecrow", "max_hp": 34}, {"id": "lantern_monk", "max_hp": 30}])
	_check(no_owner.is_valid() and no_owner.get_hero(3).get("id") == "lantern_monk",
		"absent-owner fixture is a valid three-hero party with no Yarn Ranger")
	_rejected_purling(resolver, deck, no_owner, enemies, unravel, PURLING, 1,
		"owner_missing", "absent Yarn Ranger")
	for misplaced in [1, 2]:
		var displaced := _needle_party(misplaced)
		_check(displaced.get_hero(misplaced).get("id") == "yarn_ranger"
			and not displaced.is_downed(misplaced),
			"misplaced-owner fixture really has a living Yarn Ranger in seat "
			+ str(misplaced))
		_rejected_purling(resolver, deck, displaced, enemies, unravel, PURLING, 1,
			"owner_illegal_position", "Yarn Ranger in seat " + str(misplaced))
	var torn := _needle_party(3)
	_check(torn.apply_damage(3, 27) and torn.is_downed(3),
		"torn-owner fixture really has a downed Yarn Ranger in seat 3")
	_rejected_purling(resolver, deck, torn, enemies, unravel, PURLING, 1,
		"owner_downed", "downed owner")

	# Malformed party/enemy models and status maps fail closed.
	var duplicate := _needle_party(3)
	duplicate._heroes[0]["id"] = "yarn_ranger"
	_check(duplicate.get_hero(1).get("id") == "yarn_ranger"
		and duplicate.get_hero(3).get("id") == "yarn_ranger",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_purling(resolver, deck, duplicate, enemies, unravel, PURLING, 1,
		"invalid_party", "duplicate hero identity")
	var bad_hp := _needle_party(3)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_purling(resolver, deck, bad_hp, enemies, unravel, PURLING, 1,
		"invalid_party", "malformed hero HP")
	var bad_party_statuses := _needle_party(3)
	bad_party_statuses._heroes[2]["statuses"] = "bad"
	_rejected_purling(resolver, deck, bad_party_statuses, enemies, unravel, PURLING, 1,
		"invalid_party", "malformed party status map")
	var bad_attacker := _needle_party(3)
	bad_attacker._heroes[2]["statuses"] = {"forged": 1}
	_rejected_purling(resolver, deck, bad_attacker, enemies, unravel, PURLING, 1,
		"invalid_party", "unsupported attacker status map")
	var blind_attacker := _needle_party(3)
	blind_attacker._heroes[2]["statuses"] = {"blind_next_attack": 1}
	_rejected_purling(resolver, deck, blind_attacker, enemies, unravel, PURLING, 1,
		"invalid_statuses", "attacker Blind token belongs to the miss path")
	for malformed: Variant in ["bad", 4, {"tangled": -1}, {"tangled": "2"}, {"forged": 1},
			{"tangled": 1.5}, {"tangled": true}, {1: 2}]:
		var broken := _needle_enemies([
			{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10},
		])
		broken._enemies[1]["statuses"] = malformed
		var broken_ledger := _needle_ledger(broken, {1: "normal", 2: "normal", 3: "normal"})
		_rejected_purling(resolver, deck, party, broken, broken_ledger, PURLING, 1,
			"invalid_enemies", "malformed target status map " + str(malformed))
	var dodging_target := _needle_enemies([
		{"max_hp": 10, "hp": 10, "statuses": {"dodge_next_attack": 1}},
		{"max_hp": 10, "hp": 10},
	])
	var dodging_ledger := _needle_ledger(dodging_target, {1: "normal", 2: "normal"})
	_rejected_purling(resolver, deck, party, dodging_target, dodging_ledger, PURLING, 1,
		"invalid_statuses", "defender Dodge token belongs to the evasion path")
	var bad_enemy_hp := _needle_enemies([{"max_hp": 10, "hp": 10}])
	bad_enemy_hp._enemies[0]["hp"] = 99
	var bad_enemy_hp_ledger := _needle_ledger(bad_enemy_hp, {1: "normal"})
	_rejected_purling(resolver, deck, party, bad_enemy_hp, bad_enemy_hp_ledger, PURLING, 1,
		"invalid_enemies", "malformed enemy HP")
	var bad_enemy_position := _needle_enemies([{"max_hp": 10, "hp": 10}])
	bad_enemy_position._enemies[0]["position"] = 2
	var bad_enemy_position_ledger := _needle_ledger(bad_enemy_position, {1: "normal"})
	_rejected_purling(resolver, deck, party, bad_enemy_position,
		bad_enemy_position_ledger, PURLING, 1, "invalid_enemies", "malformed enemy slot index")

	# Unbound, wrongly bound or tampered ledgers never authorize a paid Purling play.
	var unbound := CombatUnravel.new()
	_rejected_purling(resolver, deck, party, enemies, unbound, PURLING, 1,
		"invalid_unravel", "unbound ledger")
	var other_enemies := _needle_enemies([{"max_hp": 12, "hp": 12}])
	var wrong_ledger := _needle_ledger(other_enemies, {1: "normal"})
	_rejected_purling(resolver, deck, party, enemies, wrong_ledger, PURLING, 1,
		"invalid_unravel", "ledger bound to another roster")
	var torn_ledger := _needle_ledger(enemies, {1: "normal", 2: "normal", 3: "normal"})
	torn_ledger._gauges[1]["threshold"] = 0
	_rejected_purling(resolver, deck, party, enemies, torn_ledger, PURLING, 1,
		"invalid_unravel", "tampered gauge threshold")

	# A consumed copy cannot be played twice, and a refused attempt never poisons the next one.
	var repeat_enemies := _needle_enemies([{"max_hp": 20, "hp": 20}])
	var repeat_party := _needle_party(3)
	var repeat_ledger := _needle_ledger(repeat_enemies, {1: "normal"})
	var repeat_deck := _needle_deck([PURLING], 8815)
	_check(resolver.play_purling_barrage(repeat_deck, repeat_party, repeat_enemies,
		repeat_ledger, PURLING, 1).get("ok") == true,
		"duplicate-play fixture really casts once")
	_check(repeat_deck.energy == 1 and repeat_deck.discard_pile == [PURLING],
		"duplicate-play fixture really spent two energy and discarded the copy")
	var repeat_after := _needle_snapshot(repeat_deck, repeat_party, repeat_enemies, repeat_ledger)
	var replay: Dictionary = resolver.play_purling_barrage(repeat_deck, repeat_party,
		repeat_enemies, repeat_ledger, PURLING, 1)
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		"replay: the consumed copy is refused")
	_check(_needle_snapshot(repeat_deck, repeat_party, repeat_enemies, repeat_ledger)
		== repeat_after, "replay: the refusal changes no energy, card, HP or gauge")

	var retry_deck := _needle_deck([PURLING_PLUS], 6124)
	var retry_party := _needle_party(3)
	var retry_enemies := _needle_enemies([{"max_hp": 20, "hp": 20}])
	var retry_ledger := _needle_ledger(retry_enemies, {1: "boss"})
	_rejected_purling(resolver, retry_deck, retry_party, retry_enemies, retry_ledger,
		"yarn_ranger_snare_net", 1, "unsupported_card", "retry: wrong card first")
	_rejected_purling(resolver, retry_deck, retry_party, retry_enemies, retry_ledger,
		PURLING_PLUS, 0, "invalid_target", "retry: illegal slot second")
	var retry_result: Dictionary = resolver.play_purling_barrage(retry_deck, retry_party,
		retry_enemies, retry_ledger, PURLING_PLUS, 1)
	_check(retry_result.get("ok") == true and retry_deck.energy == 1
		and retry_enemies.get_enemy(1).get("hp") == 12
		and retry_ledger.get_snapshot(1).get("gauge") == 2,
		"retry: the authentic play then succeeds exactly once on the boss gauge")
	_check(retry_ledger.get_snapshot(1).get("threshold") == 16,
		"retry: the boss seat keeps the service's own sixteen-point threshold")


func _needle_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero party drawn from the V3 roster IDs, with the 27 HP Yarn Ranger in the
## named seat so FROM 2-3 and the front-seat refusal are both exercised for real.
func _needle_party(ranger_position: int) -> CombatParty:
	var heroes: Array = [
		{"id": "rag_duelist", "max_hp": 32},
		{"id": "scarecrow", "max_hp": 34},
		{"id": "lantern_monk", "max_hp": 30},
	]
	var ranger: Dictionary = heroes[ranger_position - 1]
	ranger["id"] = "yarn_ranger"
	ranger["max_hp"] = 27
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_hero(ranger_position).get("id") == "yarn_ranger"
		and party.get_hero(ranger_position).get("hp") == 27,
		"valid three-hero party with a living Yarn Ranger in seat " + str(ranger_position))
	return party


## Real enemy slots built through the model's own state APIs; HP loss and Block come from the model.
func _needle_enemies(specs: Array) -> CombatEnemies:
	var definitions: Array = []
	for index in range(specs.size()):
		var definition := {"id": "needle_fixture_foe_" + str(index + 1),
			"max_hp": int(specs[index]["max_hp"])}
		if specs[index].has("statuses"):
			definition["statuses"] = specs[index]["statuses"]
		definitions.append(definition)
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == specs.size(),
		"needle fixture builds a real indexed enemy roster")
	for index in range(specs.size()):
		var lost: int = int(specs[index]["max_hp"]) - int(specs[index]["hp"])
		if lost > 0:
			_check(enemies.apply_damage(index + 1, lost),
				"needle fixture foe " + str(index + 1) + " really lost HP")
		var block := int(specs[index].get("block", 0))
		if block > 0:
			_check(enemies.gain_block(index + 1, block),
				"needle fixture foe " + str(index + 1) + " really gained Block")
	return enemies


## A real ledger bound to the exact encounter roster with explicit per-seat tiers.
func _needle_ledger(enemies: CombatEnemies, tiers: Dictionary) -> CombatUnravel:
	var unravel := CombatUnravel.new()
	_check(unravel.bind_roster(enemies, tiers),
		"the Unravel ledger binds the exact enemy roster")
	return unravel


## A genuine seeded six-card turn that really holds every requested copy. Five of six cards are
## drawn, so one requested copy can still sit in the draw pile; that copy is swapped with a filler
## already in hand without changing deck size, energy or RNG state.
func _needle_deck(card_ids: Array, seed_value: int) -> CombatDeck:
	var ids: Array[String] = []
	var wanted: Array[String] = []
	for card_id in card_ids:
		ids.append(str(card_id))
		wanted.append(str(card_id))
	var filler := 0
	while ids.size() < 6:
		ids.append("needle_filler_" + str(filler))
		filler += 1
	var deck := CombatDeck.new(ids, _needle_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"needle fixture starts a real three-energy shared turn")
	for card_id in wanted:
		var pending: int = deck.draw_pile.find(card_id)
		if pending < 0:
			continue
		for index in range(deck.hand.size()):
			if not wanted.has(deck.hand[index]):
				deck.draw_pile[pending] = deck.hand[index]
				deck.hand[index] = card_id
				break
	for card_id in wanted:
		_check(deck.hand.count(card_id) == wanted.count(card_id),
			card_id + ": the fixture hand genuinely holds its copies")
	return deck


## The complete mutable combat state: deck, party, enemies, every Unravel gauge and the run RNG.
func _needle_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: CombatUnravel) -> Dictionary:
	var snapshot: Dictionary = {
		"deck_present": deck != null, "party_present": party != null,
		"enemies_present": enemies != null, "unravel_present": unravel != null,
	}
	if deck != null:
		snapshot["turn"] = deck.turn_active
		snapshot["energy"] = deck.energy
		snapshot["state_energy"] = deck.combat_state.energy
		snapshot["state_turn"] = deck.combat_state.player_turn_active
		snapshot["hand"] = deck.hand.duplicate()
		snapshot["draw"] = deck.draw_pile.duplicate()
		snapshot["discard"] = deck.discard_pile.duplicate()
		snapshot["rng_state"] = deck._rng.state if deck._rng != null else -1
	if party != null:
		snapshot["party"] = party.get_heroes()
		snapshot["party_valid"] = party.is_valid()
	if enemies != null:
		snapshot["enemies"] = enemies.get_enemies()
		snapshot["enemies_valid"] = enemies.is_valid()
	if unravel != null:
		var gauges: Dictionary = {}
		for position in [1, 2, 3]:
			gauges[position] = unravel.get_snapshot(position)
		snapshot["gauges"] = gauges
	return snapshot


## The exact post-transaction state: one energy, one discarded copy, Block-before-HP damage and the
## printed Unravel charged onto the chosen surviving foe only.
func _expected_needle(before: Dictionary, card_id: String, target: int, damage: int,
		unravel_added: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	_check(expected.get("deck_present") == true and expected.get("enemies_present") == true,
		"expected needle snapshot is backed by real objects")
	expected["energy"] = int(expected["energy"]) - 1
	expected["state_energy"] = int(expected["state_energy"]) - 1
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) >= 1, "expected snapshot: a played copy is really held")
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var enemy: Dictionary = expected["enemies"][target - 1]
	var absorbed: int = mini(int(enemy["block"]), damage)
	enemy["block"] = int(enemy["block"]) - absorbed
	enemy["hp"] = maxi(0, int(enemy["hp"]) - (damage - absorbed))
	if int(enemy["hp"]) > 0 and unravel_added > 0:
		var gauge: Dictionary = expected["gauges"][target]
		if not (bool(gauge["unravelled"]) and bool(gauge["skip_pending"])):
			var charged: int = int(gauge["gauge"]) + unravel_added
			if charged >= int(gauge["threshold"]):
				charged = int(gauge["threshold"])
				gauge["unravelled"] = true
				gauge["skip_pending"] = true
			gauge["gauge"] = charged
	return expected


## The exact post-Purling state: two energy, one discarded copy, each independent hit spending
## Block before HP on the chosen target, and the printed Unravel charged once on a survivor.
func _expected_purling(before: Dictionary, card_id: String, target: int, damage_per_hit: int,
		hit_count: int, unravel_added: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	_check(expected.get("deck_present") == true and expected.get("enemies_present") == true,
		"expected Purling snapshot is backed by real objects")
	expected["energy"] = int(expected["energy"]) - 2
	expected["state_energy"] = int(expected["state_energy"]) - 2
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) >= 1,
		"expected Purling snapshot: a played copy is really held")
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var enemy: Dictionary = expected["enemies"][target - 1]
	for index in range(hit_count):
		var absorbed: int = mini(int(enemy["block"]), damage_per_hit)
		enemy["block"] = int(enemy["block"]) - absorbed
		enemy["hp"] = maxi(0, int(enemy["hp"]) - (damage_per_hit - absorbed))
	if int(enemy["hp"]) > 0 and unravel_added > 0:
		var gauge: Dictionary = expected["gauges"][target]
		if not (bool(gauge["unravelled"]) and bool(gauge["skip_pending"])):
			var charged: int = int(gauge["gauge"]) + unravel_added
			if charged >= int(gauge["threshold"]):
				charged = int(gauge["threshold"])
				gauge["unravelled"] = true
				gauge["skip_pending"] = true
			gauge["gauge"] = charged
	return expected


func _rejected_purling(resolver: CombatYarnRangerNeedleCards, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, unravel: CombatUnravel, card_id: Variant,
		target: int, reason: String, label: String) -> void:
	var before := _needle_snapshot(deck, party, enemies, unravel)
	var result: Dictionary = resolver.play_purling_barrage(deck, party, enemies, unravel,
		card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_needle_snapshot(deck, party, enemies, unravel) == before,
		label + ": unchanged energy, hand, piles, turn, party, enemies, gauges and RNG")


func _rejected_needle(resolver: CombatYarnRangerNeedleCards, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, unravel: CombatUnravel, card_id: Variant,
		target: int, reason: String, label: String) -> void:
	var before := _needle_snapshot(deck, party, enemies, unravel)
	var result: Dictionary = resolver.play_card(deck, party, enemies, unravel, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_needle_snapshot(deck, party, enemies, unravel) == before,
		label + ": unchanged energy, hand, piles, turn, party, enemies, gauges and RNG")
