extends SceneTree
## V3-1 Tinker starter-card catalog contract.
## Data only: these four bases and their "+" printings are authored starter data for the Tinker.
## Casing Ward and Tune Up (base and '+') are now also resolved as paid, deterministic, scene-free
## effects by CombatTinkerV3ScrapSupportCards; admitting them to a live hand, the active three-hero
## deck or reward offers is still a later wiring task. Combat Scrap is a COMBAT counter, never the
## run's wallet `scraps`; nothing in this file is ever granted by a lookup.

const V3TinkerStarterCards = preload("res://data/cards/v3_tinker_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const V3TinkerPoolCards = preload("res://data/cards/v3_tinker_pool_cards.gd")
const CombatDeck = preload("res://scripts/combat_deck.gd")
const CombatParty = preload("res://scripts/combat_party.gd")
const CombatTinkerV3ScrapSupportCards = preload(
	"res://scripts/combat_tinker_v3_scrap_support_cards.gd")

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
## The four starter printings this helper now resolves as paid support effects.
const STARTER_SUPPORT_IDS: Array[String] = [WARD, WARD_PLUS, TUNE, TUNE_PLUS]
## The unchanged reward-pool support IDs resolved by the same helper.
const POOL_SUPPORT_IDS: Array[String] = ["tinker_v3_gear_brace",
	"tinker_v3_gear_brace_plus", "tinker_v3_spare_screws", "tinker_v3_spare_screws_plus"]
## The three genuine discard-refill cards of the Tune Up reshuffle fixture.
const REFILL_CARDS: Array[String] = ["v3_support_refill_a", "v3_support_refill_b",
	"v3_support_refill_c"]

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
	_test_support_printings_and_authentication()
	_test_casing_ward_paid_plays()
	_test_tune_up_paid_plays()
	_test_tune_up_draw_supply()
	_test_support_refusals()
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


## AC1: the helper authenticates exactly the four authored starter printings against
## V3TinkerStarterCards, keeps the four reward-pool printings on their own schema, and refuses a
## forged, rewritten, cross-catalog or foreign record.
func _test_support_printings_and_authentication() -> void:
	var catalog := V3TinkerStarterCards.new()
	var pool := V3TinkerPoolCards.new()
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var expected := {
		WARD: {"display": "Casing Ward", "cost": 1, "target": "self", "block": 5, "draw": 0,
			"scrap": 1, "copies": 1, "effects": {"block": 5, "combat_scrap_gain": 1}},
		WARD_PLUS: {"display": "Casing Ward+", "cost": 1, "target": "self", "block": 7, "draw": 0,
			"scrap": 1, "copies": 0, "effects": {"block": 7, "combat_scrap_gain": 1}},
		TUNE: {"display": "Tune Up", "cost": 0, "target": "none", "block": 0, "draw": 1,
			"scrap": 1, "copies": 1, "effects": {"draw": 1, "combat_scrap_gain": 1}},
		TUNE_PLUS: {"display": "Tune Up+", "cost": 0, "target": "none", "block": 0, "draw": 2,
			"scrap": 1, "copies": 0, "effects": {"draw": 2, "combat_scrap_gain": 1}},
	}
	for card_id: String in STARTER_SUPPORT_IDS:
		var row: Dictionary = expected[card_id]
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " is authored in the starter catalog")
		if record.is_empty():
			continue
		_check(record.get("owner") == "tinker", card_id + " is owned by Tinker")
		_check(record.get("display_name") == row["display"], card_id + " keeps its printed name")
		_check(typeof(record.get("cost")) == TYPE_INT and record.get("cost") == row["cost"],
			card_id + " prints its exact integer cost")
		_check(record.get("from_positions") == [1, 2, 3], card_id + " prints FROM 1-3")
		_check(record.get("target_kind") == row["target"],
			card_id + " prints its authored target kind")
		_check(record.get("to_positions") == [], card_id + " prints an empty TO line")
		_check(record.get("effects") == row["effects"], card_id + " prints its exact effects")
		_check(record.get("starting_copies") == row["copies"],
			card_id + " prints its authored starting-copy count")
		_check(record.get("reward_eligible") == false, card_id + " is never reward eligible")
		_check(record.get("illustration_path")
			== ART_DIR + card_id.trim_suffix("_plus") + ".png",
			card_id + " keeps the starter art path of its base")
		_check(not record.has("base_id") and not record.has("is_upgrade")
			and not record.has("rarity"), card_id + " keeps the starter schema, not the pool schema")
		if card_id.ends_with("_plus"):
			_check(record.get("upgrade_of") == card_id.trim_suffix("_plus"),
				card_id + " names its base")
			_check(not record.has("upgrade_id"), card_id + " has no onward upgrade")
			_check(catalog.get_upgrade_id(card_id) == "", card_id + " cannot upgrade again")
		else:
			_check(record.get("upgrade_id") == card_id + "_plus",
				card_id + " names its one upgrade")
			_check(not record.has("upgrade_of"), card_id + " is not itself an upgrade")
			_check(catalog.get_upgrade_id(card_id) == card_id + "_plus",
				card_id + " maps to its printed upgrade")
		_check(not pool.has_card(card_id), card_id + " is not served by the reward pool")
		_check(resolver.is_supported_card(card_id), card_id + " is a supported paid support")
		_check(CombatTinkerV3ScrapSupportCards.is_authentic_definition(record, card_id),
			card_id + " passes the catalog-specific authenticator")
		_check(CombatTinkerV3ScrapSupportCards.is_authentic_starter_definition(record, card_id),
			card_id + " passes the starter authenticator")
		_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(card_id) == record,
			card_id + " resolves to its exact detached starter record")

	# The four existing reward-pool supports keep their own schema and stay supported.
	for pool_id: String in POOL_SUPPORT_IDS:
		var pool_record: Dictionary = pool.get_definition(pool_id)
		_check(not pool_record.is_empty() and not catalog.has_card(pool_id),
			pool_id + " remains a reward-pool-only printing")
		_check(pool_record.get("base_id") is String and pool_record.get("is_upgrade") is bool
			and not pool_record.has("upgrade_of"),
			pool_id + " keeps the pool base_id/upgrade_id/is_upgrade link")
		_check(resolver.is_supported_card(pool_id), pool_id + " remains a supported paid support")
		_check(CombatTinkerV3ScrapSupportCards.is_authentic_definition(pool_record, pool_id),
			pool_id + " still passes the pool authenticator")
		_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(pool_id) == pool_record,
			pool_id + " still resolves to its exact pool record")
		_check(not CombatTinkerV3ScrapSupportCards.is_authentic_starter_definition(
			pool_record, pool_id), pool_id + " is never a starter record")

	# Cross-catalog substitutes and cross-printing records never authenticate.
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		catalog.get_definition(WARD), POOL_SUPPORT_IDS[0]),
		"a starter Casing Ward record cannot pass as Gear Brace")
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		pool.get_definition(POOL_SUPPORT_IDS[0]), WARD),
		"a pool Gear Brace record cannot pass as Casing Ward")
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		catalog.get_definition(WARD_PLUS), WARD),
		"an upgraded starter record cannot authenticate as its base")
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		catalog.get_definition(WARD), WARD_PLUS),
		"a base starter record cannot authenticate as its upgrade")
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		catalog.get_definition(TUNE_PLUS), TUNE),
		"Tune Up+ cannot authenticate as Tune Up")
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		catalog.get_definition(TUNE), TUNE_PLUS),
		"Tune Up cannot authenticate as Tune Up+")

	# Other starter cards and every forged spelling stay unrelated to this helper.
	var unrelated: Array = [COG, COG_PLUS, BOMB, BOMB_PLUS, "tinker_v3_casing_ward+",
		"tinker_v3_casing_ward_plus_plus", "tinker_v3_tune_up+", "tinker_v3_tune_up_plus_plus",
		"casing_ward", "tune_up", "TINKER_V3_CASING_WARD", "TINKER_V3_TUNE_UP", "",
		"tinker_v3_missing_card", "tinker_pop_shot", "tinker_tune_up", StringName(WARD),
		StringName(TUNE), null, 0, 3.5, false, [], {}]
	for other_id: Variant in unrelated:
		_check(not resolver.is_supported_card(other_id),
			"unrelated or non-string ID is not supported: " + str(other_id))
		_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(other_id).is_empty(),
			"unrelated or non-string ID never resolves: " + str(other_id))

	# Adversarial copies of the real Casing Ward record: every altered contract field is refused.
	var base_record: Dictionary = catalog.get_definition(WARD)
	_check(not base_record.is_empty()
		and CombatTinkerV3ScrapSupportCards.is_authentic_definition(base_record, WARD),
		"authenticator positive fixture really is the authored Casing Ward")
	var mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["block"] = 6,
		func(record: Dictionary) -> void: record["effects"]["block"] = 5.0,
		func(record: Dictionary) -> void: record["effects"]["block"] = "5",
		func(record: Dictionary) -> void: record["effects"]["combat_scrap_gain"] = 2,
		func(record: Dictionary) -> void: record["effects"].erase("combat_scrap_gain"),
		func(record: Dictionary) -> void: record["effects"]["draw"] = 1,
		func(record: Dictionary) -> void: record["effects"] = {"block": 5},
		func(record: Dictionary) -> void: record["effects"] = "block",
		func(record: Dictionary) -> void: record["cost"] = 0,
		func(record: Dictionary) -> void: record["cost"] = 2,
		func(record: Dictionary) -> void: record["cost"] = 1.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["from_positions"] = [2, 3],
		func(record: Dictionary) -> void: record["from_positions"] = ["1", "2", "3"],
		func(record: Dictionary) -> void: record["from_positions"] = "1,2,3",
		func(record: Dictionary) -> void: record["to_positions"] = [1],
		func(record: Dictionary) -> void: record["target_kind"] = "none",
		func(record: Dictionary) -> void: record["target_kind"] = "ally_single",
		func(record: Dictionary) -> void: record["id"] = WARD_PLUS,
		func(record: Dictionary) -> void: record["display_name"] = "Casing Ward +",
		func(record: Dictionary) -> void: record["starting_copies"] = 0,
		func(record: Dictionary) -> void: record["starting_copies"] = 1.0,
		func(record: Dictionary) -> void: record["reward_eligible"] = true,
		func(record: Dictionary) -> void: record["reward_eligible"] = 0,
		func(record: Dictionary) -> void: record["illustration_path"] = ART_DIR + "tinker_v3_tune_up.png",
		func(record: Dictionary) -> void: record["upgrade_id"] = WARD_PLUS + "_plus",
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record["upgrade_of"] = WARD,
		func(record: Dictionary) -> void: record["base_id"] = WARD,
		func(record: Dictionary) -> void: record["is_upgrade"] = false,
		func(record: Dictionary) -> void: record["rarity"] = "common",
		func(record: Dictionary) -> void: record.erase("to_positions"),
		func(record: Dictionary) -> void: record.erase("effects"),
	]
	for index in range(mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		mutations[index].call(tampered)
		_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(tampered, WARD),
			"tampered Casing Ward record " + str(index) + " is refused")

	# Tune Up's none target and free draw are equally authentic-only.
	var tune_record: Dictionary = catalog.get_definition(TUNE)
	_check(not tune_record.is_empty()
		and CombatTinkerV3ScrapSupportCards.is_authentic_definition(tune_record, TUNE),
		"authenticator positive fixture really is the authored Tune Up")
	var tune_mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["target_kind"] = "self",
		func(record: Dictionary) -> void: record["effects"]["draw"] = 2,
		func(record: Dictionary) -> void: record["effects"]["block"] = 5,
		func(record: Dictionary) -> void: record["cost"] = 1,
		func(record: Dictionary) -> void: record["starting_copies"] = 0,
	]
	for index in range(tune_mutations.size()):
		var tampered: Dictionary = tune_record.duplicate(true)
		tune_mutations[index].call(tampered)
		_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(tampered, TUNE),
			"tampered Tune Up record " + str(index) + " is refused")


