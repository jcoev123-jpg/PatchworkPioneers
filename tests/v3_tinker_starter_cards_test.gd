extends SceneTree
## V3-1 Tinker starter-card catalog contract.
## Data only: these four bases and their "+" printings are authored starter data for the Tinker.
## Nothing here claims the IDs are admitted to a live hand, the active three-hero deck, reward
## offers or a combat resolver; a later wiring task owns that. Combat Scrap is a COMBAT counter,
## never the run's wallet `scraps`; nothing in this file is ever granted by a lookup.

const V3TinkerStarterCards = preload("res://data/cards/v3_tinker_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const V3TinkerPoolCards = preload("res://data/cards/v3_tinker_pool_cards.gd")

const COG := "tinker_v3_cog_shot"
const COG_PLUS := "tinker_v3_cog_shot_plus"
const WARD := "tinker_v3_casing_ward"
const WARD_PLUS := "tinker_v3_casing_ward_plus"
const BOMB := "tinker_v3_scrap_bomb"
const BOMB_PLUS := "tinker_v3_scrap_bomb_plus"
const TUNE := "tinker_v3_tune_up"
const TUNE_PLUS := "tinker_v3_tune_up_plus"
const ALL_PRINTINGS: Array[String] = [COG, COG_PLUS, WARD, WARD_PLUS, BOMB, BOMB_PLUS,
	TUNE, TUNE_PLUS]
## Authored starter order: one copy of each base, no upgrades.
const STARTER_ORDER: Array[String] = [COG, WARD, BOMB, TUNE]

## The only effect keys these four starters may print. Anything else would be an invented
## status, resource or combat-state descriptor.
const ALLOWED_EFFECT_KEYS: Array[String] = [
	"damage", "block", "draw", "combat_scrap_gain", "living_targets_only",
]

## The eight authored v3 Tinker reward-pool bases whose records must stay untouched.
const V3_POOL_BASE_IDS: Array[String] = [
	"tinker_v3_brass_casing",
	"tinker_v3_gear_brace",
	"tinker_v3_spare_screws",
	"tinker_v3_spring_clamp",
	"tinker_v3_wind_up_turret",
	"tinker_v3_overload",
	"tinker_v3_jury_rig",
	"tinker_v3_scrapstorm",
]

## The unchanged legacy Tinker entries of the shared 12-card starting deck.
const LEGACY_TINKER_STARTERS: Dictionary = {
	"tinker_pop_shot": {"copies": 2, "effects": {"damage": 5}},
	"tinker_scrap_bomb": {"copies": 1, "effects": {"damage": 4}},
	"tinker_tune_up": {"copies": 1, "effects": {"draw": 1}},
}

const ART_DIR := "res://assets/paper/cards/"

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_eight_printings()
	_test_look_descriptors()
	_test_starter_projection()
	_test_legacy_and_pool_unchanged()
	_test_not_reward_offered()
	_test_detached_records()
	_test_invalid_and_upgraded_ids()
	_test_deterministic_and_rng_free()
	if failures.is_empty():
		print("v3_tinker_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_tinker_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## All v3 Tinker reward printings (bases plus their '+' partners), derived from the pool's own
## base list and upgrade links; the pool exposes no single enumeration method.
func _v3_pool_card_ids(pool: Variant) -> Array[String]:
	var ids: Array[String] = []
	for base_id: String in pool.get_pool_card_ids():
		ids.append(base_id)
		var plus_id: String = pool.get_upgrade_id(base_id)
		if not plus_id.is_empty():
			ids.append(plus_id)
	return ids


## Literal, independent expectations for all eight printings: every ID, owner, target, FROM/TO,
## cost, effect, art path, copy count, reward flag and upgrade link written out by hand rather
## than read back from the catalog under test.
func _expected_printings() -> Dictionary:
	return {
		COG: {
			"id": COG,
			"display_name": "Cog Shot",
			"owner": "tinker",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 5, "combat_scrap_gain": 1},
			"illustration_path": ART_DIR + "tinker_v3_cog_shot.png",
			"starting_copies": 1,
			"reward_eligible": false,
			"upgrade_id": COG_PLUS,
		},
		COG_PLUS: {
			"id": COG_PLUS,
			"display_name": "Cog Shot+",
			"owner": "tinker",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 7, "combat_scrap_gain": 1},
			"illustration_path": ART_DIR + "tinker_v3_cog_shot.png",
			"starting_copies": 0,
			"reward_eligible": false,
			"upgrade_of": COG,
		},
		WARD: {
			"id": WARD,
			"display_name": "Casing Ward",
			"owner": "tinker",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 5, "combat_scrap_gain": 1},
			"illustration_path": ART_DIR + "tinker_v3_casing_ward.png",
			"starting_copies": 1,
			"reward_eligible": false,
			"upgrade_id": WARD_PLUS,
		},
		WARD_PLUS: {
			"id": WARD_PLUS,
			"display_name": "Casing Ward+",
			"owner": "tinker",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "self",
			"to_positions": [],
			"effects": {"block": 7, "combat_scrap_gain": 1},
			"illustration_path": ART_DIR + "tinker_v3_casing_ward.png",
			"starting_copies": 0,
			"reward_eligible": false,
			"upgrade_of": WARD,
		},
		BOMB: {
			"id": BOMB,
			"display_name": "Scrap Bomb",
			"owner": "tinker",
			"cost": 2,
			"from_positions": [3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 4, "combat_scrap_gain": 1, "living_targets_only": true},
			"illustration_path": ART_DIR + "tinker_v3_scrap_bomb.png",
			"starting_copies": 1,
			"reward_eligible": false,
			"upgrade_id": BOMB_PLUS,
		},
		BOMB_PLUS: {
			"id": BOMB_PLUS,
			"display_name": "Scrap Bomb+",
			"owner": "tinker",
			"cost": 2,
			"from_positions": [3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 6, "combat_scrap_gain": 1, "living_targets_only": true},
			"illustration_path": ART_DIR + "tinker_v3_scrap_bomb.png",
			"starting_copies": 0,
			"reward_eligible": false,
			"upgrade_of": BOMB,
		},
		TUNE: {
			"id": TUNE,
			"display_name": "Tune Up",
			"owner": "tinker",
			"cost": 0,
			"from_positions": [1, 2, 3],
			"target_kind": "none",
			"to_positions": [],
			"effects": {"draw": 1, "combat_scrap_gain": 1},
			"illustration_path": ART_DIR + "tinker_v3_tune_up.png",
			"starting_copies": 1,
			"reward_eligible": false,
			"upgrade_id": TUNE_PLUS,
		},
		TUNE_PLUS: {
			"id": TUNE_PLUS,
			"display_name": "Tune Up+",
			"owner": "tinker",
			"cost": 0,
			"from_positions": [1, 2, 3],
			"target_kind": "none",
			"to_positions": [],
			"effects": {"draw": 2, "combat_scrap_gain": 1},
			"illustration_path": ART_DIR + "tinker_v3_tune_up.png",
			"starting_copies": 0,
			"reward_eligible": false,
			"upgrade_of": TUNE,
		},
	}