## AC2: a real held Casing Ward or Casing Ward+ pays one energy once, discards exactly one copy,
## grants the printed Block and one Combat Scrap to the living Tinker at his actual seat only, and
## consumes no RNG.
func _test_casing_ward_paid_plays() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var cases := [
		{"id": WARD, "seat": 1, "block": 5},
		{"id": WARD_PLUS, "seat": 2, "block": 7},
		{"id": WARD, "seat": 3, "block": 5},
		{"id": WARD_PLUS, "seat": 1, "block": 7},
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var card_id: String = entry["id"]
		var seat: int = entry["seat"]
		var printed_block: int = entry["block"]
		var label := card_id + " from seat " + str(seat)
		var party := _support_party(seat)
		_check(party.gain_block(seat, 2), label + ": the owner fixture really carries Block")
		var deck := _support_deck([card_id], 701100 + index, 6)
		_check(deck.energy == 3 and deck.turn_active and deck.discard_pile.is_empty(),
			label + ": a real three-energy turn is active")
		var blocks_before: Array = [
			party.get_hero(1).get("block"), party.get_hero(2).get("block"),
			party.get_hero(3).get("block"),
		]
		var wallet := {"gold": 9, "scraps": 4}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var rng_before: int = deck._rng.state
		var draw_before: int = deck.draw_pile.size()
		var before := _support_snapshot(deck, party)
		var result: Dictionary = resolver.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			label + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == seat and result.get("target_position") == seat,
			label + ": receipt reports the real owner seat as the self recipient")
		_check(result.get("block_gained") == printed_block,
			label + ": receipt reports the printed Block")
		_check(result.get("draw_requested") == 0 and result.get("drawn") == 0,
			label + ": Casing Ward prints no draw")
		_check(result.get("combat_scrap_before") == 0
			and result.get("combat_scrap_gained") == 1
			and result.get("combat_scrap_after") == 1,
			label + ": receipt reports exactly one Combat Scrap from zero")
		_check(result.get("energy_before") == 3 and result.get("energy_after") == 2,
			label + ": receipt reports the exact energy change")
		_check(not result.has("scraps") and not result.has("wallet"),
			label + ": receipt carries no wallet state")
		_check(deck.energy == 2, label + ": exactly one energy was paid")
		_check(deck.hand.count(card_id) == 0, label + ": the held copy left the hand")
		_check(deck.discard_pile == [card_id],
			label + ": exactly one played copy reached the discard")
		_check(deck.draw_pile.size() == draw_before, label + ": Casing Ward drew nothing")
		_check(deck._rng.state == rng_before, label + ": no RNG was consumed")
		_check(party.get_hero(seat).get("block") == int(blocks_before[seat - 1]) + printed_block,
			label + ": the Tinker gained exactly the printed Block on existing Block")
		_check(party.get_hero(seat).get("combat_scrap") == 1
			and party._heroes[seat - 1].get("combat_scrap") == 1,
			label + ": the authoritative Tinker record holds one Combat Scrap")
		_check(party.get_hero(seat).get("hp") == 26, label + ": the Tinker's HP is untouched")
		for position: int in [1, 2, 3]:
			if position == seat:
				continue
			_check(party.get_hero(position).get("block") == int(blocks_before[position - 1]),
				label + ": seat " + str(position) + " gained no Block")
			_check(not party.get_hero(position).has("combat_scrap"),
				label + ": seat " + str(position) + " gained no Combat Scrap")
		_check(wallet == wallet_before, label + ": wallet scraps are never modified")
		_check(_support_snapshot(deck, party)
			== _expected_support(before, card_id, seat, 1, printed_block, 0),
			label + ": exact hand, piles, energy, turn, party, counter and RNG state")

	# Two genuine held copies: one legal play discards exactly one of them.
	var copy_party := _support_party(2)
	var copy_deck := _support_duplicate_deck(WARD, 701199)
	_check(copy_deck.hand.count(WARD) == 2, "duplicate-copy fixture really holds two Wards")
	var copy_result: Dictionary = resolver.play_card(copy_deck, copy_party, WARD)
	_check(copy_result.get("ok") == true, "a hand with two copies is one legal play")
	_check(copy_deck.hand.count(WARD) == 1, "exactly one held Ward was discarded")
	_check(copy_deck.discard_pile == [WARD], "only the played Ward reached the discard")
	_check(copy_party.get_hero(2).get("block") == 5
		and copy_party.get_hero(2).get("combat_scrap") == 1,
		"the duplicate-copy play still grants its Block and one Combat Scrap")