## AC1: all eight printings compared field by field against the independent literal table.
func _test_all_eight_printings() -> void:
	var catalog := V3TinkerStarterCards.new()
	var expected: Dictionary = _expected_printings()
	_check(expected.size() == 8, "the literal table enumerates eight authored printings")
	_check(ALL_PRINTINGS.size() == 8, "the fixture names eight authored printings")
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(not all_ids.is_empty(), "catalog enumeration is populated (precondition)")
	_check(all_ids.size() == 8, "the starter catalog holds exactly its eight printings")
	for card_id: String in ALL_PRINTINGS:
		_check(expected.has(card_id), card_id + " is in the literal table")
		_check(all_ids.has(card_id), card_id + " is discoverable through get_all_card_ids")
		_check(catalog.has_card(card_id), card_id + " is authored")
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " definition exists")
		if record.is_empty():
			continue
		var row: Dictionary = expected[card_id]
		for field: String in row:
			_check(record.has(field) and record.get(field) == row[field],
				card_id + " matches " + field + ": " + str(record.get(field)))
		_check(record.size() == row.size(), card_id + " has exactly the documented fields")
		# No silent extra fields, no reward-pool metadata, no hero statistics.
		for forbidden: String in ["rarity", "max_hp", "passive", "is_upgrade", "base_id"]:
			_check(not record.has(forbidden), card_id + " carries no " + forbidden)
		_check(record.get("owner") == "tinker", card_id + " is owned by the Tinker")
		_check(record.get("display_name") is String, card_id + " has a string display name")
		_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
			card_id + " has both position arrays")
		_check(record.get("effects") is Dictionary, card_id + " has an effect dictionary")
		_check(typeof(record.get("cost")) == TYPE_INT, card_id + " prints an integer cost")
		_check(typeof(record.get("starting_copies")) == TYPE_INT,
			card_id + " prints an integer copy count")
		_check(record.get("starting_copies") >= 0, card_id + " never prints a negative copy count")
		_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
			and record.get("reward_eligible") == false, card_id + " is never reward eligible")
		_check(record.get("illustration_path") is String
			and str(record.get("illustration_path")).begins_with(ART_DIR),
			card_id + " keeps a normal res:// art path")
		var effects: Dictionary = record.get("effects")
		_check(effects.size() == (row["effects"] as Dictionary).size(),
			card_id + " prints exactly the documented effects")
		for key: String in effects:
			_check(ALLOWED_EFFECT_KEYS.has(key),
				card_id + " invents no new status or resource key: " + key)
			if key == "living_targets_only":
				_check(typeof(effects[key]) == TYPE_BOOL, card_id + " prints a boolean flag")
			else:
				_check(typeof(effects[key]) == TYPE_INT, card_id + " prints an integer " + key)
				_check(int(effects[key]) > 0, card_id + " prints a positive " + key)
		# Authored legality: every named slot is one of the three party positions.
		for position: Variant in record.get("from_positions"):
			_check(typeof(position) == TYPE_INT and int(position) >= 1 and int(position) <= 3,
				card_id + " FROM position is one of 1..3: " + str(position))
		for position: Variant in record.get("to_positions"):
			_check(typeof(position) == TYPE_INT and int(position) >= 1 and int(position) <= 3,
				card_id + " TO position is one of 1..3: " + str(position))
		_check(not record.get("from_positions").is_empty(),
			card_id + " declares at least one legal FROM slot")
		if record.get("target_kind") == "enemy_single" \
				or record.get("target_kind") == "enemy_all":
			_check(not record.get("to_positions").is_empty(),
				card_id + " names at least one enemy slot")
		else:
			_check(record.get("to_positions").is_empty(),
				card_id + " names no enemy slot for a self or none target")
		# Stable snake_case IDs with the Tinker's v3 prefix.
		_check(card_id.begins_with("tinker_v3_"), card_id + " carries the v3 Tinker prefix")
		_check(card_id == card_id.to_lower(), card_id + " is lower case")
		_check(not card_id.ends_with("+") and not card_id.contains(" "),
			card_id + " uses a plain snake_case spelling")
		var snake := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
		_check(snake.search(card_id) != null, card_id + " is snake_case only")
		# Links: exactly one upgrade each way, and an upgrade can never upgrade again.
		if card_id.ends_with("_plus"):
			var base_id: String = card_id.trim_suffix("_plus")
			_check(record.get("upgrade_of") == base_id, card_id + " names its base")
			_check(not record.has("upgrade_id"), card_id + " has no onward upgrade link")
			_check(catalog.has_card(base_id), card_id + " has an authored base")
			_check(catalog.get_upgrade_id(base_id) == card_id,
				base_id + " maps to its authored upgrade")
			_check(catalog.get_upgrade_id(card_id) == "", card_id + " cannot upgrade again")
			_check(not catalog.has_card(card_id + "_plus"),
				card_id + "_plus is not authored")
			_check(record.get("illustration_path")
				== catalog.get_definition(base_id).get("illustration_path"),
				card_id + " shares its base illustration path")
		else:
			_check(record.get("upgrade_id") == card_id + "_plus",
				card_id + " carries its own upgrade link")
			_check(not record.has("upgrade_of"), card_id + " is not itself an upgrade")
			_check(catalog.get_upgrade_id(card_id + "_plus") == "",
				card_id + "_plus is terminal")
	# Every enumerated ID has a literal row, and no row goes unserved.
	for card_id: String in all_ids:
		_check(expected.has(card_id), card_id + " belongs to the literal table")
	# Each pair shares one art path, and no two starters share a picture.
	var art_paths: Array[String] = []
	for base_id: String in STARTER_ORDER:
		var base: Dictionary = catalog.get_definition(base_id)
		_check(not base.is_empty(), base_id + " base record is loaded")
		if base.is_empty():
			continue
		art_paths.append(str(base.get("illustration_path")))
		_check(base.get("illustration_path")
			== ART_DIR + base_id + ".png", base_id + " uses its own normal art path")
	for path: String in art_paths:
		_check(art_paths.count(path) == 1, path + " is unique to its own starter")


## The scrap-kit look descriptors, printed magnitudes only, no live resolution claimed.
func _test_look_descriptors() -> void:
	var catalog := V3TinkerStarterCards.new()

	# Cog Shot: the cog-loaded blunderbuss salvages one Combat Scrap on a confirmed shot.
	for suffix: String in ["", "_plus"]:
		var cog: Dictionary = catalog.get_definition(COG + suffix)
		var cog_effects: Dictionary = cog.get("effects")
		_check(cog.get("target_kind") == "enemy_single" and cog.get("to_positions") == [1, 2, 3],
			"Cog Shot aims at one enemy in any enemy slot" + suffix)
		_check(cog.get("from_positions") == [2, 3],
			"Cog Shot fires from the middle or back slot" + suffix)
		_check(cog_effects.get("combat_scrap_gain") == 1,
			"Cog Shot salvages exactly one Combat Scrap" + suffix)
		_check(cog_effects.get("damage") is int and not cog_effects.has("block")
			and not cog_effects.has("draw"),
			"Cog Shot only shoots; it neither Blocks nor draws" + suffix)
		_check(not cog_effects.has("living_targets_only"),
			"Cog Shot is a single-target shot, not an area blast" + suffix)
	_check(catalog.get_definition(COG).get("cost") == 1
		and catalog.get_definition(COG_PLUS).get("cost") == 1,
		"Cog Shot and Cog Shot+ both cost one energy")
	_check(catalog.get_definition(COG).get("effects")
		== {"damage": 5, "combat_scrap_gain": 1},
		"Cog Shot prints the legacy five-damage Pop Shot budget plus one Combat Scrap")
	_check(catalog.get_definition(COG_PLUS).get("effects")
		== {"damage": 7, "combat_scrap_gain": 1},
		"Cog Shot+ prints the legacy seven-damage budget plus one Combat Scrap")

	# Casing Ward: salvaged metal folded into personal Block for the Tinker itself.
	for suffix: String in ["", "_plus"]:
		var ward: Dictionary = catalog.get_definition(WARD + suffix)
		var ward_effects: Dictionary = ward.get("effects")
		_check(ward.get("target_kind") == "self" and ward.get("to_positions") == [],
			"Casing Ward targets the Tinker itself and no enemy slot" + suffix)
		_check(ward.get("from_positions") == [1, 2, 3],
			"Casing Ward works from any hero slot" + suffix)
		_check(ward.get("target_kind") != "ally_single"
			and ward.get("target_kind") != "party_all",
			"Casing Ward is personal Block, not an ally or whole-party shield" + suffix)
		_check(ward_effects.get("block") is int
			and ward_effects.get("combat_scrap_gain") == 1,
			"Casing Ward prints integer Block plus one Combat Scrap" + suffix)
		_check(not ward_effects.has("damage") and not ward_effects.has("draw"),
			"Casing Ward neither strikes nor draws" + suffix)
	_check(catalog.get_definition(WARD).get("cost") == 1
		and catalog.get_definition(WARD_PLUS).get("cost") == 1,
		"Casing Ward and Casing Ward+ both cost one energy")
	_check(catalog.get_definition(WARD).get("effects")
		== {"block": 5, "combat_scrap_gain": 1},
		"Casing Ward uses the authored V3 Tinker Gear Brace five-Block scale")
	_check(catalog.get_definition(WARD_PLUS).get("effects")
		== {"block": 7, "combat_scrap_gain": 1},
		"Casing Ward+ uses the authored V3 Tinker Gear Brace seven-Block scale")

	# Scrap Bomb: back-seat powder charge into the enemy line, unchanged 4/6 damage budget.
	for suffix: String in ["", "_plus"]:
		var bomb: Dictionary = catalog.get_definition(BOMB + suffix)
		var bomb_effects: Dictionary = bomb.get("effects")
		_check(bomb.get("target_kind") == "enemy_all" and bomb.get("to_positions") == [1, 2, 3],
			"Scrap Bomb hits the authored three enemy slots" + suffix)
		_check(bomb.get("from_positions") == [3],
			"Scrap Bomb is thrown from the back slot only" + suffix)
		_check(bomb_effects.get("living_targets_only") is bool
			and bomb_effects.get("living_targets_only") == true,
			"Scrap Bomb skips downed enemies instead of hitting empty slots" + suffix)
		_check(bomb_effects.get("combat_scrap_gain") == 1,
			"Scrap Bomb salvages exactly one Combat Scrap" + suffix)
		_check(not bomb_effects.has("draw") and not bomb_effects.has("block"),
			"Scrap Bomb neither draws nor Blocks" + suffix)
		# No automatic fourth target: the printed candidate slots stay the three party seats.
		_check(bomb.get("to_positions").size() == 3, "Scrap Bomb names exactly three slots" + suffix)
		_check(not bomb.get("to_positions").has(4),
			"Scrap Bomb introduces no fourth target" + suffix)
		_check(not bomb_effects.has("targets") and not bomb_effects.has("hit_count")
			and not bomb_effects.has("extra_targets"),
			"Scrap Bomb invents no extra target count" + suffix)
	_check(catalog.get_definition(BOMB).get("cost") == 2
		and catalog.get_definition(BOMB_PLUS).get("cost") == 2,
		"Scrap Bomb and Scrap Bomb+ both cost two energy")
	_check(catalog.get_definition(BOMB).get("effects")
		== {"damage": 4, "combat_scrap_gain": 1, "living_targets_only": true},
		"Scrap Bomb keeps the legacy four-damage budget plus one Combat Scrap")
	_check(catalog.get_definition(BOMB_PLUS).get("effects")
		== {"damage": 6, "combat_scrap_gain": 1, "living_targets_only": true},
		"Scrap Bomb+ keeps the legacy six-damage budget plus one Combat Scrap")

	# Tune Up: the backpack yields a bolt and a card.
	for suffix: String in ["", "_plus"]:
		var tune: Dictionary = catalog.get_definition(TUNE + suffix)
		var tune_effects: Dictionary = tune.get("effects")
		_check(tune.get("target_kind") == "none" and tune.get("to_positions") == [],
			"Tune Up targets nothing and names no enemy slot" + suffix)
		_check(tune.get("from_positions") == [1, 2, 3],
			"Tune Up works from any hero slot" + suffix)
		_check(tune_effects.get("draw") is int
			and tune_effects.get("combat_scrap_gain") == 1,
			"Tune Up prints an integer draw plus one Combat Scrap" + suffix)
		_check(not tune_effects.has("damage") and not tune_effects.has("block"),
			"Tune Up neither strikes nor Blocks" + suffix)
	_check(catalog.get_definition(TUNE).get("cost") == 0
		and catalog.get_definition(TUNE_PLUS).get("cost") == 0,
		"Tune Up and Tune Up+ are free")
	_check(catalog.get_definition(TUNE).get("effects")
		== {"draw": 1, "combat_scrap_gain": 1},
		"Tune Up keeps the legacy draw-one budget plus one Combat Scrap")
	_check(catalog.get_definition(TUNE_PLUS).get("effects")
		== {"draw": 2, "combat_scrap_gain": 1},
		"Tune Up+ keeps the legacy draw-two budget plus one Combat Scrap")

	# The kit stays four distinct shapes: one single shot, one self ward, one blast, one tune.
	_check(catalog.get_definition(COG).get("target_kind") == "enemy_single"
		and catalog.get_definition(WARD).get("target_kind") == "self"
		and catalog.get_definition(BOMB).get("target_kind") == "enemy_all"
		and catalog.get_definition(TUNE).get("target_kind") == "none",
		"each starter keeps its own target shape")

	# Combat Scrap is a combat counter: never the run wallet, never a spend or a lookup side effect.
	for card_id: String in ALL_PRINTINGS:
		var effects: Dictionary = catalog.get_definition(card_id).get("effects")
		for wallet_key: String in ["scraps", "scrap_cost", "scrap_spend", "wallet", "gold",
				"combat_scrap_spend", "combat_scrap_spend_max"]:
			_check(not effects.has(wallet_key),
				card_id + " never models the run wallet or a scrap price: " + wallet_key)
	_check(not catalog.has_method("resolve"), "catalog exposes no live resolution")
	_check(not catalog.has_method("play_card"), "catalog exposes no paid play")
	_check(not catalog.has_method("spend_scraps"), "catalog exposes no wallet spending")
	_check(not catalog.has_method("gain_combat_scrap"),
		"lookups cannot grant Combat Scrap on their own")