## AC3: a real held Tune Up or Tune Up+ pays its zero printed energy, draws 1/2 shared cards before
## discarding its own copy, grants one Combat Scrap and zero Block to the Tinker only, and leaves a
## true zero-energy turn untouched.
func _test_tune_up_paid_plays() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var cases := [
		{"id": TUNE, "seat": 1, "draw": 1},
		{"id": TUNE_PLUS, "seat": 2, "draw": 2},
		{"id": TUNE, "seat": 3, "draw": 1},
		{"id": TUNE_PLUS, "seat": 1, "draw": 2},
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var card_id: String = entry["id"]
		var seat: int = entry["seat"]
		var draw: int = entry["draw"]
		var label := card_id + " from seat " + str(seat)
		var party := _support_party(seat)
		var deck := _support_deck([card_id], 702100 + index, 6)
		_check(deck.energy == 3 and deck.draw_pile.size() == 2,
			label + ": a real turn leaves two genuine shared cards to draw")
		var expected_draws: Array[String] = []
		for offset in range(draw):
			expected_draws.append(deck.draw_pile[deck.draw_pile.size() - 1 - offset])
		var wallet := {"gold": 9, "scraps": 4}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var rng_before: int = deck._rng.state
		var before := _support_snapshot(deck, party)
		var result: Dictionary = resolver.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 0,
			label + ": receipt names the authentic card and its zero cost")
		_check(result.get("owner_position") == seat and result.get("target_position") == 0,
			label + ": the none target uses the helper's sentinel 0")
		_check(result.get("block_gained") == 0, label + ": Tune Up grants no Block")
		_check(result.get("draw_requested") == draw and result.get("drawn") == draw,
			label + ": receipt reports its printed shared draw")
		_check(result.get("combat_scrap_before") == 0
			and result.get("combat_scrap_gained") == 1
			and result.get("combat_scrap_after") == 1,
			label + ": receipt reports exactly one Combat Scrap from zero")
		_check(result.get("energy_before") == 3 and result.get("energy_after") == 3,
			label + ": receipt reports no energy change")
		_check(not result.has("scraps") and not result.has("wallet"),
			label + ": receipt carries no wallet state")
		_check(deck.energy == 3, label + ": its zero printed energy was paid")
		_check(deck.hand.count(card_id) == 0, label + ": the played copy left the hand")
		_check(deck.hand.size() == 4 + draw, label + ": exactly its printed draw reached the hand")
		for expected_id: String in expected_draws:
			_check(deck.hand.has(expected_id),
				label + ": the seeded shared draw reached the hand: " + expected_id)
		_check(deck.draw_pile.size() == 2 - draw, label + ": the draw consumed its supply")
		_check(deck.discard_pile == [card_id],
			label + ": exactly one played copy reached the discard after the draw")
		_check(deck._rng.state == rng_before,
			label + ": drawing from a nonempty supply consumes no RNG")
		_check(party.get_hero(seat).get("combat_scrap") == 1
			and party._heroes[seat - 1].get("combat_scrap") == 1,
			label + ": the authoritative Tinker record holds one Combat Scrap")
		for position: int in [1, 2, 3]:
			_check(party.get_hero(position).get("block") == 0,
				label + ": seat " + str(position) + " gained no Block")
			if position == seat:
				continue
			_check(not party.get_hero(position).has("combat_scrap"),
				label + ": seat " + str(position) + " gained no Combat Scrap")
		_check(wallet == wallet_before, label + ": wallet scraps are never modified")
		_check(_support_snapshot(deck, party)
			== _expected_support(before, card_id, seat, 0, 0, draw),
			label + ": exact hand, piles, energy, turn, party, counter and RNG state")

	# A genuine zero-energy turn still pays Tune Up's printed zero and plays normally.
	var free_party := _support_party(2)
	var free_deck := _support_deck([TUNE], 702200, 5)
	free_deck.combat_state.energy = 0
	_check(free_deck.energy == 0 and free_deck.hand.has(TUNE),
		"zero-energy fixture really holds a Tune Up with no energy")
	var free_result: Dictionary = resolver.play_card(free_deck, free_party, TUNE)
	_check(free_result.get("ok") == true and free_result.get("cost") == 0
		and free_deck.energy == 0,
		"Tune Up is legal at zero energy and pays nothing")
	_check(free_result.get("drawn") == 1
		and free_deck.discard_pile == [TUNE]
		and free_party.get_hero(2).get("combat_scrap") == 1
		and free_party.get_hero(2).get("block") == 0,
		"the zero-energy play still draws one, discards one and gains one Combat Scrap")