## AC1: the dedicated hero projection: each named base exactly once in authored order, never an
## upgrade and never a reward card. The shared 12-card deck is checked separately.
func _test_starter_projection() -> void:
	var catalog := V3TinkerStarterCards.new()
	var expected: Dictionary = _expected_printings()
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	_check(not starter_ids.is_empty() and not deck.is_empty(),
		"starter projection is populated before counting")
	_check(starter_ids == STARTER_ORDER,
		"get_starter_ids names the four authored bases in authored order: " + str(starter_ids))
	_check(deck == STARTER_ORDER,
		"get_starting_deck holds one copy of each base in authored order: " + str(deck))
	_check(starter_ids.size() == 4, "exactly four starter IDs")
	_check(deck.size() == 4, "exactly four starting copies")
	for base_id: String in STARTER_ORDER:
		_check(starter_ids.count(base_id) == 1, base_id + " appears once in get_starter_ids")
		_check(deck.count(base_id) == 1, base_id + " appears once in the dedicated deck")
		_check(catalog.get_definition(base_id).get("starting_copies") == 1,
			base_id + " starts with one copy")
		var plus_id: String = base_id + "_plus"
		_check(not starter_ids.has(plus_id), plus_id + " is not a starter id")
		_check(not deck.has(plus_id), plus_id + " is not in the dedicated starting deck")
		_check(catalog.get_definition(plus_id).get("starting_copies") == 0,
			plus_id + " adds no starting copy")
		_check(not starter_ids.has(base_id + "_plus_plus"),
			base_id + " proposes no forged plus-of-plus starter")
	for id: String in starter_ids:
		_check(STARTER_ORDER.has(id), id + " in get_starter_ids is one of the four authored bases")
	for id: String in deck:
		_check(STARTER_ORDER.has(id), id + " in the dedicated deck is one of the four bases")
		_check(not id.ends_with("_plus"), id + " is never an upgraded printing")
	# Membership is a local contract: nothing from another catalog leaks into either projection.
	var starter := StarterCards.new()
	var pool := V3TinkerPoolCards.new()
	var pool_ids: Array[String] = _v3_pool_card_ids(pool)
	_check(not pool_ids.is_empty(), "v3 Tinker reward enumeration is populated (precondition)")
	_check(pool_ids.has("tinker_v3_brass_casing_plus"),
		"v3 Tinker reward enumeration includes a real '+' printing (precondition)")
	for active_id: String in starter.get_all_card_ids():
		_check(not starter_ids.has(active_id),
			active_id + " belongs to the active starter catalog, not this projection")
		_check(not deck.has(active_id),
			active_id + " is not proposed in the dedicated starting deck")
	for pool_id: String in pool_ids:
		_check(not starter_ids.has(pool_id), pool_id + " is a reward card, not a starter")
		_check(not deck.has(pool_id), pool_id + " is not in the dedicated starting deck")
		_check(not expected.has(pool_id), pool_id + " is not one of the eight printings")
	for card_id: String in ALL_PRINTINGS:
		_check(not starter.has_card(card_id),
			card_id + " has not entered the legacy StarterCards catalog")
		_check(not pool.has_card(card_id), card_id + " has not entered the V3 Tinker pool")
		_check(not starter.get_starting_deck().has(card_id),
			card_id + " is absent from the shared starting deck")


## AC3: the legacy shared deck and the eight V3 Tinker reward records stay exactly as authored.
func _test_legacy_and_pool_unchanged() -> void:
	var catalog := V3TinkerStarterCards.new()
	var starter := StarterCards.new()
	var pool := V3TinkerPoolCards.new()

	# The shared 12-card deck still matches its authored membership and order.
	var active_deck: Array[String] = starter.get_starting_deck()
	_check(not active_deck.is_empty(), "active starting deck is populated (precondition)")
	var raw_json: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored_deck: Variant = JSON.parse_string(raw_json)
	_check(authored_deck is Array, "authored starter deck parses (precondition)")
	if authored_deck is Array:
		_check(active_deck == authored_deck,
			"active three-hero starting deck still matches its authored membership and order")
		_check(not (authored_deck as Array).is_empty(),
			"authored starter deck is non-empty (precondition)")
	for starter_id: String in LEGACY_TINKER_STARTERS:
		var row: Dictionary = LEGACY_TINKER_STARTERS[starter_id]
		var record: Dictionary = starter.get_definition(starter_id)
		_check(not record.is_empty(), starter_id + " remains a StarterCards definition")
		_check(record.get("owner") == "tinker", starter_id + " remains Tinker-owned")
		_check(record.get("effects") == row["effects"], starter_id + " printed effects unchanged")
		_check(record.get("starting_copies") == row["copies"],
			starter_id + " catalog multiplicity unchanged")
		_check(active_deck.count(starter_id) == row["copies"],
			starter_id + " runtime deck copies unchanged")
	_check(starter.get_definition("tinker_pop_shot_plus").get("effects") == {"damage": 7},
		"legacy Pop Shot+ keeps its seven damage")
	_check(starter.get_definition("tinker_scrap_bomb_plus").get("effects") == {"damage": 6},
		"legacy Scrap Bomb+ keeps its six damage")
	_check(starter.get_definition("tinker_tune_up_plus").get("effects") == {"draw": 2},
		"legacy Tune Up+ keeps its draw two")

	# Snapshot every legacy record, exercise the new catalog, then prove nothing moved.
	var legacy_snapshot: Dictionary = {}
	for legacy_id: String in starter.get_all_card_ids():
		legacy_snapshot[legacy_id] = starter.get_definition(legacy_id)
	var pool_snapshot: Dictionary = {}
	for pool_id: String in _v3_pool_card_ids(pool):
		pool_snapshot[pool_id] = pool.get_definition(pool_id)
	_check(not pool_snapshot.is_empty(), "v3 Tinker reward snapshot is populated (precondition)")
	for card_id: String in ALL_PRINTINGS:
		catalog.get_definition(card_id)
		catalog.has_card(card_id)
		catalog.get_upgrade_id(card_id)
	catalog.get_starting_deck()
	catalog.get_starter_ids()
	for legacy_id: String in legacy_snapshot:
		_check(starter.get_definition(legacy_id) == legacy_snapshot[legacy_id],
			"legacy starter record unchanged: " + legacy_id)
	_check(starter.get_starting_deck() == active_deck,
		"the shared starting deck is unchanged after using the new catalog")
	for pool_id: String in pool_snapshot:
		_check(pool.get_definition(pool_id) == pool_snapshot[pool_id],
			"v3 Tinker reward record unchanged: " + pool_id)
	# The eight reward bases (and their '+' printings) are still authored exactly once each.
	for base_id: String in V3_POOL_BASE_IDS:
		_check(pool.has_card(base_id), base_id + " remains a v3 Tinker reward base")
		_check(pool.get_pool_card_ids().has(base_id),
			base_id + " is still listed as a reward candidate")
		_check(pool.get_upgrade_id(base_id) == base_id + "_plus",
			base_id + " still upgrades inside its reward pool")
		var plus: Dictionary = pool.get_definition(base_id + "_plus")
		_check(not plus.is_empty(), base_id + "_plus remains authored")
		_check(plus.get("owner") == "tinker" and plus.get("starting_copies") == 0,
			base_id + "_plus remains a nonstarter Tinker printing")
		_check(not catalog.has_card(base_id),
			"the starter catalog does not serve reward card " + base_id)
		_check(not catalog.has_card(base_id + "_plus"),
			"the starter catalog does not serve reward card " + base_id + "_plus")

	# The Tinker hero's stats and passive stay owned by the roster file, not by this catalog.
	var roster_raw: String = FileAccess.get_file_as_string("res://data/heroes/v3_party_roster.json")
	var roster: Variant = JSON.parse_string(roster_raw)
	_check(roster is Array, "v3 party roster parses (precondition)")
	if roster is Array:
		_check(not (roster as Array).is_empty(), "v3 party roster is populated (precondition)")
		for hero: Variant in roster:
			if hero is Dictionary:
				_check(hero.has("id") and hero.has("max_hp") and hero.has("passive"),
					str(hero.get("id")) + " keeps its authored id, max HP and passive")
	for card_id: String in ALL_PRINTINGS:
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.has("max_hp") and not record.has("passive"),
			card_id + " never invents hero statistics")