## AC3: a shared discard refill is drawn through the seeded RNG, never recycles the still-held
## played copy into its own draw, and replays identically on the same seed.
func _test_tune_up_draw_supply() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var fixture := _support_refill_fixture(TUNE_PLUS, 704100)
	_check(not fixture.is_empty(), "refill fixture built")
	if fixture.is_empty():
		return
	var deck: CombatDeck = fixture["deck"]
	var party: CombatParty = fixture["party"]
	_check(deck.hand == [TUNE_PLUS] and deck.draw_pile.is_empty()
		and deck.discard_pile.size() == 3,
		"refill fixture really leaves an empty draw pile and three genuine discards")
	var rng_before: int = deck._rng.state
	var result: Dictionary = resolver.play_card(deck, party, TUNE_PLUS)
	_check(result.get("ok") == true and result.get("drawn") == 2,
		"the discard refill supplies both printed shared draws")
	_check(not deck.hand.has(TUNE_PLUS),
		"the still-held played copy cannot refill itself into its own draw")
	_check(deck.hand.size() == 2 and deck.draw_pile.size() == 1
		and deck.discard_pile == [TUNE_PLUS],
		"the reshuffle conserves every card: two drawn, one left, only the played copy discarded")
	var seen: Array[String] = []
	for card_id: String in deck.hand:
		_check(REFILL_CARDS.has(card_id), "the drawn card is one of the genuine discards: " + card_id)
		seen.append(card_id)
	_check(seen.size() == 2 and seen[0] != seen[1],
		"the two drawn refill cards are distinct")
	_check(REFILL_CARDS.has(deck.draw_pile[0]) and not seen.has(deck.draw_pile[0]),
		"the other genuine discard stays in the reshuffled draw pile")
	_check(deck._rng.state != rng_before,
		"the genuine reshuffle is drawn through the already-seeded RNG")
	_check(deck.energy == 3, "the free Tune Up+ refill play pays nothing")
	_check(party.get_hero(2).get("combat_scrap") == 1
		and party.get_hero(2).get("block") == 0,
		"the refill play gains one Combat Scrap and no Block")

	# Same seed, same fixture: an identical replay of the reshuffle and its draw.
	var replay := _support_refill_fixture(TUNE_PLUS, 704100)
	_check(not replay.is_empty(), "replay fixture built")
	if replay.is_empty():
		return
	var replay_deck: CombatDeck = replay["deck"]
	var replay_party: CombatParty = replay["party"]
	var replay_result: Dictionary = resolver.play_card(replay_deck, replay_party, TUNE_PLUS)
	_check(replay_result.get("ok") == true, "the replay refill play also succeeds")
	_check(_support_snapshot(replay_deck, replay_party)
		== _support_snapshot(deck, party),
		"the same seed replays the identical drawn cards, piles, counter and RNG state")