## Until the later wiring task, the live reward routing cannot offer or resolve these starters.
func _test_not_reward_offered() -> void:
	var catalog := V3TinkerStarterCards.new()
	var candidates: Array = RunPoolCardRewardOffers.get_authored_base_candidates()
	_check(not candidates.is_empty(), "authored reward candidates are non-empty (precondition)")
	var candidate_ids: Dictionary = {}
	for record: Variant in candidates:
		if record is Dictionary:
			candidate_ids[String(record.get("id", ""))] = true
	_check(candidate_ids.has("tinker_rivet_shot"),
		"reward candidates still include an existing Tinker card (precondition)")
	_check(not RunPoolCardRewardOffers.resolve_reward_definition("tinker_rivet_shot").is_empty(),
		"an existing Tinker reward card is still reward-resolvable (precondition)")
	_check(not RunPoolCardRewardOffers.resolve_reward_definition("tinker_pop_shot").is_empty(),
		"the legacy Tinker starter is still resolvable (precondition)")
	for card_id: String in ALL_PRINTINGS:
		_check(not candidate_ids.has(card_id), "reward candidates exclude " + card_id)
		_check(not candidate_ids.has(card_id + "_plus"),
			"reward candidates exclude the forged upgrade of " + card_id)
		_check(catalog.get_definition(card_id).get("reward_eligible") == false,
			card_id + " is never reward eligible")
		_check(RunPoolCardRewardOffers.resolve_reward_definition(card_id).is_empty(),
			"starter is not reward-resolvable yet: " + card_id)


## AC2: every returned record and projection array is detached from the catalog.
func _test_detached_records() -> void:
	var catalog := V3TinkerStarterCards.new()
	var sample: Dictionary = catalog.get_definition(BOMB)
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["combat_scrap_gain"] = 99
	sample["effects"]["living_targets_only"] = false
	sample["effects"]["invented"] = true
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["display_name"] = "Mutated"
	sample["cost"] = 99
	sample["starting_copies"] = 99
	var pristine: Dictionary = catalog.get_definition(BOMB)
	_check(pristine.get("effects")
		== {"damage": 4, "combat_scrap_gain": 1, "living_targets_only": true},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [3], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2, 3], "TO arrays are deeply detached")
	_check(pristine.get("id") == BOMB, "metadata is detached")
	_check(pristine.get("display_name") == "Scrap Bomb", "display name is detached")
	_check(pristine.get("cost") == 2, "cost is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")

	var upgraded: Dictionary = catalog.get_definition(COG_PLUS)
	_check(not upgraded.is_empty(), "upgrade mutation fixture loaded")
	if upgraded.is_empty():
		return
	upgraded["effects"]["damage"] = 900
	upgraded["effects"]["combat_scrap_gain"] = 9
	upgraded["effects"]["draw"] = 3
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	upgraded["upgrade_of"] = COG_PLUS
	var upgraded_pristine: Dictionary = catalog.get_definition(COG_PLUS)
	_check(upgraded_pristine.get("effects") == {"damage": 7, "combat_scrap_gain": 1},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [2, 3], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [1, 2, 3], "upgrade TO is detached")
	_check(upgraded_pristine.get("upgrade_of") == COG, "upgrade link is detached")
	_check(catalog.get_definition(COG).get("effects") == {"damage": 5, "combat_scrap_gain": 1},
		"mutating one record leaves its base untouched")

	var tune_plus: Dictionary = catalog.get_definition(TUNE_PLUS)
	_check(not tune_plus.is_empty(), "none-target upgrade fixture loaded")
	if not tune_plus.is_empty():
		_check(tune_plus.get("effects") == {"draw": 2, "combat_scrap_gain": 1},
			"none-target fixture is intact before mutation")
		tune_plus["effects"]["draw"] = 900
		tune_plus["effects"]["damage"] = 900
		var tune_pristine: Dictionary = catalog.get_definition(TUNE_PLUS)
		_check(tune_pristine.get("effects") == {"draw": 2, "combat_scrap_gain": 1},
			"none-target effects resist caller mutation and injection")
		_check(tune_pristine.get("to_positions") == [],
			"an empty TO array stays empty after a caller append")

	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(starter_ids.has(WARD) and deck.has(TUNE), "projections are populated before mutation")
	starter_ids.clear()
	starter_ids.append("forged_starter")
	deck.clear()
	all_ids.clear()
	_check(catalog.get_starter_ids().has(WARD), "get_starter_ids returns a fresh array")
	_check(catalog.get_starting_deck().has(TUNE), "get_starting_deck returns a fresh array")
	_check(catalog.get_all_card_ids().has(BOMB_PLUS), "get_all_card_ids returns a fresh array")
	_check(not catalog.get_starter_ids().has("forged_starter"),
		"mutated starter id array leaks nothing")
	_check(not catalog.get_starting_deck().has("forged_starter"),
		"mutated deck array leaks nothing")
	_check(not catalog.get_all_card_ids().has("forged_starter"),
		"mutated enumeration array leaks nothing")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(first_deck == second_deck and first_deck == STARTER_ORDER,
		"two starting-deck calls agree with the authored order")
	if not first_deck.is_empty():
		first_deck[0] = "mutated_first"
	_check(second_deck.count(COG) == 1 and catalog.get_starting_deck().count(COG) == 1,
		"each base starter contributes exactly one copy")
	_check(V3TinkerStarterCards.new().get_definition(BOMB) == pristine,
		"a fresh instance retains the canonical definition")