## AC4: every failed identity, turn, owner, seat, energy, held-copy, target, roster, counter or
## overflow precondition is refused with its reason and mutates no deck, party, counter or RNG
## state; the four pool supports keep their contract.
func _test_support_refusals() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var party := _support_party(2)
	var deck := _support_deck([WARD], 703100, 6)
	var tune_deck := _support_deck([TUNE], 703101, 6)
	var wallet := {"gold": 9, "scraps": 4}
	var wallet_before: Dictionary = wallet.duplicate(true)

	_rejected_support(resolver, null, party, WARD, 0, "invalid_request", "null deck")
	_rejected_support(resolver, deck, null, WARD, 0, "invalid_request", "null party")

	# An inactive turn is never paid, even with a real copy in hand.
	var inactive := CombatDeck.new([WARD], _support_rng(703102))
	inactive.hand.append(WARD)
	_check(not inactive.turn_active and inactive.hand.has(WARD),
		"inactive fixture really holds a Ward outside a turn")
	_rejected_support(resolver, inactive, party, WARD, 0, "inactive_turn", "inactive Ward turn")
	var inactive_tune := CombatDeck.new([TUNE], _support_rng(703103))
	inactive_tune.hand.append(TUNE)
	_rejected_support(resolver, inactive_tune, party, TUNE, 0, "inactive_turn",
		"inactive Tune Up turn")

	# Unsupported identities: other authentic starter and v2 cards, forged spellings, non-strings.
	var wrong_ids: Array = [COG, COG_PLUS, BOMB, BOMB_PLUS, "tinker_v3_casing_ward+",
		"tinker_v3_casing_ward_plus_plus", "tinker_v3_tune_up+", "tinker_v3_tune_up_plus_plus",
		"casing_ward", "tune_up", "TINKER_V3_CASING_WARD", "TINKER_V3_TUNE_UP", "",
		"tinker_v3_missing_card", "tinker_pop_shot", "tinker_tune_up", StringName(WARD), null, 0,
		3.5, false, [], {}]
	for wrong_id: Variant in wrong_ids:
		_rejected_support(resolver, deck, party, wrong_id, 0, "unsupported_card",
			"unsupported ID " + str(wrong_id))

	# Authentic supports the hand does not hold are still unheld, including a pool support.
	_rejected_support(resolver, deck, party, WARD_PLUS, 0, "card_not_held",
		"authentic but unheld Casing Ward+")
	_rejected_support(resolver, deck, party, TUNE_PLUS, 0, "card_not_held",
		"authentic but unheld Tune Up+")
	_rejected_support(resolver, deck, party, POOL_SUPPORT_IDS[0], 0, "card_not_held",
		"authentic but unheld pool Gear Brace")

	# Ward's one printed energy is required before any partial charge.
	var poor := _support_deck([WARD], 703104, 6)
	poor.combat_state.energy = 0
	_check(poor.energy == 0 and poor.hand.has(WARD),
		"short-energy fixture really holds a Ward on no energy")
	_rejected_support(resolver, poor, party, WARD, 0, "insufficient_energy", "no Ward energy")

	# Both starter targets use the sentinel: any named slot is an invalid request.
	for slot: int in [1, 2, 3, 4, -1, 99]:
		_rejected_support(resolver, deck, party, WARD, slot, "invalid_target",
			"Ward target slot " + str(slot))
		_rejected_support(resolver, tune_deck, party, TUNE, slot, "invalid_target",
			"Tune Up target slot " + str(slot))

	# A party without Tinker never authorizes the play.
	var absent_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "yarn_ranger", "max_hp": 28}])
	_check(absent_owner.is_valid() and absent_owner.get_hero(2).get("id") == "seamstress",
		"absent-owner fixture is a valid party without a Tinker")
	_rejected_support(resolver, deck, absent_owner, WARD, 0, "owner_missing", "absent Tinker")

	# A second Tinker identity is a malformed roster, never a second owner.
	var duplicate := _support_party(2)
	duplicate._heroes[0]["id"] = "tinker"
	_check(duplicate.get_hero(1).get("id") == "tinker"
		and duplicate.get_hero(2).get("id") == "tinker",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_support(resolver, deck, duplicate, WARD, 0, "invalid_party",
		"duplicate Tinker identity")

	# A torn (downed) owner may not play either starter.
	var torn_owner := _support_party(3)
	_check(torn_owner.apply_damage(3, 26) and torn_owner.is_downed(3),
		"torn-owner fixture really has a downed Tinker")
	_rejected_support(resolver, deck, torn_owner, WARD, 0, "owner_downed", "downed Tinker Ward")

	# Malformed party records fail closed before the counter or Block is touched.
	var shorten := CombatParty.new([{"id": "tinker", "max_hp": 26}])
	_rejected_support(resolver, deck, shorten, WARD, 0, "invalid_party", "one-hero party")
	var bad_hp := _support_party(2)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_support(resolver, deck, bad_hp, WARD, 0, "invalid_party", "malformed hero HP")
	var bad_block := _support_party(2)
	bad_block._heroes[0]["block"] = -1
	_rejected_support(resolver, deck, bad_block, WARD, 0, "invalid_party",
		"malformed hero Block")
	var bad_position := _support_party(2)
	bad_position._heroes[0]["position"] = 3
	_rejected_support(resolver, deck, bad_position, WARD, 0, "invalid_party",
		"malformed hero slot index")
	var bad_identity := _support_party(2)
	bad_identity._heroes[0]["id"] = ""
	_rejected_support(resolver, deck, bad_identity, WARD, 0, "invalid_party",
		"empty hero identity")

	# Block and counter capacity are proven before any payment.
	var block_overflow := _support_party(2)
	block_overflow._heroes[1]["block"] = CombatParty.MAX_INT - 1
	_check(block_overflow.get_hero(2).get("block") == CombatParty.MAX_INT - 1,
		"Block-overflow fixture really sits one Block below the integer limit")
	_rejected_support(resolver, deck, block_overflow, WARD, 0, "block_overflow", "Block overflow")
	var counter_overflow := _support_party(2)
	counter_overflow._heroes[1]["combat_scrap"] = CombatParty.MAX_INT
	_rejected_support(resolver, deck, counter_overflow, WARD, 0, "combat_scrap_overflow",
		"Ward Combat Scrap overflow")
	var tune_overflow := _support_party(2)
	tune_overflow._heroes[1]["combat_scrap"] = CombatParty.MAX_INT
	_rejected_support(resolver, tune_deck, tune_overflow, TUNE, 0, "combat_scrap_overflow",
		"Tune Up Combat Scrap overflow")

	# A malformed stored counter is never coerced into a legal number.
	for bad_counter: Variant in ["3", -1, 1.0]:
		var text_counter := _support_party(2)
		text_counter._heroes[1]["combat_scrap"] = bad_counter
		_rejected_support(resolver, deck, text_counter, WARD, 0, "malformed_combat_scrap",
			"Ward malformed Combat Scrap " + str(bad_counter))
		var tune_counter := _support_party(2)
		tune_counter._heroes[1]["combat_scrap"] = bad_counter
		_rejected_support(resolver, tune_deck, tune_counter, TUNE, 0, "malformed_combat_scrap",
			"Tune Up malformed Combat Scrap " + str(bad_counter))

	# A rewritten starter record is refused through this instance's catalog seam; the static
	# authentic lookup still returns the authored printing.
	var forged_catalog := V3TinkerStarterCards.new()
	forged_catalog._definitions[WARD]["effects"]["block"] = 9
	forged_catalog._definitions[TUNE_PLUS]["cost"] = 2
	var forged_resolver := CombatTinkerV3ScrapSupportCards.new()
	forged_resolver._starter_catalog = forged_catalog
	_check(not forged_resolver.is_supported_card(WARD)
		and not forged_resolver.is_supported_card(TUNE_PLUS),
		"rewritten starter records are not supported paid printings")
	_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(WARD).get("effects")
		.get("block") == 5,
		"the authentic static resolution still returns the printed Block")
	_rejected_support(forged_resolver, deck, party, WARD, 0, "catalog_mismatch",
		"forged Casing Ward record")
	_rejected_support(forged_resolver, _support_deck([TUNE_PLUS], 703105, 6), party, TUNE_PLUS,
		0, "catalog_mismatch", "forged Tune Up+ record")

	# A consumed copy cannot be played twice.
	var repeat_party := _support_party(3)
	var repeat_deck := _support_deck([TUNE], 703106, 5)
	_check(resolver.play_card(repeat_deck, repeat_party, TUNE).get("ok") == true,
		"duplicate-play fixture really casts once")
	_check(repeat_deck.energy == 3 and repeat_deck.discard_pile == [TUNE],
		"duplicate-play fixture really paid nothing and discarded the copy")
	_rejected_support(resolver, repeat_deck, repeat_party, TUNE, 0, "card_not_held",
		"duplicate play of the consumed Tune Up")

	_check(wallet == wallet_before, "every refusal left the run wallet's scraps untouched")

	# The shared fixture decks and party survived every refusal untouched.
	_check(deck.energy == 3 and deck.hand.has(WARD) and deck.discard_pile.is_empty()
		and tune_deck.energy == 3 and tune_deck.hand.has(TUNE)
		and tune_deck.discard_pile.is_empty()
		and party.get_hero(2).get("block") == 0
		and not party.get_hero(2).has("combat_scrap"),
		"every refusal left the shared fixture decks and party untouched")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry: Dictionary = resolver.play_card(deck, party, WARD, 0)
	_check(retry.get("ok") == true and retry.get("block_gained") == 5
		and retry.get("combat_scrap_after") == 1,
		"the authentic play then succeeds exactly once")
	_check(deck.energy == 2 and deck.discard_pile == [WARD]
		and party.get_hero(2).get("block") == 5
		and party.get_hero(2).get("combat_scrap") == 1,
		"the retry paid once, granted only the Tinker its Block and one Combat Scrap")
	for position: int in [1, 3]:
		_check(party.get_hero(position).get("block") == 0
			and not party.get_hero(position).has("combat_scrap"),
			"the retry left teammate seat " + str(position) + " untouched")
	_rejected_support(resolver, deck, party, WARD, 0, "card_not_held",
		"a second claim of the same Ward copy")


## A real seeded shared hand holding the named support printing, with further filler in the shared
## draw pile. Swaps only move real cards between the real hand and draw pile.
func _support_deck(held_ids: Array, seed_value: int, supply: int) -> CombatDeck:
	var ids: Array[String] = []
	for card_id in held_ids:
		ids.append(str(card_id))
	for index in range(supply):
		ids.append("v3_support_filler_" + str(index))
	var deck := CombatDeck.new(ids, _support_rng(seed_value))
	_check(deck.start_turn() and deck.energy == 3,
		"fixture starts a real three-energy shared turn for " + str(held_ids))
	var hand_slot := 0
	for card_id: String in held_ids:
		if deck.hand.has(card_id):
			continue
		var source: int = deck.draw_pile.find(card_id)
		if source < 0:
			continue
		while hand_slot < deck.hand.size() and deck.hand[hand_slot] in held_ids:
			hand_slot += 1
		if hand_slot >= deck.hand.size():
			continue
		var swap: String = deck.hand[hand_slot]
		deck.draw_pile[source] = swap
		deck.hand[hand_slot] = card_id
		hand_slot += 1
	for card_id: String in held_ids:
		_check(deck.hand.has(card_id), "fixture hand really holds " + card_id)
	_check(deck.discard_pile.is_empty(), "fixture discard starts empty")
	return deck