## AC2: unknown, malformed and foreign IDs fail closed; '+' cards are terminal.
func _test_invalid_and_upgraded_ids() -> void:
	var catalog := V3TinkerStarterCards.new()
	var invalid: Array = [null, 0, 1, -1, 3.5, true, false, [], [COG], {}, StringName(COG),
		StringName(BOMB), "", "tinker_v3_", "tinker_v3_missing_card", "tinker_v3_cog_shot+",
		COG.to_upper(), " " + COG, COG + " ", "forged_starter", "cog_shot", "tinker_pop_shot",
		"tinker_pop_shot_plus", "tinker_scrap_bomb", "tinker_tune_up", "tinker_rivet_shot",
		"tinker_v3_brass_casing", "tinker_v3_brass_casing_plus", "tinker_v3_gear_brace",
		"tinker_v3_gear_brace_plus", "tinker_v3_scrapstorm", "tinker_v3_scrapstorm_plus",
		"warden_strike", "warden_v3_pot_helm_bonk", "seamstress_v3_thread_prick",
		"yarn_ranger_needle_nock", "v3_tinker_cog_shot"]
	for card_id: String in ALL_PRINTINGS:
		invalid.append(card_id + "_plus_plus")
		invalid.append(card_id + "__plus")
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(),
			"invalid id returns no definition: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))
	# Upgraded records exist but are terminal: no second upgrade, no starter membership.
	for card_id: String in ALL_PRINTINGS:
		if not card_id.ends_with("_plus"):
			continue
		var plus_record: Dictionary = catalog.get_definition(card_id)
		_check(not plus_record.is_empty(), card_id + " is a real record")
		_check(plus_record.get("upgrade_of") == card_id.trim_suffix("_plus"),
			card_id + " points back to its base")
		_check(catalog.get_upgrade_id(card_id) == "", card_id + " cannot upgrade again")
		_check(catalog.get_upgrade_id(card_id + "_plus") == "",
			card_id + " has no forged plus-of-plus upgrade")
		_check(catalog.get_definition(catalog.get_upgrade_id(card_id)).is_empty(),
			card_id + " resolves no second definition")
		_check(not catalog.get_starter_ids().has(card_id),
			card_id + " is not proposed as a starter")
		_check(not catalog.get_starting_deck().has(card_id),
			card_id + " is not proposed in the dedicated deck")
		_check(catalog.get_definition(card_id).get("starting_copies") == 0,
			card_id + " never becomes a starting copy")
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(12) == ""
		and catalog.get_upgrade_id("") == "" and catalog.get_upgrade_id([]) == ""
		and catalog.get_upgrade_id(StringName(COG)) == "",
		"get_upgrade_id fails closed on non-string, empty and StringName IDs")
	_check(catalog.get_definition(12).is_empty() and catalog.has_card(12) == false,
		"numeric IDs fail closed on definition and membership")
	_check(not catalog.has_card(StringName(TUNE))
		and catalog.get_definition(StringName(TUNE)).is_empty(),
		"StringName IDs are rejected rather than coerced")


## AC2: catalog construction and lookups are deterministic and draw no RNG at all.
func _test_deterministic_and_rng_free() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
	var before: int = rng.state
	var catalog := V3TinkerStarterCards.new()
	var first_ids: Array[String] = catalog.get_all_card_ids()
	var first_starters: Array[String] = catalog.get_starter_ids()
	var first_deck: Array[String] = catalog.get_starting_deck()
	_check(not first_ids.is_empty(), "determinism fixture loaded (precondition)")
	for card_id: String in ALL_PRINTINGS:
		catalog.get_definition(card_id)
		catalog.has_card(card_id)
		catalog.get_upgrade_id(card_id)
		catalog.get_definition(card_id + "_plus_plus")
	catalog.get_definition("tinker_v3_missing_card")
	catalog.has_card(null)
	catalog.get_upgrade_id(17)
	var second := V3TinkerStarterCards.new()
	_check(first_ids == second.get_all_card_ids(), "catalog enumeration is deterministic")
	_check(first_starters == second.get_starter_ids(), "starter enumeration is deterministic")
	_check(first_deck == second.get_starting_deck(), "starting-deck projection is deterministic")
	_check(first_ids == catalog.get_all_card_ids(), "repeated enumeration is stable")
	_check(first_starters == catalog.get_starter_ids(), "repeated starter enumeration is stable")
	_check(first_deck == catalog.get_starting_deck(), "repeated projection is stable")
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(catalog.get_definition(COG).get("effects") == {"damage": 5, "combat_scrap_gain": 1},
		"lookups leave the catalog pristine")
	_check(rng.state == before, "a second lookup window also consumes no seeded RNG draws")

	# Twin parity: an untouched seeded generator still produces the same next value.
	var twin := RandomNumberGenerator.new()
	twin.seed = 90210
	var twin_next: int = twin.randi()
	var probe := RandomNumberGenerator.new()
	probe.seed = 90210
	for _round: int in range(3):
		for card_id: String in V3TinkerStarterCards.new().get_all_card_ids():
			catalog.get_definition(card_id)
			catalog.has_card(card_id)
			catalog.get_upgrade_id(card_id)
		catalog.get_starting_deck()
		catalog.get_starter_ids()
	var probe_next: int = probe.randi()
	_check(probe_next == twin_next and probe.state == twin.state,
		"a separate RNG instance's state is unchanged by catalog calls")

	# Global RNG: the same seed must still produce the same next value after catalog use.
	seed(814177)
	var expected_next: int = randi()
	seed(814177)
	var fresh := V3TinkerStarterCards.new()
	for card_id: String in fresh.get_all_card_ids():
		_check(not fresh.get_definition(card_id).is_empty(),
			card_id + " RNG probe reads an actual definition")
		fresh.get_upgrade_id(card_id)
		fresh.has_card(card_id)
	fresh.get_definition("tinker_v3_missing_card")
	fresh.get_definition(null)
	fresh.get_starting_deck()
	_check(randi() == expected_next, "construction and lookups never draw global RNG")