## A genuine seeded hand already holding two copies of the named support printing.
func _support_duplicate_deck(card_id: String, seed_value: int) -> CombatDeck:
	var deck := CombatDeck.new([card_id, card_id, "v3_support_filler_a",
		"v3_support_filler_b", "v3_support_filler_c", "v3_support_filler_d"],
		_support_rng(seed_value))
	_check(deck.start_turn(), "duplicate-copy fixture starts a real turn")
	while deck.hand.count(card_id) < 2 and deck.draw_pile.has(card_id):
		var spare_slot := -1
		for hand_index in range(deck.hand.size()):
			if deck.hand[hand_index] != card_id:
				spare_slot = hand_index
				break
		var pile_index: int = deck.draw_pile.find(card_id)
		if spare_slot < 0 or pile_index < 0:
			break
		var moved: String = deck.hand[spare_slot]
		deck.draw_pile[pile_index] = moved
		deck.hand[spare_slot] = card_id
	return deck


## Empty draw pile with three genuine discards behind the held zero-cost Tune Up+.
func _support_refill_fixture(card_id: String, seed_value: int) -> Dictionary:
	var deck := CombatDeck.new([card_id, "v3_support_refill_a", "v3_support_refill_b",
		"v3_support_refill_c"], _support_rng(seed_value))
	if not deck.start_turn():
		return {}
	deck.hand.clear()
	deck.hand.append(card_id)
	deck.discard_pile.append("v3_support_refill_a")
	deck.discard_pile.append("v3_support_refill_b")
	deck.discard_pile.append("v3_support_refill_c")
	return {"deck": deck, "party": _support_party(2)}


func _support_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero party with the living Tinker in the named seat. A fresh CombatParty never
## carries the optional combat_scrap key.
func _support_party(tinker_position: int) -> CombatParty:
	var roster: Array = []
	var others: Array[String] = ["warden", "seamstress"]
	var next_other := 0
	for index in range(3):
		if index + 1 == tinker_position:
			roster.append({"id": "tinker", "max_hp": 26})
		else:
			roster.append({"id": others[next_other], "max_hp": 40 - next_other * 6})
			next_other += 1
	var party := CombatParty.new(roster)
	_check(party.is_valid() and party.get_hero(tinker_position).get("id") == "tinker"
		and party.get_hero(tinker_position).get("hp") == 26,
		"valid three-hero party with a living Tinker in seat " + str(tinker_position))
	_check(not party.get_hero(tinker_position).has("combat_scrap")
		and party.get_hero(tinker_position).get("combat_scrap", 0) == 0,
		"a real fresh party begins at zero Combat Scrap in seat " + str(tinker_position))
	return party


func _support_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var snapshot: Dictionary = {
		"deck_present": deck != null, "party_present": party != null
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
	return snapshot


## The exact support outcome: the printed cost, one real shared draw per printed draw (from the
## nonempty supply this helper uses), the held copy moved to discard, Block on the owner's record
## only when printed, and one more Combat Scrap on that same hero only.
func _expected_support(before: Dictionary, card_id: String, seat: int, cost: int,
		block: int, draw: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - cost
	expected["state_energy"] = int(expected["state_energy"]) - cost
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one played copy is held")
	hand.remove_at(hand.find(card_id))
	var draw_pile: Array = expected["draw"]
	for _slot in range(draw):
		_check(not draw_pile.is_empty(), "expected snapshot: the printed draw has supply")
		if not draw_pile.is_empty():
			hand.append(draw_pile.pop_back())
	(expected["discard"] as Array).append(card_id)
	var hero: Dictionary = expected["party"][seat - 1]
	if block > 0:
		hero["block"] = int(hero["block"]) + block
	hero["combat_scrap"] = int(hero.get("combat_scrap", 0)) + 1
	return expected


func _rejected_support(resolver: CombatTinkerV3ScrapSupportCards, deck: CombatDeck,
		party: CombatParty, card_id: Variant, target: int, reason: String,
		label: String) -> void:
	var before := _support_snapshot(deck, party)
	var result: Dictionary = resolver.play_card(deck, party, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_support_snapshot(deck, party) == before,
		label + ": unchanged energy, hand, piles, turn, party, counters and RNG")
