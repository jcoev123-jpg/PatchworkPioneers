extends SceneTree
## Deterministic headless test for the standalone V3SeamstressPoolCards catalog (V3-1).
## Verifies the eight authored v3 Seamstress needle-and-thread base cards and their eight '+'
## upgrades field by field, the Tether / cleanse descriptors, catalog isolation (unknown and
## malformed IDs, base enumeration, caller mutation, RNG-free determinism) and that the existing
## Seamstress pool, the starter catalogs and the live reward selector are untouched.
##
## The second half drives the V3-1 Bobbin Snag / Bobbin Snag+ RULES resolver added by this task:
## real seeded CombatDeck hands, a real three-hero CombatParty, an original-slot CombatEnemies
## roster and the genuine CombatPinned plus roster-bound CombatUnravel authorities. The catalog is
## still NOT mounted in rewards, the map, shops or the live battle hand, so nothing here drives a
## live card, and no Tether/cleanse behaviour is claimed to be playable.
##
## The third part drives the V3-1 Blanket of Barbs / Blanket of Barbs+ target-free area resolver:
## the same real seeded deck, party and original-slot roster plus the roster-bound CombatUnravel,
## on both printings, through the real 8/12/16 thresholds and a pending action skip. That resolver
## is still callable rules-layer only: no live hand, reward, app or run-deck path is claimed.


var failures: Array[String] = []
var checks: int = 0

const SNAG := "seamstress_v3_bobbin_snag"
const SNAG_PLUS := "seamstress_v3_bobbin_snag_plus"
## The v2 Seamstress control card of a similar name: never this V3 printing.
const V2_SNAG := "seamstress_snag"
var snag_resolver := CombatSeamstressV3BobbinSnagCards.new()

const BLANKET := "seamstress_v3_blanket_of_barbs"
const BLANKET_PLUS := "seamstress_v3_blanket_of_barbs_plus"
## The v2 Seamstress blanket of a similar name: never this V3 printing.
const V2_BLANKET := "seamstress_blanket_stitch"
var blanket_resolver := CombatSeamstressV3BlanketCards.new()

## Effect keys this v3 pool is allowed to print. Guards against invented statuses, resources or
## persistent combat state arriving with a "helpful" edit.
const ALLOWED_EFFECT_KEYS: Array[String] = [
	"damage", "bleed", "weak", "unravel", "pinned", "heal", "block",
	"tether_share_percent", "cleanse_debuff",
]
## Enemy-facing target kinds: only these name enemy positions.
const ENEMY_TARGET_KINDS: Array[String] = ["enemy_single", "enemy_pair", "enemy_all"]
## Representative existing Seamstress pool definitions that must stay owned by their own catalog.
const EXISTING_SEAMSTRESS_POOL_IDS: Array[String] = [
	"seamstress_running_stitch",
	"seamstress_needle_pin",
	"seamstress_darning",
	"seamstress_blanket_stitch",
]
## Named starter membership (Warden / Seamstress / Tinker) with its authored effects and multiplicity.
const EXPECTED_STARTERS: Dictionary = {
	"warden_strike": {"copies": 2, "effects": {"damage": 6}},
	"seamstress_prick": {"copies": 2, "effects": {"damage": 3, "bleed": 2}},
	"seamstress_mend": {"copies": 1, "effects": {"heal": 5}},
	"seamstress_stitch_up": {"copies": 1, "effects": {"block": 5}},
	"tinker_pop_shot": {"copies": 2, "effects": {"damage": 5}},
	"tinker_tune_up": {"copies": 1, "effects": {"draw": 1}},
}


func _initialize() -> void:
	_test_base_card_definitions()
	_test_upgraded_card_definitions()
	_test_needle_and_thread_identity()
	_test_unknown_and_invalid_ids()
	_test_mutation_isolation()
	_test_deterministic_and_rng_free()
	_test_existing_catalogs_untouched()
	_test_not_in_reward_draws()
	_test_bobbin_snag_resolver()
	_test_blanket_resolver()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("v3_seamstress_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_seamstress_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _get_catalog() -> V3SeamstressPoolCards:
	return V3SeamstressPoolCards.new()


## Independent, named expectations keyed by the eight authored base IDs. Never a total count or an
## ordered global ID list: other coders add entries to sibling catalogs at the same time.
func _expected_base_records() -> Dictionary:
	return {
		"seamstress_v3_needle_rain": {
			"display_name": "Needle Rain",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 2, "bleed": 3},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_needle_rain.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_needle_rain_plus",
		},
		"seamstress_v3_scarlet_knot": {
			"display_name": "Scarlet Knot",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 2, "weak": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_scarlet_knot.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_scarlet_knot_plus",
		},
		"seamstress_v3_bobbin_snag": {
			"display_name": "Bobbin Snag",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"unravel": 3, "pinned": true},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_bobbin_snag.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_bobbin_snag_plus",
		},
		"seamstress_v3_patchwork_poultice": {
			"display_name": "Patchwork Poultice",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 3, "block": 3},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_patchwork_poultice.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_patchwork_poultice_plus",
		},
		"seamstress_v3_tether_stitch": {
			"display_name": "Tether Stitch",
			"owner": "seamstress",
			"cost": 2,
			"from_positions": [2, 3],
			"target_kind": "enemy_pair",
			"to_positions": [1, 2, 3],
			"effects": {"tether_share_percent": 50},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_tether_stitch_plus",
		},
		"seamstress_v3_darn_the_tear": {
			"display_name": "Darn the Tear",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 4, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_darn_the_tear.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_darn_the_tear_plus",
		},
		"seamstress_v3_blanket_of_barbs": {
			"display_name": "Blanket of Barbs",
			"owner": "seamstress",
			"cost": 2,
			"from_positions": [2, 3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 2, "unravel": 2},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_blanket_of_barbs.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_blanket_of_barbs_plus",
		},
		"seamstress_v3_midnight_loom": {
			"display_name": "Midnight Loom",
			"owner": "seamstress",
			"cost": 3,
			"from_positions": [2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"heal": 4, "block": 4, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_midnight_loom.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": true,
			"upgrade_id": "seamstress_v3_midnight_loom_plus",
		},
	}


## Independent, named '+' expectations: printed damage/Block/heal/Bleed/Unravel rise by the
## documented D2 +30%-rounded-up step, statuses and the Tether percentage do not scale, and
## Tether Stitch's '+' instead costs one less energy.
func _expected_plus_records() -> Dictionary:
	return {
		"seamstress_v3_needle_rain_plus": {
			"display_name": "Needle Rain+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"damage": 3, "bleed": 4},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_needle_rain.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_needle_rain",
		},
		"seamstress_v3_scarlet_knot_plus": {
			"display_name": "Scarlet Knot+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 3, "weak": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_scarlet_knot.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_scarlet_knot",
		},
		"seamstress_v3_bobbin_snag_plus": {
			"display_name": "Bobbin Snag+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [1, 2, 3],
			"effects": {"unravel": 4, "pinned": true},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_bobbin_snag.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_bobbin_snag",
		},
		"seamstress_v3_patchwork_poultice_plus": {
			"display_name": "Patchwork Poultice+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 4, "block": 4},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_patchwork_poultice.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_patchwork_poultice",
		},
		"seamstress_v3_tether_stitch_plus": {
			"display_name": "Tether Stitch+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_pair",
			"to_positions": [1, 2, 3],
			"effects": {"tether_share_percent": 50},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_tether_stitch",
		},
		"seamstress_v3_darn_the_tear_plus": {
			"display_name": "Darn the Tear+",
			"owner": "seamstress",
			"cost": 1,
			"from_positions": [1, 2, 3],
			"target_kind": "ally_single",
			"to_positions": [],
			"effects": {"heal": 6, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_darn_the_tear.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_darn_the_tear",
		},
		"seamstress_v3_blanket_of_barbs_plus": {
			"display_name": "Blanket of Barbs+",
			"owner": "seamstress",
			"cost": 2,
			"from_positions": [2, 3],
			"target_kind": "enemy_all",
			"to_positions": [1, 2, 3],
			"effects": {"bleed": 3, "unravel": 3},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_blanket_of_barbs.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_blanket_of_barbs",
		},
		"seamstress_v3_midnight_loom_plus": {
			"display_name": "Midnight Loom+",
			"owner": "seamstress",
			"cost": 3,
			"from_positions": [2, 3],
			"target_kind": "party_all",
			"to_positions": [],
			"effects": {"heal": 6, "block": 6, "cleanse_debuff": 1},
			"illustration_path": "res://assets/paper/cards/seamstress_v3_midnight_loom.png",
			"starting_copies": 0,
			"rarity": "rare",
			"reward_eligible": false,
			"upgrade_of": "seamstress_v3_midnight_loom",
		},
	}


func _expected_keys(upgraded: bool) -> Array[String]:
	var keys: Array[String] = [
		"id", "display_name", "owner", "cost", "from_positions", "target_kind",
		"to_positions", "effects", "illustration_path", "starting_copies", "rarity",
		"reward_eligible",
	]
	keys.append("upgrade_of" if upgraded else "upgrade_id")
	return keys


func _check_effect_keys(card_id: String, effects: Dictionary) -> void:
	_check(not effects.is_empty(), card_id + " prints at least one effect descriptor")
	for key: String in effects:
		_check(ALLOWED_EFFECT_KEYS.has(key),
			card_id + " invents no new resource/status effect key: " + key)


func _test_base_card_definitions() -> void:
	var catalog: V3SeamstressPoolCards = _get_catalog()
	var expected_table: Dictionary = _expected_base_records()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen: Dictionary = {}

	_check(not expected_table.is_empty(), "expected base table is non-empty (precondition)")
	_check(not base_ids.is_empty(), "get_base_ids is non-empty (precondition)")
	_check(not all_ids.is_empty(), "get_all_card_ids is non-empty (precondition)")

	for card_id: String in expected_table:
		var expected: Dictionary = expected_table[card_id]
		_check(not seen.has(card_id), card_id + " is authored exactly once in this table")
		seen[card_id] = true
		_check(catalog.has_card(card_id), "catalog has base card " + card_id)
		_check(base_ids.has(card_id), "get_base_ids includes " + card_id)
		_check(base_ids.count(card_id) == 1, card_id + " appears exactly once in get_base_ids")
		_check(all_ids.has(card_id), "get_all_card_ids includes " + card_id)

		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "definition for " + card_id + " is not empty")
		if definition.is_empty():
			continue

		_check(definition.get("id") == card_id, card_id + " id matches key")
		_check(definition.get("display_name") == expected["display_name"], card_id + " display_name")
		_check(not String(definition.get("display_name", "")).ends_with("+"),
			card_id + " base display_name has no trailing +")
		_check(definition.get("owner") == expected["owner"], card_id + " owner is seamstress")
		_check(definition.get("cost") == expected["cost"], card_id + " cost")
		_check(definition.get("cost") is int, card_id + " cost is an integer")
		_check(definition.get("from_positions") == expected["from_positions"], card_id + " from_positions")
		_check(definition.get("target_kind") == expected["target_kind"], card_id + " target_kind")
		_check(definition.get("to_positions") == expected["to_positions"], card_id + " to_positions")
		_check(definition.get("effects") == expected["effects"], card_id + " exact effects payload")
		_check(definition.get("illustration_path") == expected["illustration_path"], card_id + " illustration_path")
		_check(String(definition.get("illustration_path", "")) == "res://assets/paper/cards/" + card_id + ".png",
			card_id + " illustration_path names its own art id")
		_check(definition.get("starting_copies") == 0, card_id + " starting_copies is 0")
		_check(definition.get("rarity") == expected["rarity"], card_id + " rarity")
		_check(definition.get("reward_eligible") == true, card_id + " reward_eligible is true")
		_check(definition.get("upgrade_id") == expected["upgrade_id"], card_id + " upgrade_id points at its plus")
		_check(not definition.has("upgrade_of"), card_id + " base has no upgrade_of")
		_check(catalog.get_upgrade_id(card_id) == expected["upgrade_id"], card_id + " get_upgrade_id resolves plus")

		var expected_keys: Array[String] = _expected_keys(false)
		var actual_keys: Array = definition.keys()
		actual_keys.sort()
		var sorted_expected: Array = expected_keys.duplicate()
		sorted_expected.sort()
		_check(actual_keys == sorted_expected, card_id + " has exactly the documented fields")

		var effects: Dictionary = definition.get("effects", {})
		_check(effects is Dictionary, card_id + " has effect descriptors")
		_check_effect_keys(card_id, effects)
		_check(not effects.has("energy"), card_id + " adds no energy/resource engine")
		_check(not effects.has("draw"), card_id + " adds no draw engine")

		# Legal targeting: only enemy-facing kinds name enemy positions 1..3; ally/party cards name none.
		var target_kind: String = String(definition.get("target_kind", ""))
		var to_positions: Array = definition.get("to_positions", [])
		_check(to_positions is Array, card_id + " to_positions is an Array")
		if ENEMY_TARGET_KINDS.has(target_kind):
			_check(not to_positions.is_empty(), card_id + " enemy target has legal to_positions")
			for position: Variant in to_positions:
				_check(position is int and int(position) >= 1 and int(position) <= 3,
					card_id + " to position is 1..3")
		else:
			_check(to_positions.is_empty(), card_id + " non-enemy target has empty to_positions")
		var from_positions: Array = definition.get("from_positions", [])
		_check(not from_positions.is_empty(), card_id + " has a legal seamstress from_positions")
		for position: Variant in from_positions:
			_check(position is int and int(position) >= 1 and int(position) <= 3,
				card_id + " from position is 1..3")
		_check(definition.get("cost") >= 0 and definition.get("cost") <= 3,
			card_id + " cost is inside the authored 0..3 energy band")


func _test_upgraded_card_definitions() -> void:
	var catalog: V3SeamstressPoolCards = _get_catalog()
	var expected_base: Dictionary = _expected_base_records()
	var expected_plus: Dictionary = _expected_plus_records()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()

	_check(not expected_plus.is_empty(), "expected plus table is non-empty (precondition)")

	for base_id: String in expected_base:
		var plus_id: String = catalog.get_upgrade_id(base_id)
		_check(not plus_id.is_empty(), base_id + " has a valid upgrade_id")
		_check(expected_plus.has(plus_id), plus_id + " is in the expected plus table")
		if not expected_plus.has(plus_id):
			continue

		var expected: Dictionary = expected_plus[plus_id]
		var expected_base_record: Dictionary = expected_base.get(base_id, {})
		var base_definition: Dictionary = catalog.get_definition(base_id)
		var plus_definition: Dictionary = catalog.get_definition(plus_id)
		_check(catalog.has_card(base_id), "catalog has base card " + base_id)

		_check(catalog.has_card(plus_id), "catalog has upgraded card " + plus_id)
		_check(all_ids.has(plus_id), "get_all_card_ids includes " + plus_id)
		_check(all_ids.count(plus_id) == 1, plus_id + " appears exactly once in get_all_card_ids")
		_check(not base_ids.has(plus_id), "plus ID " + plus_id + " is not in get_base_ids")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " is not a base for a further upgrade")
		_check(plus_id == base_id + "_plus", plus_id + " keeps the _plus suffix contract")
		_check(not plus_definition.is_empty(), "definition for " + plus_id + " is not empty")
		if plus_definition.is_empty():
			continue

		_check(plus_definition.get("id") == plus_id, plus_id + " id matches key")
		_check(plus_definition.get("display_name") == expected["display_name"], plus_id + " display_name")
		_check(plus_definition.get("display_name") == String(base_definition.get("display_name", "")) + "+",
			plus_id + " display_name appends '+' to the base name")
		_check(plus_definition.get("owner") == "seamstress", plus_id + " owner is seamstress")
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

		var expected_keys: Array[String] = _expected_keys(true)
		var actual_keys: Array = plus_definition.keys()
		actual_keys.sort()
		var sorted_expected: Array = expected_keys.duplicate()
		sorted_expected.sort()
		_check(actual_keys == sorted_expected, plus_id + " has exactly the documented fields")
		_check_effect_keys(plus_id, plus_definition.get("effects", {}))

		# The '+' keeps the base's owner/position/target/rarity/art contract.
		_check(plus_definition.get("owner") == base_definition.get("owner"), plus_id + " preserves owner")
		_check(plus_definition.get("from_positions") == base_definition.get("from_positions"),
			plus_id + " preserves from_positions")
		_check(plus_definition.get("target_kind") == base_definition.get("target_kind"),
			plus_id + " preserves target_kind")
		_check(plus_definition.get("to_positions") == base_definition.get("to_positions"),
			plus_id + " preserves to_positions")
		_check(plus_definition.get("rarity") == base_definition.get("rarity"), plus_id + " preserves rarity")
		_check(plus_definition.get("illustration_path") == base_definition.get("illustration_path"),
			plus_id + " shares the base art path")
		_check(plus_definition.get("starting_copies") == base_definition.get("starting_copies"),
			plus_id + " preserves starting_copies")
		if expected_base_record.get("effects") != expected.get("effects"):
			_check(plus_definition.get("effects") != base_definition.get("effects"),
				plus_id + " raised printed numbers differ from the base effects")
		else:
			_check(plus_definition.get("effects") == base_definition.get("effects"),
				plus_id + " keeps the identical descriptor its '+' does not scale")


## AC2: the exact needle-and-thread descriptors, and which numbers the '+' may and may not change.
func _test_needle_and_thread_identity() -> void:
	var catalog: V3SeamstressPoolCards = _get_catalog()

	# Needle Rain: attack plus Bleed.
	_check(catalog.get_definition("seamstress_v3_needle_rain").get("effects") == {"damage": 2, "bleed": 3},
		"Needle Rain combines 2 damage with 3 Bleed")
	_check(catalog.get_definition("seamstress_v3_needle_rain_plus").get("effects") == {"damage": 3, "bleed": 4},
		"Needle Rain+ prints 3 damage with 4 Bleed")

	# Scarlet Knot: a bleed-and-weak thread trick, not another plain strike.
	var knot: Dictionary = catalog.get_definition("seamstress_v3_scarlet_knot")
	_check(knot.get("effects").has("bleed") and knot.get("effects").has("weak"),
		"Scarlet Knot combines Bleed and Weak")
	_check(not knot.get("effects").has("damage"), "Scarlet Knot is not a generic strike")
	_check(knot.get("effects").get("weak") == 1, "Scarlet Knot applies exactly 1 Weak")
	_check(catalog.get_definition("seamstress_v3_scarlet_knot_plus").get("effects").get("weak") == 1,
		"Scarlet Knot+ keeps Weak 1 (statuses do not scale)")

	# Bobbin Snag: pins and unravels; no raw Block and no damage strike.
	var snag: Dictionary = catalog.get_definition("seamstress_v3_bobbin_snag")
	_check(snag.get("effects") == {"unravel": 3, "pinned": true}, "Bobbin Snag Unravels 3 and Pins")
	_check(not snag.get("effects").has("block"), "Bobbin Snag is not a raw Block card")
	_check(not snag.get("effects").has("damage"), "Bobbin Snag is not a generic strike")
	_check(catalog.get_definition("seamstress_v3_bobbin_snag_plus").get("effects").get("pinned") == true,
		"Bobbin Snag+ keeps its boolean Pin (booleans do not scale)")
	_check(catalog.get_definition("seamstress_v3_bobbin_snag_plus").get("effects").get("unravel") == 4,
		"Bobbin Snag+ Unravels 4")

	# Patchwork Poultice: one ally healed and Blocked.
	var poultice: Dictionary = catalog.get_definition("seamstress_v3_patchwork_poultice")
	_check(poultice.get("target_kind") == "ally_single" and poultice.get("to_positions") == [],
		"Patchwork Poultice chooses exactly one ally")
	_check(poultice.get("effects") == {"heal": 3, "block": 3}, "Patchwork Poultice heals 3 and Blocks 3")
	_check(catalog.get_definition("seamstress_v3_patchwork_poultice_plus").get("effects") == {"heal": 4, "block": 4},
		"Patchwork Poultice+ heals 4 and Blocks 4")

	# Tether Stitch: two distinct living enemies linked at 50%, explicitly not a third attack.
	for suffix: String in ["", "_plus"]:
		var tether: Dictionary = catalog.get_definition("seamstress_v3_tether_stitch" + suffix)
		_check(tether.get("target_kind") == "enemy_pair", "Tether Stitch targets an enemy_pair" + suffix)
		_check(tether.get("to_positions") == [1, 2, 3], "Tether Stitch names the authored enemy positions" + suffix)
		_check(tether.get("effects") == {"tether_share_percent": 50},
			"Tether Stitch is exactly a 50% linked-damage descriptor" + suffix)
		_check(not tether.get("effects").has("damage"), "Tether Stitch is not a third attack" + suffix)
		_check(not tether.get("effects").has("hits"), "Tether Stitch invents no extra hit count" + suffix)
		_check(not tether.get("effects").has("duration"),
			"Tether Stitch invents no link lifetime" + suffix)
		_check(not tether.get("effects").has("tether"), "Tether Stitch invents no new status name" + suffix)
	_check(catalog.get_definition("seamstress_v3_tether_stitch").get("cost") == 2, "Tether Stitch costs 2")
	_check(catalog.get_definition("seamstress_v3_tether_stitch_plus").get("cost") == 1,
		"Tether Stitch+ instead costs 1 energy")
	_check(catalog.get_definition("seamstress_v3_tether_stitch_plus").get("effects") ==
		catalog.get_definition("seamstress_v3_tether_stitch").get("effects"),
		"Tether Stitch+ keeps the same 50% link descriptor")

	# Darn the Tear: healing plus one debuff removal on the same chosen ally.
	for suffix: String in ["", "_plus"]:
		var darn: Dictionary = catalog.get_definition("seamstress_v3_darn_the_tear" + suffix)
		_check(darn.get("target_kind") == "ally_single" and darn.get("to_positions") == [],
			"Darn the Tear chooses a living ally, not an enemy" + suffix)
		_check(darn.get("effects").get("cleanse_debuff") == 1,
			"Darn the Tear removes exactly one debuff" + suffix)
		_check(int(darn.get("effects").get("heal", 0)) > 0, "Darn the Tear also heals" + suffix)
		_check(not darn.get("effects").has("damage"), "Darn the Tear deals no damage" + suffix)
		_check(not darn.get("effects").has("bleed"), "Darn the Tear never applies Bleed" + suffix)
	_check(catalog.get_definition("seamstress_v3_darn_the_tear").get("effects").get("heal") == 4,
		"Darn the Tear heals 4")
	_check(catalog.get_definition("seamstress_v3_darn_the_tear_plus").get("effects").get("heal") == 6,
		"Darn the Tear+ heals 6")
	_check(catalog.get_definition("seamstress_v3_darn_the_tear").get("effects").get("cleanse_debuff") == 1,
		"Darn the Tear+ keeps cleanse_debuff 1 (does not scale)")

	# Blanket of Barbs: Bleed and Unravel on every living enemy.
	var blanket: Dictionary = catalog.get_definition("seamstress_v3_blanket_of_barbs")
	_check(blanket.get("target_kind") == "enemy_all" and blanket.get("to_positions") == [1, 2, 3],
		"Blanket of Barbs reaches every living enemy position")
	_check(blanket.get("effects") == {"bleed": 2, "unravel": 2}, "Blanket of Barbs Bleeds and Unravels 2")
	_check(not blanket.get("effects").has("block"), "Blanket of Barbs is not a raw Block card")
	_check(catalog.get_definition("seamstress_v3_blanket_of_barbs_plus").get("effects") == {"bleed": 3, "unravel": 3},
		"Blanket of Barbs+ Bleeds and Unravels 3")

	# Midnight Loom: heals, Blocks and cleanses each living party member; names no enemy position.
	var loom: Dictionary = catalog.get_definition("seamstress_v3_midnight_loom")
	_check(loom.get("target_kind") == "party_all", "Midnight Loom targets the whole party")
	_check(loom.get("to_positions") == [], "Midnight Loom names no enemy positions")
	_check(loom.get("effects") == {"heal": 4, "block": 4, "cleanse_debuff": 1},
		"Midnight Loom heals 4, Blocks 4 and removes one debuff per living ally")
	_check(not loom.get("effects").has("revive"), "Midnight Loom does not revive a downed hero")
	_check(catalog.get_definition("seamstress_v3_midnight_loom_plus").get("effects") ==
		{"heal": 6, "block": 6, "cleanse_debuff": 1},
		"Midnight Loom+ heals 6, Blocks 6 and still removes one debuff")

	# Rarity spread: four common, three uncommon, one rare, keyed by name rather than by catalog size.
	_check(catalog.get_definition("seamstress_v3_needle_rain").get("rarity") == "common"
		and catalog.get_definition("seamstress_v3_scarlet_knot").get("rarity") == "common"
		and catalog.get_definition("seamstress_v3_bobbin_snag").get("rarity") == "common"
		and catalog.get_definition("seamstress_v3_patchwork_poultice").get("rarity") == "common",
		"the four needle-and-thread commons are common")
	_check(catalog.get_definition("seamstress_v3_tether_stitch").get("rarity") == "uncommon"
		and catalog.get_definition("seamstress_v3_darn_the_tear").get("rarity") == "uncommon"
		and catalog.get_definition("seamstress_v3_blanket_of_barbs").get("rarity") == "uncommon",
		"the three thread tricks are uncommon")
	_check(catalog.get_definition("seamstress_v3_midnight_loom").get("rarity") == "rare",
		"Midnight Loom is the single rare")


func _test_unknown_and_invalid_ids() -> void:
	var catalog: V3SeamstressPoolCards = _get_catalog()
	var expected_plus: Dictionary = _expected_plus_records()
	var invalid: Array = [
		null, 0, 1, -1, 3.5, true, false, [], ["seamstress_v3_needle_rain"], {},
		{"id": "seamstress_v3_needle_rain"}, StringName("seamstress_v3_needle_rain"),
		"", "nonexistent_id", "seamstress_v3_", "seamstress_v3",
		"seamstress_v3_needle_rain+", "seamstress_v3_needle_rain_plus_plus",
		"seamstress_v3_needle_rain_PLUS", "SEAMSTRESS_V3_NEEDLE_RAIN",
		" seamstress_v3_needle_rain", "seamstress_v3_needle_rain ",
		"seamstress_prick", "seamstress_running_stitch", "warden_strike",
	]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))

	# A '+' is never a base and can never be upgraded again.
	var base_ids: Array[String] = catalog.get_base_ids()
	for plus_id: String in expected_plus:
		_check(catalog.has_card(plus_id), "plus card " + plus_id + " exists")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot itself be upgraded")
		_check(not base_ids.has(plus_id), plus_id + " is not reported as a base ID")
		_check(not catalog.get_definition(plus_id).is_empty(), plus_id + " still resolves as a definition")
	_check(not catalog.has_card("seamstress_v3_midnight_loom_plus_plus"),
		"no double upgrade suffix exists")
	for base_id: String in base_ids:
		_check(base_id.begins_with("seamstress_v3_"), base_id + " stays inside the seamstress v3 namespace")
		_check(not base_id.ends_with("_plus"), base_id + " base IDs never end with _plus")


func _test_mutation_isolation() -> void:
	var catalog: V3SeamstressPoolCards = _get_catalog()

	# Mutating top-level fields of a returned base definition.
	var mutated: Dictionary = catalog.get_definition("seamstress_v3_needle_rain")
	_check(not mutated.is_empty(), "mutation fixture loaded (precondition)")
	if mutated.is_empty():
		return
	mutated["display_name"] = "Corrupted Name"
	mutated["cost"] = 99
	mutated["reward_eligible"] = false
	mutated["target_kind"] = "self"
	mutated["id"] = "mutated"
	var fresh: Dictionary = catalog.get_definition("seamstress_v3_needle_rain")
	_check(fresh.get("display_name") == "Needle Rain", "base display_name protected from caller mutation")
	_check(fresh.get("cost") == 1, "base cost protected from caller mutation")
	_check(fresh.get("reward_eligible") == true, "base reward_eligible protected from caller mutation")
	_check(fresh.get("target_kind") == "enemy_single", "base target_kind protected from caller mutation")
	_check(fresh.get("id") == "seamstress_v3_needle_rain", "base id protected from caller mutation")

	# Mutating the nested effects dictionary.
	var mutated_effects: Dictionary = catalog.get_definition("seamstress_v3_midnight_loom")
	var effects: Dictionary = mutated_effects.get("effects", {})
	effects["heal"] = 9999
	effects["injected_key"] = true
	effects.erase("cleanse_debuff")
	var fresh_effects: Dictionary = catalog.get_definition("seamstress_v3_midnight_loom").get("effects", {})
	_check(fresh_effects.get("heal") == 4, "nested effects heal protected from caller mutation")
	_check(fresh_effects.get("cleanse_debuff") == 1, "nested cleanse protected from caller erase")
	_check(not fresh_effects.has("injected_key"), "nested effects protected from key injection")

	# Mutating the nested position arrays, including an empty TO list.
	var mutated_positions: Dictionary = catalog.get_definition("seamstress_v3_tether_stitch")
	var from_positions: Array = mutated_positions.get("from_positions", [])
	from_positions.clear()
	var to_positions: Array = mutated_positions.get("to_positions", [])
	to_positions.append(999)
	to_positions[0] = 88
	var fresh_positions: Dictionary = catalog.get_definition("seamstress_v3_tether_stitch")
	_check(fresh_positions.get("from_positions") == [2, 3], "nested from_positions protected from caller mutation")
	_check(fresh_positions.get("to_positions") == [1, 2, 3], "nested to_positions protected from caller mutation")
	var empty_to: Dictionary = catalog.get_definition("seamstress_v3_midnight_loom")
	var empty_to_list: Array = empty_to.get("to_positions", [])
	empty_to_list.append(2)
	_check(catalog.get_definition("seamstress_v3_midnight_loom").get("to_positions") == [],
		"empty party TO list cannot be filled by a caller")

	# Mutating a returned '+' definition, its nested effects and its link descriptor.
	var mutated_plus: Dictionary = catalog.get_definition("seamstress_v3_tether_stitch_plus")
	mutated_plus["effects"] = {"tether_share_percent": 100}
	mutated_plus["effects"]["tether_share_percent"] = 100
	mutated_plus["upgrade_of"] = "seamstress_v3_midnight_loom"
	mutated_plus["cost"] = 0
	var fresh_plus: Dictionary = catalog.get_definition("seamstress_v3_tether_stitch_plus")
	_check(fresh_plus.get("effects") == {"tether_share_percent": 50}, "plus effects protected from caller mutation")
	_check(fresh_plus.get("upgrade_of") == "seamstress_v3_tether_stitch", "plus upgrade_of protected from caller mutation")
	_check(fresh_plus.get("cost") == 1, "plus cost protected from caller mutation")

	var shared: Dictionary = catalog.get_definition("seamstress_v3_blanket_of_barbs_plus")
	var shared_effects: Dictionary = shared.get("effects", {})
	shared_effects["bleed"] = 0
	_check(catalog.get_definition("seamstress_v3_blanket_of_barbs_plus").get("effects") == {"bleed": 3, "unravel": 3},
		"plus effect numbers survive an in-place nested edit")

	# Mutating the returned base ID and all-ID arrays.
	var base_ids1: Array[String] = catalog.get_base_ids()
	base_ids1.clear()
	base_ids1.append("fake_card")
	var base_ids2: Array[String] = catalog.get_base_ids()
	_check(not base_ids2.is_empty(), "get_base_ids protected from caller clear")
	_check(not base_ids2.has("fake_card"), "get_base_ids protected from caller injection")
	_check(base_ids2.has("seamstress_v3_midnight_loom"),
		"get_base_ids retains the authored bases after caller mutation")
	var all_ids1: Array[String] = catalog.get_all_card_ids()
	all_ids1.clear()
	all_ids1.append("fake_card")
	var all_ids2: Array[String] = catalog.get_all_card_ids()
	_check(not all_ids2.is_empty(), "get_all_card_ids protected from caller clear")
	_check(not all_ids2.has("fake_card"), "get_all_card_ids protected from caller injection")
	_check(all_ids2.has("seamstress_v3_midnight_loom_plus"),
		"get_all_card_ids retains plus IDs after caller mutation")

	# The same instance stays pristine for later callers.
	_check(catalog.get_definition("seamstress_v3_needle_rain").get("effects") == {"damage": 2, "bleed": 3},
		"repeated lookups return the pristine payload")


## Repeated enumeration and lookup must be identical and must not consume RNG (no wall clock,
## no unseeded randomness); the later Tether handlers alone will draw targets.
func _test_deterministic_and_rng_free() -> void:
	var catalog: V3SeamstressPoolCards = _get_catalog()
	var first_ids: Array[String] = catalog.get_base_ids()
	var first_all: Array[String] = catalog.get_all_card_ids()
	var snapshot: Dictionary = {}
	for card_id: String in first_all:
		snapshot[card_id] = catalog.get_definition(card_id)
	_check(not first_ids.is_empty() and not snapshot.is_empty(), "determinism fixture loaded (precondition)")

	var catalog_b: V3SeamstressPoolCards = V3SeamstressPoolCards.new()
	_check(catalog_b.get_base_ids() == first_ids, "base enumeration is stable across instances")
	_check(catalog_b.get_all_card_ids() == first_all, "all-ID enumeration is stable across instances")
	for card_id: String in first_all:
		_check(catalog_b.get_definition(card_id) == snapshot[card_id],
			"definition is stable across instances: " + card_id)
	_check(catalog.get_base_ids() == first_ids, "repeated base enumeration is unchanged")
	_check(catalog.get_all_card_ids() == first_all, "repeated all-ID enumeration is unchanged")
	for card_id: String in first_all:
		_check(catalog.get_definition(card_id) == snapshot[card_id],
			"repeated lookup is unchanged: " + card_id)

	# Local RandomNumberGenerator parity: exercise the whole API, then compare with an untouched twin.
	var twin: RandomNumberGenerator = RandomNumberGenerator.new()
	twin.seed = 424242
	var twin_next: int = twin.randi()
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	probe.seed = 424242
	for _round: int in range(3):
		catalog.get_base_ids()
		catalog.get_all_card_ids()
		var ids: Array[String] = catalog.get_all_card_ids()
		for card_id: String in ids:
			catalog.get_definition(card_id)
			catalog.has_card(card_id)
			catalog.get_upgrade_id(card_id)
		catalog.get_definition("seamstress_v3_missing")
		catalog.has_card(null)
		catalog.get_upgrade_id(17)
	_check(probe.randi() == twin_next, "catalog calls consume no local RNG draws")

	# Global RNG parity: the same check against Godot's seeded global stream.
	seed(90210)
	var control_global: int = randi()
	seed(90210)
	for card_id: String in catalog.get_all_card_ids():
		catalog.get_definition(card_id)
	catalog.get_base_ids()
	catalog.get_all_card_ids()
	_check(randi() == control_global, "catalog calls consume no global RNG draws")


func _snapshot_catalog_entries(catalog: RefCounted) -> Dictionary:
	var snapshot: Dictionary = {}
	var ids: Array[String] = catalog.get_all_card_ids()
	for card_id: String in ids:
		snapshot[card_id] = catalog.get_definition(card_id)
	return snapshot


func _test_existing_catalogs_untouched() -> void:
	var seamstress_pool: SeamstressPoolCards = SeamstressPoolCards.new()
	var starter_cards: StarterCards = StarterCards.new()
	var pool_before: Dictionary = _snapshot_catalog_entries(seamstress_pool)
	var pool_base_before: Array[String] = seamstress_pool.get_base_ids()
	var starter_before: Dictionary = _snapshot_catalog_entries(starter_cards)
	var starter_deck: Array[String] = starter_cards.get_starting_deck()

	# Exercise the whole new catalog API, including failed lookups, then compare the old catalogs.
	var v3: V3SeamstressPoolCards = _get_catalog()
	var v3_base_ids: Array[String] = v3.get_base_ids()
	var v3_all_ids: Array[String] = v3.get_all_card_ids()
	for card_id: String in v3_all_ids:
		_check(not v3.get_definition(card_id).is_empty(), "v3 definition resolves for " + card_id)
	_check(v3.get_definition("seamstress_running_stitch").is_empty(), "v3 lookup stays closed for v2 IDs")

	_check(not pool_before.is_empty(), "v2 Seamstress pool snapshot is non-empty (precondition)")
	_check(not starter_before.is_empty(), "starter catalog snapshot is non-empty (precondition)")
	_check(not starter_deck.is_empty(), "starting deck is non-empty (precondition)")

	for card_id: String in pool_before:
		_check(seamstress_pool.get_definition(card_id) == pool_before[card_id],
			"v2 Seamstress definition unchanged: " + card_id)
		_check(not v3_all_ids.has(card_id), "v3 catalog does not take over v2 ID " + card_id)
	for card_id: String in starter_before:
		_check(starter_cards.get_definition(card_id) == starter_before[card_id],
			"starter definition unchanged: " + card_id)
		_check(not v3_all_ids.has(card_id), "v3 catalog does not take over starter ID " + card_id)
	_check(seamstress_pool.get_base_ids() == pool_base_before, "v2 Seamstress base ID list unchanged")

	# Named starter membership and authored effects still hold, without pinning a global catalog total.
	for starter_id: String in EXPECTED_STARTERS:
		var expected: Dictionary = EXPECTED_STARTERS[starter_id]
		var record: Dictionary = starter_cards.get_definition(starter_id)
		_check(not record.is_empty(), starter_id + " remains a StarterCards definition")
		_check(record.get("effects") == expected["effects"], starter_id + " printed effects unchanged")
		_check(record.get("starting_copies") == expected["copies"], starter_id + " catalog multiplicity unchanged")
		_check(starter_deck.count(starter_id) == expected["copies"], starter_id + " runtime deck copies unchanged")
		_check(not v3.has_card(starter_id), "v3 catalog does not own starter " + starter_id)
	_check(starter_cards.get_definition("seamstress_prick").get("owner") == "seamstress",
		"seamstress_prick remains Seamstress-owned")
	_check(starter_cards.get_definition("warden_strike").get("owner") == "warden",
		"warden_strike remains Warden-owned")
	_check(starter_cards.get_definition("tinker_pop_shot").get("owner") == "tinker",
		"tinker_pop_shot remains Tinker-owned")

	# The pre-existing Seamstress pool keeps all of its own IDs and never gains a v3 ID.
	for existing_id: String in EXISTING_SEAMSTRESS_POOL_IDS:
		_check(seamstress_pool.has_card(existing_id), "v2 pool still owns " + existing_id)
		_check(seamstress_pool.get_base_ids().has(existing_id), "v2 pool still lists " + existing_id + " as a base")
		_check(seamstress_pool.get_upgrade_id(existing_id) == existing_id + "_plus",
			existing_id + " still upgrades to its own plus")
	_check(seamstress_pool.get_definition("seamstress_running_stitch").get("effects") == {"damage": 2, "bleed": 3},
		"seamstress_running_stitch effects unchanged")
	_check(seamstress_pool.get_definition("seamstress_needle_pin").get("effects") == {"damage": 3, "pinned": true},
		"seamstress_needle_pin effects unchanged")
	_check(seamstress_pool.get_definition("seamstress_darning").get("effects") == {"heal": 4, "block": 3},
		"seamstress_darning effects unchanged")
	var pool_all_ids: Array[String] = seamstress_pool.get_all_card_ids()
	for v3_id: String in v3_all_ids:
		_check(not pool_all_ids.has(v3_id), "v2 pool does not contain v3 card " + v3_id)
		_check(not seamstress_pool.get_base_ids().has(v3_id), "v2 base list excludes v3 card " + v3_id)
		_check(not starter_deck.has(v3_id), "starting deck does not contain v3 card " + v3_id)

	# The authored starter_deck.json agrees with StarterCards and never names a v3 ID.
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "starter_deck.json parses as an Array")
	if parsed is Array:
		var json_deck: Array = parsed
		_check(not json_deck.is_empty(), "starter_deck.json is non-empty (precondition)")
		for starter_id: String in EXPECTED_STARTERS:
			_check(json_deck.count(starter_id) == EXPECTED_STARTERS[starter_id]["copies"],
				starter_id + " JSON deck copies unchanged")
		_check(json_deck == starter_deck, "StarterCards deck and JSON stay identical in membership and order")
		for v3_id: String in v3_all_ids:
			_check(not json_deck.has(v3_id), "starter_deck.json does not contain v3 card " + v3_id)


func _test_not_in_reward_draws() -> void:
	var v3: V3SeamstressPoolCards = _get_catalog()
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
	for existing_id: String in EXISTING_SEAMSTRESS_POOL_IDS:
		_check(candidate_ids.has(existing_id), "reward candidates still include " + existing_id)

	# A real seeded reward draw never offers a v3 Seamstress ID.
	var run_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	run_rng.seed = 255031
	var generated: Dictionary = RunPoolCardRewardOffers.generate_from_authored_pools(
		run_rng, ["warden", "seamstress", "tinker"])
	_check(generated.get("ok") == true, "seeded authored reward draw succeeds (precondition)")
	var offers: Array = generated.get("offers", [])
	_check(offers.size() == 3, "seeded authored reward draw offers three cards (precondition)")
	for offer: Dictionary in offers:
		var offered_id: String = String(offer.get("id", ""))
		_check(not offered_id.is_empty(), "offered card has an ID (precondition)")
		_check(not v3_all_ids.has(offered_id), "reward draw does not offer v3 card " + offered_id)

	# Fail-closed reward resolution: the v3 IDs stay unresolvable until the later wiring task.
	for v3_id: String in v3_all_ids:
		_check(RunPoolCardRewardOffers.resolve_reward_definition(v3_id).is_empty(),
			"v3 card is not reward-resolvable yet: " + v3_id)
	_check(not RunPoolCardRewardOffers.resolve_reward_definition("seamstress_running_stitch").is_empty(),
		"v2 Seamstress card still reward-resolvable")


## ===== V3-1 Bobbin Snag / Bobbin Snag+ paid rules resolver =====
##
## Every fixture below uses the real authorities: a seeded CombatDeck that genuinely dealt a
## five-card hand, a real three-hero CombatParty, an original-slot CombatEnemies roster, the
## genuine CombatPinned token map and a CombatUnravel bound to that exact roster. Nothing here
## mounts the card in the live hand, the reward pool, the map or the app flow.

## A seeded authentic five-card held-hand fixture. The Seamstress is genuinely constructed at her
## real position (the authoritative party records are reordered, never mislabelled), the enemies
## keep their original slots 1-3 with normal/elite/boss tiers, and the gauge is bound to that
## exact roster instance. `enemy_definitions` and `tiers` let an area-card test use a genuinely
## smaller (one- or two-enemy) roster; the defaults are the authored three-enemy line.
func _resolver_fixture(cards: Array[String], seamstress_position: int = 2,
		seed_value: int = 386, enemy_definitions: Array = [],
		tiers: Dictionary = {}) -> Dictionary:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	if seamstress_position != 2:
		var exchanged: Dictionary = party._heroes[seamstress_position - 1]
		party._heroes[seamstress_position - 1] = party._heroes[1]
		party._heroes[1] = exchanged
		party._heroes[seamstress_position - 1]["position"] = seamstress_position
		party._heroes[1]["position"] = 2
	var definitions: Array = enemy_definitions if not enemy_definitions.is_empty() else [
		{"id": "normal_foe", "max_hp": 18},
		{"id": "elite_foe", "max_hp": 22},
		{"id": "boss_foe", "max_hp": 30}]
	var enemies := CombatEnemies.new(definitions)
	var bind_tiers: Dictionary = tiers if not tiers.is_empty() else _default_tiers(definitions.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck_ids: Array[String] = cards.duplicate()
	while deck_ids.size() < CombatDeck.TURN_DRAW:
		deck_ids.append("filler_%d" % deck_ids.size())
	var deck := CombatDeck.new(deck_ids, rng)
	var pinned := CombatPinned.new()
	var unravel := CombatUnravel.new()
	_check(party.is_valid() and enemies.is_valid()
			and party.get_hero(seamstress_position)["id"] == "seamstress"
			and party.get_hero(seamstress_position)["hp"] == 30,
			"resolver fixture has a living Seamstress at real seat %d" % seamstress_position)
	_check(unravel.bind_roster(enemies, bind_tiers),
		"resolver fixture gauge is bound to the exact roster and tiers")
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
			and deck.hand.size() == 5 and deck._rng == rng,
			"resolver fixture begins a real seeded five-card turn")
	for card_id: String in cards:
		_check(deck.hand.has(card_id), "authored printing is genuinely held: " + card_id)
	return {"deck": deck, "party": party, "enemies": enemies,
		"pinned": pinned, "unravel": unravel}


## The authored tier line for a genuinely smaller roster: slot 1 normal, slot 2 elite, slot 3 boss.
func _default_tiers(enemy_count: int) -> Dictionary:
	match enemy_count:
		1:
			return {1: "normal"}
		2:
			return {1: "normal", 2: "elite"}
	return {1: "normal", 2: "elite", 3: "boss"}


## Complete authoritative snapshot, taken from the SAME seeded instances before and after a call,
## so a no-mutation assertion cannot pass on independently rebuilt fixtures.
func _resolver_state(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var pinned: CombatPinned = f["pinned"]
	var unravel: CombatUnravel = f["unravel"]
	return {
		"draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"exhausted": deck.exhausted.duplicate(),
		"turn": deck.turn_active,
		"energy": deck.energy,
		"rng": deck._rng.state,
		"heroes": f["party"].get_heroes(),
		"enemies": f["enemies"].get_enemies(),
		"tokens": pinned._pinner_by_position.duplicate(true),
		"gauges": unravel._gauges.duplicate(true),
		"tiers": unravel._tiers_by_position.duplicate(true),
		"bound_roster": unravel._bound_enemies,
	}


func _snag_play(f: Dictionary, card_id: Variant, target: int,
		resolver: RefCounted = null) -> Dictionary:
	var service: RefCounted = resolver if resolver != null else snag_resolver
	return service.play_card(f["deck"], f["party"], f["enemies"], f["pinned"],
		f["unravel"], card_id, target)


func _snag_spent_once(before: Dictionary, f: Dictionary, card_id: String,
		label: String) -> void:
	var after: Dictionary = _resolver_state(f)
	_check(after["energy"] == before["energy"] - 1
			and after["hand"].size() == before["hand"].size() - 1
			and after["hand"].count(card_id) == before["hand"].count(card_id) - 1
			and after["discard"].size() == before["discard"].size() + 1
			and after["discard"][-1] == card_id
			and after["draw"] == before["draw"]
			and after["rng"] == before["rng"]
			and after["heroes"] == before["heroes"],
			label + " pays exactly one energy, discards one held copy and preserves draw/RNG/party")


## AC1: both authentic printings from both legal seats against every original enemy slot.
func _test_bobbin_snag_paid_cast() -> void:
	_check(snag_resolver.is_supported_card(SNAG)
			and snag_resolver.is_supported_card(SNAG_PLUS)
			and not snag_resolver.is_supported_card(V2_SNAG)
			and not snag_resolver.is_supported_card("seamstress_v3_needle_rain"),
			"only the two authentic V3 Bobbin Snag printings are supported")
	for record: Dictionary in [
		{"id": SNAG, "seat": 2, "unravel": 3},
		{"id": SNAG_PLUS, "seat": 3, "unravel": 4},
	]:
		var card_id: String = record["id"]
		for target: int in [1, 2, 3]:
			var f: Dictionary = _resolver_fixture([card_id], record["seat"])
			var enemies: CombatEnemies = f["enemies"]
			var pinned: CombatPinned = f["pinned"]
			var unravel: CombatUnravel = f["unravel"]
			var enemy_max: int = [18, 22, 30][target - 1]
			_check(enemies.gain_block(target, 6)
					and enemies.apply_statuses({target: {"bleed": 2, "exposed": 1}}),
					"%s fixture keeps the target's Block and unrelated statuses" % card_id)
			var untouched: Array[Dictionary] = []
			for position: int in [1, 2, 3]:
				if position != target:
					untouched.append(enemies.get_enemy(position))
			var before: Dictionary = _resolver_state(f)
			var r: Dictionary = _snag_play(f, card_id, target)
			var gauge: Dictionary = unravel.get_snapshot(target)
			_check(r.get("ok", false) and r["reason"] == "applied"
					and r["card_id"] == card_id and r["cost"] == 1
					and r["energy_spent"] == 1
					and r["owner_position"] == record["seat"]
					and r["target_position"] == target
					and r["printed_unravel"] == record["unravel"]
					and r["unravel_applied"] == record["unravel"],
					"%s from seat %d onto slot %d publishes an exact receipt"
							% [card_id, record["seat"], target])
			_check(r["gauge_before"]["gauge"] == 0
					and r["gauge_before"]["threshold"] == [8, 12, 16][target - 1]
					and gauge == {"gauge": record["unravel"],
						"threshold": [8, 12, 16][target - 1],
						"unravelled": false, "skip_pending": false}
					and r["unravel_snapshot"] == gauge
					and r["gauge"] == record["unravel"]
					and not r["skip_pending"],
					"%s adds exactly %d Unravel through the bound gauge on slot %d"
							% [card_id, record["unravel"], target])
			_check(r["pinned"] and r["pinner"] == "seamstress"
					and r["prior_pinner"] == ""
					and pinned.pinner_for_enemy(target) == "seamstress"
					and pinned._pinner_by_position == {target: "seamstress"},
					"%s pins exactly the chosen slot for the Seamstress: %d" % [card_id, target])
			_check(r["damage"] == 0 and r["hp_loss"] == 0 and r["block_absorbed"] == 0
					and not r["target_slain"]
					and r["hp_before"] == enemy_max and r["hp_after"] == enemy_max
					and r["block_before"] == 6 and r["block_after"] == 6,
					"%s is control, not a strike: no damage on slot %d" % [card_id, target])
			var live: Dictionary = enemies.get_enemy(target)
			_check(live["hp"] == enemy_max and live["block"] == 6
					and live["position"] == target and live["id"] == before["enemies"][target - 1]["id"]
					and live["statuses"] == {"bleed": 2, "exposed": 1},
					"%s preserves HP, Block, slot and unrelated statuses: %d" % [card_id, target])
			var others_live: Array[Dictionary] = []
			var other_gauges_untouched := true
			for position: int in [1, 2, 3]:
				if position != target:
					others_live.append(enemies.get_enemy(position))
					other_gauges_untouched = other_gauges_untouched \
						and unravel.get_snapshot(position)["gauge"] == 0
			_check(others_live == untouched and other_gauges_untouched,
					"%s touches no other original enemy slot or gauge: %d" % [card_id, target])
			_snag_spent_once(before, f, card_id, "%s on slot %d" % [card_id, target])


## AC2: needle-and-thread control across the real 8/12/16 thresholds, one pending skip, and the
## blocked / already-pinned living enemy cases.
func _test_bobbin_snag_needle_and_thread() -> void:
	# Normal (slot 1, threshold 8): three base charges clamp at eight.
	var f: Dictionary = _resolver_fixture([SNAG, SNAG, SNAG, SNAG], 2)
	var unravel: CombatUnravel = f["unravel"]
	f["deck"].combat_state.energy = 4
	_check(f["deck"].energy == 4, "normal-threshold fixture funds four real paid casts")
	_check(unravel.get_snapshot(1)["threshold"] == 8
			and unravel.get_snapshot(2)["threshold"] == 12
			and unravel.get_snapshot(3)["threshold"] == 16,
			"the real roster starts at normal/elite/boss thresholds 8/12/16")
	var before: Dictionary = _resolver_state(f)
	var counters: Array[int] = []
	for index: int in range(3):
		var cast: Dictionary = _snag_play(f, SNAG, 1)
		_check(cast.get("ok", false), "normal charge %d resolves" % (index + 1))
		counters.append(int(cast.get("gauge", -1)))
	_check(counters == [3, 6, 8], "normal gauge charges 3, 6 then clamps at 8")
	_check(unravel.get_snapshot(1) == {"gauge": 8, "threshold": 8,
			"unravelled": true, "skip_pending": true},
			"normal threshold queues exactly one action skip")
	var pending_before: Dictionary = _resolver_state(f)
	var pending: Dictionary = _snag_play(f, SNAG, 1)
	_check(pending.get("ok", false) and pending["gauge"] == 8
			and pending["unravelled"] and pending["skip_pending"]
			and unravel.get_snapshot(1) == pending["gauge_before"],
			"a charge while the skip is pending neither stacks a second skip nor moves the gauge")
	_snag_spent_once(pending_before, f, SNAG, "pending-skip charge")
	_check(_resolver_state(f)["rng"] == before["rng"]
			and _resolver_state(f)["enemies"] == before["enemies"],
			"threshold work draws no RNG and changes no enemy HP/Block/status/slot")
	_check(unravel.consume_action_skip(f["enemies"], 1)
			and unravel.get_snapshot(1) == {"gauge": 0, "threshold": 12,
				"unravelled": false, "skip_pending": false}
			and not unravel.consume_action_skip(f["enemies"], 1),
			"one queued skip resets the gauge to 0, raises the threshold by 4 and is consumed once")

	# Elite (slot 2, threshold 12): three plus charges land exactly on twelve.
	f = _resolver_fixture([SNAG_PLUS, SNAG_PLUS, SNAG_PLUS], 3)
	unravel = f["unravel"]
	for index: int in range(3):
		_check(_snag_play(f, SNAG_PLUS, 2).get("ok", false),
			"elite charge %d resolves" % (index + 1))
	_check(unravel.get_snapshot(2) == {"gauge": 12, "threshold": 12,
			"unravelled": true, "skip_pending": true},
			"elite reaches its authored threshold of twelve with one pending skip")
	_check(unravel.get_snapshot(1)["gauge"] == 0 and unravel.get_snapshot(3)["gauge"] == 0,
			"the elite charge stays on its original slot only")
	_check(unravel.consume_action_skip(f["enemies"], 2)
			and unravel.get_snapshot(2)["threshold"] == 16
			and unravel.get_snapshot(2)["gauge"] == 0
			and not unravel.consume_action_skip(f["enemies"], 2),
			"the elite skip resets to zero and raises the threshold to sixteen once")

	# Boss (slot 3, threshold 16): four plus charges land exactly on sixteen.
	f = _resolver_fixture([SNAG_PLUS, SNAG_PLUS, SNAG_PLUS, SNAG_PLUS], 2)
	unravel = f["unravel"]
	f["deck"].combat_state.energy = 4
	for index: int in range(4):
		_check(_snag_play(f, SNAG_PLUS, 3).get("ok", false),
			"boss charge %d resolves" % (index + 1))
	_check(unravel.get_snapshot(3) == {"gauge": 16, "threshold": 16,
			"unravelled": true, "skip_pending": true},
			"boss reaches its authored threshold of sixteen with one pending skip")
	_check(unravel.consume_action_skip(f["enemies"], 3)
			and unravel.get_snapshot(3)["threshold"] == 20
			and unravel.get_snapshot(3)["gauge"] == 0,
			"the boss skip resets to zero and raises the threshold to twenty")

	# A blocked, already cross-pinned living enemy is still a legal target: Block and HP stay put
	# and the later Snag replaces the earlier pinner.
	f = _resolver_fixture([SNAG], 2)
	var enemies: CombatEnemies = f["enemies"]
	var pinned: CombatPinned = f["pinned"]
	unravel = f["unravel"]
	_check(enemies.gain_block(1, 9) and pinned.pin_enemy(enemies, 1, "warden"),
			"blocked and already-pinned living enemy precondition")
	before = _resolver_state(f)
	var replaced: Dictionary = _snag_play(f, SNAG, 1)
	_check(replaced.get("ok", false) and replaced["prior_pinner"] == "warden"
			and replaced["pinner"] == "seamstress"
			and pinned.pinner_for_enemy(1) == "seamstress"
			and enemies.get_enemy(1)["block"] == 9
			and enemies.get_enemy(1)["hp"] == 18
			and unravel.get_snapshot(1)["gauge"] == 3,
			"a blocked, already-pinned living enemy is pinned and charged, not attacked")
	_snag_spent_once(before, f, SNAG, "blocked and re-pinned cast")


## AC3: the pin is a real cross-hero setup measured through CombatPinned's own bonus/consume API.
func _test_bobbin_snag_cross_hero_setup() -> void:
	var f: Dictionary = _resolver_fixture([SNAG, SNAG_PLUS], 2)
	var enemies: CombatEnemies = f["enemies"]
	var pinned: CombatPinned = f["pinned"]
	_check(_snag_play(f, SNAG, 1).get("ok", false), "cross-hero setup pin resolves")
	_check(pinned.pinner_for_enemy(1) == "seamstress"
			and pinned.bonus_for_attack(enemies, 1, "warden") == 5
			and pinned.bonus_for_attack(enemies, 1, "tinker") == 5
			and pinned.bonus_for_attack(enemies, 1, "seamstress") == 0,
			"a later confirmed different-hero attack gets the shared +5; the pinning Seamstress does not")
	_check(pinned.bonus_for_attack(enemies, 1, "warden") == 5
			and pinned.pinner_for_enemy(1) == "seamstress",
			"reading the +5 preview repeatedly never consumes the token")
	_check(not pinned.consume_after_attack(1, "warden", false)
			and pinned.pinner_for_enemy(1) == "seamstress",
			"an unconfirmed preview never consumes the token")
	_check(not pinned.consume_after_attack(1, "seamstress", true)
			and pinned.pinner_for_enemy(1) == "seamstress"
			and pinned.bonus_for_attack(enemies, 1, "warden") == 5,
			"a same-owner confirmed attack neither consumes nor weakens the token")
	_check(pinned.consume_after_attack(1, "tinker", true)
			and pinned.pinner_for_enemy(1) == ""
			and pinned.bonus_for_attack(enemies, 1, "warden") == 0,
			"one confirmed different-hero attack consumes the +5 exactly once")
	_check(not pinned.consume_after_attack(1, "warden", true),
			"a spent token cannot be consumed twice")

	var other: Dictionary = _resolver_fixture([SNAG_PLUS], 3)
	_check(other["pinned"].pin_enemy(other["enemies"], 2, "warden"),
			"prior Warden pin precondition")
	var replaced: Dictionary = _snag_play(other, SNAG_PLUS, 2)
	_check(replaced.get("ok", false) and replaced["prior_pinner"] == "warden"
			and other["pinned"].pinner_for_enemy(2) == "seamstress"
			and other["pinned"].bonus_for_attack(other["enemies"], 2, "warden") == 5
			and other["pinned"].bonus_for_attack(other["enemies"], 2, "seamstress") == 0,
			"a later successful Snag replaces the prior pinner and re-arms the cross-hero +5")


## AC4: every refusal is a complete no-op on the same seeded instances.
func _snag_reject_with(f: Dictionary, card_id: Variant, target: int,
		pinned: Variant, unravel: Variant, label: String,
		resolver: RefCounted = null) -> void:
	var before: Dictionary = _resolver_state(f)
	var service: RefCounted = resolver if resolver != null else snag_resolver
	var r: Dictionary = service.play_card(f["deck"], f["party"], f["enemies"],
		pinned, unravel, card_id, target)
	_check(not r.get("ok", false) and not String(r.get("reason", "")).is_empty(),
			label + " refuses with an explicit reason")
	_check(_resolver_state(f) == before,
			label + " leaves deck, party, enemies, pin, gauge and RNG untouched")


func _snag_reject(f: Dictionary, card_id: Variant, target: int, label: String) -> void:
	_snag_reject_with(f, card_id, target, f["pinned"], f["unravel"], label)


func _test_bobbin_snag_rejections() -> void:
	# Unknown / unsupported / unheld printings and the v2 control card of a similar name.
	var f: Dictionary = _resolver_fixture([SNAG, V2_SNAG], 2)
	_snag_reject(f, SNAG_PLUS, 1, "unheld plus printing")
	_snag_reject(f, V2_SNAG, 1, "held v2 Snag is not this V3 printing")
	_snag_reject(f, "seamstress_v3_bobbin_snag_plus_plus", 1, "unknown V3 card id")
	_snag_reject(f, 17, 1, "non-string card id")
	_snag_reject(f, null, 1, "null card id")

	# A forged definition for an otherwise valid, held ID is refused by the catalog seam.
	var forged_effects := V3SeamstressPoolCards.new()
	forged_effects._definitions[SNAG]["effects"]["unravel"] = 9
	var forged_resolver := CombatSeamstressV3BobbinSnagCards.new(forged_effects)
	_snag_reject_with(f, SNAG, 1, f["pinned"], f["unravel"],
			"forged Unravel printing", forged_resolver)
	var forged_seat := V3SeamstressPoolCards.new()
	forged_seat._definitions[SNAG]["from_positions"] = [1, 2, 3]
	_snag_reject_with(f, SNAG, 1, f["pinned"], f["unravel"],
			"forged printing that widens FROM", CombatSeamstressV3BobbinSnagCards.new(forged_seat))
	var forged_link := V3SeamstressPoolCards.new()
	forged_link._definitions[SNAG]["upgrade_id"] = SNAG
	_snag_reject_with(f, SNAG, 1, f["pinned"], f["unravel"],
			"forged base/+ link", CombatSeamstressV3BobbinSnagCards.new(forged_link))
	_check(snag_resolver.is_supported_card(SNAG) and snag_resolver.is_supported_card(SNAG_PLUS),
			"the shipped resolver still accepts both authentic printings after the forged runs")

	# Not held, inactive turn, unaffordable.
	f = _resolver_fixture([SNAG], 2)
	f["deck"].hand.erase(SNAG)
	_snag_reject(f, SNAG, 1, "printing no longer in hand")
	f = _resolver_fixture([SNAG], 2)
	_check(f["deck"].end_turn() and not f["deck"].turn_active, "ended real player turn fixture")
	_snag_reject(f, SNAG, 1, "inactive turn")
	f = _resolver_fixture([SNAG], 2)
	f["deck"].combat_state.energy = 0
	_snag_reject(f, SNAG, 1, "insufficient energy")

	# Torn, misplaced and duplicated Seamstress.
	f = _resolver_fixture([SNAG], 2)
	_check(f["party"].apply_damage(2, 30) and f["party"].is_downed(2), "downed Seamstress fixture")
	_snag_reject(f, SNAG, 1, "downed Seamstress")
	f = _resolver_fixture([SNAG], 2)
	f["party"]._heroes[1]["position"] = 1
	_snag_reject(f, SNAG, 1, "misplaced Seamstress record")
	f = _resolver_fixture([SNAG], 2)
	f["party"]._heroes[0]["id"] = "seamstress"
	_snag_reject(f, SNAG, 1, "duplicated Seamstress")
	f = _resolver_fixture([SNAG], 1)
	_snag_reject(f, SNAG, 1, "Seamstress in the illegal front seat")
	f = _resolver_fixture([SNAG], 2)
	f["party"]._heroes[1]["id"] = "mender"
	_snag_reject(f, SNAG, 1, "no Seamstress in the party")

	# Target slots: out of range, out of the printed window, and slain.
	f = _resolver_fixture([SNAG], 2)
	_snag_reject(f, SNAG, 0, "target slot 0")
	_snag_reject(f, SNAG, 4, "unoccupied target slot 4")
	_snag_reject(f, SNAG, -1, "negative target slot")
	f = _resolver_fixture([SNAG], 2)
	_check(f["enemies"].apply_damage(1, 18) and f["enemies"].is_slain(1), "slain target fixture")
	_snag_reject(f, SNAG, 1, "slain target enemy")

	# Missing / foreign authorities.
	f = _resolver_fixture([SNAG], 2)
	_snag_reject_with(f, SNAG, 1, null, f["unravel"], "missing Pinned authority")
	_snag_reject_with(f, SNAG, 1, f["pinned"], null, "missing Unravel authority")
	_snag_reject_with(f, SNAG, 1, f["pinned"], CombatUnravel.new(), "unbound Unravel gauge")
	var alien := CombatEnemies.new([{"id": "alien", "max_hp": 10}])
	var wrong := CombatUnravel.new()
	_check(wrong.bind_roster(alien, {1: "normal"}), "different roster gauge genuinely bound")
	_snag_reject_with(f, SNAG, 1, f["pinned"], wrong, "wrong-roster Unravel gauge")
	_check(wrong.get_snapshot(1)["gauge"] == 0, "the wrong-roster gauge is never charged")
	var stage: Dictionary = _resolver_state(f)
	_check(not snag_resolver.play_card(null, f["party"], f["enemies"], f["pinned"],
			f["unravel"], SNAG, 1).get("ok", false)
			and _resolver_state(f) == stage, "missing deck refuses with no mutation")
	_check(not snag_resolver.play_card(f["deck"], null, f["enemies"], f["pinned"],
			f["unravel"], SNAG, 1).get("ok", false)
			and _resolver_state(f) == stage, "missing party refuses with no mutation")
	_check(not snag_resolver.play_card(f["deck"], f["party"], null, f["pinned"],
			f["unravel"], SNAG, 1).get("ok", false)
			and _resolver_state(f) == stage, "missing enemy roster refuses with no mutation")

	# Corrupt authoritative state fails closed before payment.
	f = _resolver_fixture([SNAG], 2)
	f["pinned"]._pinner_by_position[1] = "not_a_pinner"
	_snag_reject(f, SNAG, 1, "malformed Pinned token")
	f = _resolver_fixture([SNAG], 2)
	f["pinned"]._pinner_by_position[4] = "warden"
	_snag_reject(f, SNAG, 1, "Pinned token on an unoccupied slot")
	f = _resolver_fixture([SNAG], 2)
	f["enemies"]._enemies[0]["statuses"] = {"unknown": 1}
	_snag_reject(f, SNAG, 1, "malformed enemy status")
	f = _resolver_fixture([SNAG], 2)
	f["party"]._heroes[0]["statuses"] = {"unknown": 1}
	_snag_reject(f, SNAG, 1, "malformed hero status")
	f = _resolver_fixture([SNAG], 2)
	f["unravel"]._gauges[1]["gauge"] = 99
	_snag_reject(f, SNAG, 1, "gauge above its own threshold")
	f = _resolver_fixture([SNAG], 2)
	f["unravel"]._gauges[1] = {"gauge": CombatSeamstressV3BobbinSnagCards.MAX_COUNTER,
		"threshold": CombatSeamstressV3BobbinSnagCards.MAX_COUNTER,
		"unravelled": true, "skip_pending": true}
	_snag_reject(f, SNAG, 1, "Unravel counter overflow")


func _test_bobbin_snag_resolver() -> void:
	_test_bobbin_snag_paid_cast()
	_test_bobbin_snag_needle_and_thread()
	_test_bobbin_snag_cross_hero_setup()
	_test_bobbin_snag_rejections()


## ===== V3-1 Blanket of Barbs / Blanket of Barbs+ target-free area resolver =====
##
## Every fixture below uses the real authorities: a seeded CombatDeck that genuinely dealt a
## five-card hand, a real three-hero CombatParty, an original-slot CombatEnemies roster and a
## genuine CombatUnravel bound to that exact roster. Nothing here mounts the card in the live hand,
## the reward pool, the map or the app flow.

## Mixed authentic line state: Block on two living slots, pre-existing Bleed on two slots, an
## unrelated debuff, a one-shot dodge token, hero Block and a hero debuff. Everything the sweep must
## preserve exactly.
func _blanket_stage_mixed_line(f: Dictionary) -> bool:
	var enemies: CombatEnemies = f["enemies"]
	var party: CombatParty = f["party"]
	var staged: bool = enemies.gain_block(1, 5) \
		and enemies.gain_block(3, 2) \
		and enemies.apply_statuses({1: {"bleed": 2, "weak": 1}, 2: {"exposed": 2},
			3: {"bleed": 4}}) \
		and party.gain_block(1, 4)
	if staged:
		# A one-shot Dodge token is not one of the enemy-applicable effects, so the authoritative
		# record is the only place the shared token lives.
		enemies._enemies[2]["statuses"]["dodge_next_attack"] = 1
		party._heroes[0]["statuses"] = {"weak": 1}
	return staged


## Independently specified expected state after one successful sweep: the exact two-energy payment,
## the one discarded held copy, the printed Bleed (plus her +1 passive) added to each swept slot and
## the documented gauge arithmetic. Everything else must stay byte-for-byte identical.
func _blanket_expected_after(before: Dictionary, card_id: String,
		positions: Array, bleed_add: int, unravel_add: int, cost: int = 2) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(before["energy"]) - cost
	var hand: Array = expected["hand"]
	var index: int = hand.find(card_id)
	if index >= 0:
		hand.remove_at(index)
	var discard: Array = expected["discard"]
	discard.append(card_id)
	for position: int in positions:
		var record: Dictionary = expected["enemies"][position - 1]
		var statuses: Dictionary = record.get("statuses", {}).duplicate(true)
		statuses["bleed"] = int(statuses.get("bleed", 0)) + bleed_add
		record["statuses"] = statuses
		expected["gauges"][position] = _blanket_expected_gauge(
			expected["gauges"][position], unravel_add)
	return expected


## The documented shared Unravel arithmetic, restated independently of the authority: a pending skip
## absorbs the charge, otherwise the gauge climbs and clamps at its own threshold while queueing the
## single action skip.
func _blanket_expected_gauge(gauge: Dictionary, amount: int) -> Dictionary:
	var result: Dictionary = gauge.duplicate(true)
	if result["unravelled"] and result["skip_pending"]:
		return result
	var value: int = int(result["gauge"]) + amount
	if value >= int(result["threshold"]):
		value = int(result["threshold"])
		result["unravelled"] = true
		result["skip_pending"] = true
	result["gauge"] = value
	return result


func _blanket_play(f: Dictionary, card_id: Variant, resolver: RefCounted = null) -> Dictionary:
	var service: RefCounted = resolver if resolver != null else blanket_resolver
	return service.play_card(f["deck"], f["party"], f["enemies"], f["unravel"], card_id)


## AC1: both authentic printings from both legal seats, every living slot paid for exactly once.
func _test_blanket_paid_cast() -> void:
	_check(blanket_resolver.is_supported_card(BLANKET)
			and blanket_resolver.is_supported_card(BLANKET_PLUS)
			and not blanket_resolver.is_supported_card(V2_BLANKET)
			and not blanket_resolver.is_supported_card(SNAG)
			and not blanket_resolver.is_supported_card("seamstress_v3_blanket_of_barbs_plus_plus")
			and not blanket_resolver.is_supported_card(null),
			"only the two authentic V3 Blanket of Barbs printings are supported")
	for record: Dictionary in [
		{"id": BLANKET, "seat": 2, "bleed": 3, "unravel": 2},
		{"id": BLANKET_PLUS, "seat": 3, "bleed": 4, "unravel": 3},
	]:
		var card_id: String = record["id"]
		var f: Dictionary = _resolver_fixture([card_id], record["seat"])
		var enemies: CombatEnemies = f["enemies"]
		var unravel: CombatUnravel = f["unravel"]
		_check(_blanket_stage_mixed_line(f),
			"%s fixture stages mixed Block/Bleed/token state on the real line" % card_id)
		var before: Dictionary = _resolver_state(f)
		var r: Dictionary = _blanket_play(f, card_id)
		_check(r.get("ok", false) and r["reason"] == "applied" and r["card_id"] == card_id
				and r["cost"] == 2 and r["energy_spent"] == 2 and r["energy_after"] == 1
				and r["owner_position"] == record["seat"]
				and r["target_kind"] == "enemy_all"
				and r["targets"] == [1, 2, 3] and r["target_count"] == 3,
				"%s from seat %d sweeps the whole living line and pays two energy"
						% [card_id, record["seat"]])
		_check(r["printed_bleed"] == int(record["bleed"]) - 1
				and r["passive_bleed"] == 1
				and r["bleed_applied"] == int(record["bleed"])
				and r["printed_unravel"] == int(record["unravel"])
				and r["unravel_applied"] == int(record["unravel"]),
				"%s prints Bleed %d and Unravel %d plus her +1 Bleed passive"
						% [card_id, int(record["bleed"]) - 1, int(record["unravel"])])
		_check(r["damage"] == 0 and r["hp_loss"] == 0 and r["block_absorbed"] == 0,
				"%s is control, not a strike: no damage and no Block absorbed" % card_id)
		var bleed_before_by_slot: Array = [2, 0, 4]
		var block_by_slot: Array = [5, 0, 2]
		var hp_by_slot: Array = [18, 22, 30]
		var unrelated_by_slot := {
			1: {"weak": 1},
			2: {"exposed": 2},
			3: {"dodge_next_attack": 1},
		}
		var effects: Array = r["effects"]
		_check(effects.size() == 3, "%s reports one effect entry per living original slot" % card_id)
		for index: int in range(mini(3, effects.size())):
			var entry: Dictionary = effects[index]
			var position: int = index + 1
			_check(entry["position"] == position
					and entry["bleed_before"] == int(bleed_before_by_slot[index])
					and entry["bleed_added"] == int(record["bleed"])
					and entry["bleed_after"] == int(bleed_before_by_slot[index]) + int(record["bleed"])
					and entry["gauge_before"] == {"gauge": 0, "threshold": [8, 12, 16][index],
						"unravelled": false, "skip_pending": false}
					and entry["gauge_after"] == {"gauge": int(record["unravel"]),
						"threshold": [8, 12, 16][index], "unravelled": false, "skip_pending": false}
					and entry["hp_before"] == int(hp_by_slot[index])
					and entry["hp_after"] == int(hp_by_slot[index])
					and entry["block_before"] == int(block_by_slot[index])
					and entry["block_after"] == int(block_by_slot[index])
					and not entry["slain"],
					"%s reports exact per-slot Bleed, Unravel and preserved HP/Block on slot %d"
							% [card_id, position])
		for position: int in [1, 2, 3]:
			var live: Dictionary = enemies.get_enemy(position)
			var statuses: Dictionary = live.get("statuses", {})
			var unrelated: Dictionary = unrelated_by_slot[position]
			var expected_bleed: int = int(bleed_before_by_slot[position - 1]) + int(record["bleed"])
			_check(statuses.get("bleed", 0) == expected_bleed,
					"%s stacks Bleed on original slot %d" % [card_id, position])
			var unrelated_preserved := true
			for key: String in unrelated:
				unrelated_preserved = unrelated_preserved and statuses.get(key) == unrelated[key]
			_check(unrelated_preserved,
					"%s preserves unrelated statuses on original slot %d" % [card_id, position])
			_check(live["hp"] == int(hp_by_slot[position - 1])
					and live["block"] == int(block_by_slot[position - 1])
					and live["position"] == position,
					"%s leaves HP, Block and original position on slot %d" % [card_id, position])
			_check(unravel.get_snapshot(position) == {"gauge": int(record["unravel"]),
					"threshold": [8, 12, 16][position - 1],
					"unravelled": false, "skip_pending": false},
					"%s adds exactly %d Unravel through the bound gauge on slot %d"
							% [card_id, int(record["unravel"]), position])
		_check(_resolver_state(f) == _blanket_expected_after(before, card_id, [1, 2, 3],
				int(record["bleed"]), int(record["unravel"])),
				"%s pays exactly two energy and one held copy and changes nothing else" % card_id)


## AC2: the sweep reaches only living authentic slots, on full, partial and dead-slot rosters, and
## leaves every slain slot, gauge and pile exactly as it found it.
func _test_blanket_living_line() -> void:
	# A slain middle slot is skipped even though its original slot is inside the printed TO window.
	var f: Dictionary = _resolver_fixture([BLANKET], 2)
	var enemies: CombatEnemies = f["enemies"]
	var unravel: CombatUnravel = f["unravel"]
	_check(enemies.gain_block(2, 7) and enemies.apply_statuses({2: {"bleed": 3, "weak": 1}})
			and enemies.apply_damage(2, 29) and enemies.is_slain(2),
			"slain middle slot fixture keeps its Block, Bleed and original position")
	var before: Dictionary = _resolver_state(f)
	var r: Dictionary = _blanket_play(f, BLANKET)
	_check(r.get("ok", false) and r["targets"] == [1, 3] and r["target_count"] == 2,
			"a dead enemy inside the printed TO window is skipped, not replaced by a neighbour")
	_check(enemies.get_enemy(2)["hp"] == 0 and enemies.get_enemy(2)["block"] == 0
			and enemies.get_enemy(2).get("statuses", {}) == {"bleed": 3, "weak": 1}
			and unravel.get_snapshot(2) == {"gauge": 0, "threshold": 12,
				"unravelled": false, "skip_pending": false},
			"the slain slot receives neither Bleed nor Unravel and keeps its record")
	_check(enemies.get_enemy(1).get("statuses", {}).get("bleed") == 3
			and enemies.get_enemy(3).get("statuses", {}).get("bleed") == 3
			and unravel.get_snapshot(1)["gauge"] == 2 and unravel.get_snapshot(3)["gauge"] == 2,
			"the surviving original slots 1 and 3 are swept")
	_check(_resolver_state(f) == _blanket_expected_after(before, BLANKET, [1, 3], 3, 2),
			"skipping a dead slot still pays two energy and one copy and changes nothing else")

	# A two-enemy roster never indexes the unoccupied third board seat.
	f = _resolver_fixture([BLANKET], 2, 386, [
		{"id": "small_a", "max_hp": 12},
		{"id": "small_b", "max_hp": 14}])
	enemies = f["enemies"]
	unravel = f["unravel"]
	_check(unravel.get_snapshot(1)["threshold"] == 8 and unravel.get_snapshot(2)["threshold"] == 12
			and unravel.get_snapshot(3).is_empty(),
			"two-enemy fixture binds gauges 1-2 only")
	before = _resolver_state(f)
	r = _blanket_play(f, BLANKET)
	_check(r.get("ok", false) and r["targets"] == [1, 2] and r["target_count"] == 2,
			"a two-enemy roster is swept across its authentic original slots only")
	_check(enemies.get_enemy(1).get("statuses", {}).get("bleed") == 3
			and enemies.get_enemy(2).get("statuses", {}).get("bleed") == 3
			and unravel.get_snapshot(1)["gauge"] == 2 and unravel.get_snapshot(2)["gauge"] == 2,
			"both living slots of a two-enemy roster gain Bleed and Unravel")
	_check(_resolver_state(f) == _blanket_expected_after(before, BLANKET, [1, 2], 3, 2),
			"a two-enemy sweep changes nothing beyond the printed line")

	# A one-enemy roster reaches exactly its single original slot.
	f = _resolver_fixture([BLANKET_PLUS], 3, 386, [{"id": "lone_foe", "max_hp": 10}])
	enemies = f["enemies"]
	unravel = f["unravel"]
	before = _resolver_state(f)
	r = _blanket_play(f, BLANKET_PLUS)
	_check(r.get("ok", false) and r["targets"] == [1] and r["target_count"] == 1
			and enemies.get_enemy(1).get("statuses", {}).get("bleed") == 4
			and unravel.get_snapshot(1) == {"gauge": 3, "threshold": 8,
				"unravelled": false, "skip_pending": false},
			"a one-enemy roster receives the plus printing's Bleed 4 and Unravel 3")
	_check(_resolver_state(f) == _blanket_expected_after(before, BLANKET_PLUS, [1], 4, 3),
			"a one-enemy sweep changes nothing beyond the printed line")


## AC2: the real 8/12/16 thresholds, the single pending skip and the after-skip reset all stay the
## CombatUnravel authority's own behaviour.
func _test_blanket_thresholds_and_skip() -> void:
	var f: Dictionary = _resolver_fixture([BLANKET, BLANKET, BLANKET], 2)
	var enemies: CombatEnemies = f["enemies"]
	var unravel: CombatUnravel = f["unravel"]
	f["deck"].combat_state.energy = 6
	_check(f["deck"].energy == 6, "threshold fixture funds three real paid sweeps")
	_check(unravel.apply_unravel(enemies, 1, 7) and unravel.apply_unravel(enemies, 2, 11)
			and unravel.apply_unravel(enemies, 3, 15),
			"pre-charge near the real 8/12/16 thresholds through the shared gauge")
	_check(unravel.get_snapshot(1) == {"gauge": 7, "threshold": 8,
				"unravelled": false, "skip_pending": false}
			and unravel.get_snapshot(2) == {"gauge": 11, "threshold": 12,
				"unravelled": false, "skip_pending": false}
			and unravel.get_snapshot(3) == {"gauge": 15, "threshold": 16,
				"unravelled": false, "skip_pending": false},
			"near-threshold gauges are inert before the sweep")
	var before: Dictionary = _resolver_state(f)
	var r: Dictionary = _blanket_play(f, BLANKET)
	_check(r.get("ok", false) and r["targets"] == [1, 2, 3],
			"a near-threshold sweep resolves across the whole line")
	_check(unravel.get_snapshot(1) == {"gauge": 8, "threshold": 8,
				"unravelled": true, "skip_pending": true}
			and unravel.get_snapshot(2) == {"gauge": 12, "threshold": 12,
				"unravelled": true, "skip_pending": true}
			and unravel.get_snapshot(3) == {"gauge": 16, "threshold": 16,
				"unravelled": true, "skip_pending": true},
			"each real threshold clamps its own gauge and queues exactly one action skip")
	_check(_resolver_state(f) == _blanket_expected_after(before, BLANKET, [1, 2, 3], 3, 2),
			"threshold work changes only the paid copy, the Bleed and the clamped gauges")

	# A second sweep while every skip is pending neither stacks a second skip nor moves a gauge.
	before = _resolver_state(f)
	var pending: Dictionary = _blanket_play(f, BLANKET)
	_check(pending.get("ok", false) and pending["targets"] == [1, 2, 3]
			and unravel.get_snapshot(1) == {"gauge": 8, "threshold": 8,
				"unravelled": true, "skip_pending": true}
			and unravel.get_snapshot(2) == {"gauge": 12, "threshold": 12,
				"unravelled": true, "skip_pending": true}
			and unravel.get_snapshot(3) == {"gauge": 16, "threshold": 16,
				"unravelled": true, "skip_pending": true},
			"a sweep while skips are pending adds no second skip and moves no clamped gauge")
	_check(_resolver_state(f) == _blanket_expected_after(before, BLANKET, [1, 2, 3], 3, 2),
			"the pending-skip sweep still pays normally and leaves every unrelated field alone")

	# One consumed skip resets only its own slot, raises its threshold by 4 and is consumed once.
	_check(unravel.consume_action_skip(enemies, 2)
			and unravel.get_snapshot(2) == {"gauge": 0, "threshold": 16,
				"unravelled": false, "skip_pending": false}
			and not unravel.consume_action_skip(enemies, 2)
			and unravel.get_snapshot(1) == {"gauge": 8, "threshold": 8,
				"unravelled": true, "skip_pending": true}
			and unravel.get_snapshot(3) == {"gauge": 16, "threshold": 16,
				"unravelled": true, "skip_pending": true},
			"one queued skip resets only its own gauge, raises its threshold by 4 and is spent once")

	# The next sweep charges the reset elite gauge from zero against its raised threshold.
	before = _resolver_state(f)
	var after_skip: Dictionary = _blanket_play(f, BLANKET)
	_check(after_skip.get("ok", false)
			and unravel.get_snapshot(2) == {"gauge": 2, "threshold": 16,
				"unravelled": false, "skip_pending": false}
			and unravel.get_snapshot(1)["gauge"] == 8
			and unravel.get_snapshot(3)["gauge"] == 16,
			"after the skip the swept gauge charges from zero against its raised threshold")
	_check(_resolver_state(f) == _blanket_expected_after(before, BLANKET, [1, 2, 3], 3, 2),
			"the after-skip sweep changes nothing else")


## AC3: every refusal is a complete no-op on the same seeded instances.
func _blanket_reject_with(f: Dictionary, card_id: Variant, unravel: Variant,
		label: String, resolver: RefCounted = null) -> void:
	var before: Dictionary = _resolver_state(f)
	var service: RefCounted = resolver if resolver != null else blanket_resolver
	var r: Dictionary = service.play_card(f["deck"], f["party"], f["enemies"], unravel, card_id)
	_check(not r.get("ok", false) and not String(r.get("reason", "")).is_empty(),
			label + " refuses with an explicit reason")
	_check(_resolver_state(f) == before,
			label + " leaves deck, party, enemies, gauge and RNG untouched")


func _blanket_reject(f: Dictionary, card_id: Variant, label: String) -> void:
	_blanket_reject_with(f, card_id, f["unravel"], label)


func _test_blanket_rejections() -> void:
	# Unknown / unsupported / unheld printings, including the v2 blanket of a similar name.
	var f: Dictionary = _resolver_fixture([BLANKET, V2_BLANKET], 2)
	_blanket_reject(f, BLANKET_PLUS, "unheld plus printing")
	_blanket_reject(f, V2_BLANKET, "held v2 blanket is not this V3 printing")
	_blanket_reject(f, SNAG, "held sibling v3 card is not this printing")
	_blanket_reject(f, "seamstress_v3_blanket_of_barbs_plus_plus", "unknown V3 card id")
	_blanket_reject(f, 17, "non-string card id")
	_blanket_reject(f, null, "null card id")

	# Forged records for an otherwise valid, held ID are refused by the catalog seam.
	var forged_effects := V3SeamstressPoolCards.new()
	forged_effects._definitions[BLANKET]["effects"]["bleed"] = 5
	_blanket_reject_with(f, BLANKET, f["unravel"], "forged Bleed printing",
		CombatSeamstressV3BlanketCards.new(forged_effects))
	var forged_extra := V3SeamstressPoolCards.new()
	forged_extra._definitions[BLANKET]["effects"]["damage"] = 1
	_blanket_reject_with(f, BLANKET, f["unravel"], "printing with an invented damage effect",
		CombatSeamstressV3BlanketCards.new(forged_extra))
	var forged_seat := V3SeamstressPoolCards.new()
	forged_seat._definitions[BLANKET]["from_positions"] = [1, 2, 3]
	_blanket_reject_with(f, BLANKET, f["unravel"], "forged printing that widens FROM",
		CombatSeamstressV3BlanketCards.new(forged_seat))
	var forged_cost := V3SeamstressPoolCards.new()
	forged_cost._definitions[BLANKET]["cost"] = 1
	_blanket_reject_with(f, BLANKET, f["unravel"], "forged cheaper cost",
		CombatSeamstressV3BlanketCards.new(forged_cost))
	var forged_rarity := V3SeamstressPoolCards.new()
	forged_rarity._definitions[BLANKET]["rarity"] = "rare"
	_blanket_reject_with(f, BLANKET, f["unravel"], "forged rarity",
		CombatSeamstressV3BlanketCards.new(forged_rarity))
	var forged_link := V3SeamstressPoolCards.new()
	forged_link._definitions[BLANKET]["upgrade_id"] = BLANKET
	_blanket_reject_with(f, BLANKET, f["unravel"], "forged base/+ link",
		CombatSeamstressV3BlanketCards.new(forged_link))
	var forged_companion := V3SeamstressPoolCards.new()
	forged_companion._definitions[BLANKET_PLUS]["upgrade_of"] = "seamstress_v3_midnight_loom"
	_blanket_reject_with(f, BLANKET, f["unravel"], "forged companion link on the plus printing",
		CombatSeamstressV3BlanketCards.new(forged_companion))
	var forged_plus_reward := V3SeamstressPoolCards.new()
	forged_plus_reward._definitions[BLANKET_PLUS]["reward_eligible"] = true
	_blanket_reject_with(f, BLANKET, f["unravel"], "plus printing marked reward eligible",
		CombatSeamstressV3BlanketCards.new(forged_plus_reward))
	_check(blanket_resolver.is_supported_card(BLANKET)
			and blanket_resolver.is_supported_card(BLANKET_PLUS),
			"the shipped resolver still accepts both authentic printings after the forged runs")

	# Not held, inactive turn, unaffordable.
	f = _resolver_fixture([BLANKET], 2)
	f["deck"].hand.erase(BLANKET)
	_blanket_reject(f, BLANKET, "printing no longer in hand")
	f = _resolver_fixture([BLANKET], 2)
	_check(f["deck"].end_turn() and not f["deck"].turn_active, "ended real player turn fixture")
	_blanket_reject(f, BLANKET, "inactive turn")
	f = _resolver_fixture([BLANKET], 2)
	f["deck"].combat_state.energy = 1
	_blanket_reject(f, BLANKET, "insufficient energy")

	# Torn, misplaced, duplicated and wrong-seat owner.
	f = _resolver_fixture([BLANKET], 2)
	_check(f["party"].apply_damage(2, 30) and f["party"].is_downed(2), "downed Seamstress fixture")
	_blanket_reject(f, BLANKET, "downed Seamstress")
	f = _resolver_fixture([BLANKET], 2)
	f["party"]._heroes[1]["position"] = 1
	_blanket_reject(f, BLANKET, "misplaced Seamstress record")
	f = _resolver_fixture([BLANKET], 2)
	f["party"]._heroes[0]["id"] = "seamstress"
	_blanket_reject(f, BLANKET, "duplicated Seamstress")
	f = _resolver_fixture([BLANKET], 1)
	_blanket_reject(f, BLANKET, "Seamstress in the illegal front seat")
	f = _resolver_fixture([BLANKET], 2)
	f["party"]._heroes[1]["id"] = "mender"
	_blanket_reject(f, BLANKET, "no Seamstress in the party")

	# Corrupt authoritative state fails closed before payment.
	f = _resolver_fixture([BLANKET], 2)
	f["enemies"]._enemies[0]["statuses"] = {"unknown": 1}
	_blanket_reject(f, BLANKET, "unknown enemy status")
	f = _resolver_fixture([BLANKET], 2)
	f["enemies"]._enemies[1]["statuses"] = {"bleed": -1}
	_blanket_reject(f, BLANKET, "negative enemy Bleed counter")
	f = _resolver_fixture([BLANKET], 2)
	f["enemies"]._enemies[2]["statuses"] = {"dodge_next_attack": 2}
	_blanket_reject(f, BLANKET, "malformed one-shot enemy token")
	f = _resolver_fixture([BLANKET], 2)
	f["enemies"]._enemies[0]["statuses"] = ["bleed"]
	_blanket_reject(f, BLANKET, "non-dictionary enemy status map")
	f = _resolver_fixture([BLANKET], 2)
	f["party"]._heroes[0]["statuses"] = {"cannot_buff_next_turn": 1}
	_blanket_reject(f, BLANKET, "non-boolean Fear token on a hero")
	f = _resolver_fixture([BLANKET], 2)
	f["party"]._heroes[2]["statuses"] = {"unknown": 1}
	_blanket_reject(f, BLANKET, "unknown hero status")
	f = _resolver_fixture([BLANKET], 2)
	f["enemies"]._enemies[0]["statuses"] = {"bleed": CombatEnemies.MAX_INT}
	_blanket_reject(f, BLANKET, "Bleed counter overflow on a swept slot")
	f = _resolver_fixture([BLANKET], 2)
	f["unravel"]._gauges[1]["gauge"] = 99
	_blanket_reject(f, BLANKET, "gauge above its own threshold")
	f = _resolver_fixture([BLANKET], 2)
	f["unravel"]._gauges[3] = {"gauge": 0, "threshold": 16, "unravelled": false}
	_blanket_reject(f, BLANKET, "malformed gauge record on a swept slot")
	f = _resolver_fixture([BLANKET], 2)
	f["unravel"]._gauges[1] = {"gauge": CombatSeamstressV3BlanketCards.MAX_COUNTER,
		"threshold": CombatSeamstressV3BlanketCards.MAX_COUNTER,
		"unravelled": true, "skip_pending": true}
	_blanket_reject(f, BLANKET, "Unravel counter overflow")
	# Every original slot's gauge is validated, including one whose slot is already slain.
	f = _resolver_fixture([BLANKET], 2)
	_check(f["enemies"].apply_damage(2, 22) and f["enemies"].is_slain(2), "slain-slot gauge fixture")
	f["unravel"]._gauges[2] = {"gauge": 13, "threshold": 12,
		"unravelled": false, "skip_pending": false}
	_blanket_reject(f, BLANKET, "malformed gauge on a slain original slot")

	# Missing / foreign authorities.
	f = _resolver_fixture([BLANKET], 2)
	_blanket_reject_with(f, BLANKET, null, "missing Unravel authority")
	_blanket_reject_with(f, BLANKET, CombatUnravel.new(), "unbound Unravel gauge")
	var alien := CombatEnemies.new([{"id": "alien", "max_hp": 10}])
	var wrong := CombatUnravel.new()
	_check(wrong.bind_roster(alien, {1: "normal"}), "different roster gauge genuinely bound")
	_blanket_reject_with(f, BLANKET, wrong, "wrong-roster Unravel gauge")
	_check(wrong.get_snapshot(1)["gauge"] == 0, "the wrong-roster gauge is never charged")
	var stage: Dictionary = _resolver_state(f)
	_check(not blanket_resolver.play_card(null, f["party"], f["enemies"], f["unravel"], BLANKET)
			.get("ok", false) and _resolver_state(f) == stage,
			"missing deck refuses with no mutation")
	_check(not blanket_resolver.play_card(f["deck"], null, f["enemies"], f["unravel"], BLANKET)
			.get("ok", false) and _resolver_state(f) == stage,
			"missing party refuses with no mutation")
	_check(not blanket_resolver.play_card(f["deck"], f["party"], null, f["unravel"], BLANKET)
			.get("ok", false) and _resolver_state(f) == stage,
			"missing enemy roster refuses with no mutation")

	# A wholly slain line has nothing to sweep and is refused before payment.
	f = _resolver_fixture([BLANKET], 2)
	_check(f["enemies"].apply_damage(1, 18) and f["enemies"].apply_damage(2, 22)
			and f["enemies"].apply_damage(3, 30) and f["enemies"].is_victorious(),
			"wholly slain roster fixture")
	_blanket_reject(f, BLANKET, "wholly slain roster")

	# Replay after the sole held copy was already discarded is refused with no second payment.
	var replay: Dictionary = _resolver_fixture([BLANKET], 3)
	var first: Dictionary = _blanket_play(replay, BLANKET)
	_check(first.get("ok", false) and replay["deck"].hand.count(BLANKET) == 0
			and replay["deck"].discard_pile.count(BLANKET) == 1,
			"the first authentic sweep genuinely spends the sole held copy")
	_blanket_reject(replay, BLANKET, "replay after the sole copy was discarded")


func _test_blanket_resolver() -> void:
	_test_blanket_paid_cast()
	_test_blanket_living_line()
	_test_blanket_thresholds_and_skip()
	_test_blanket_rejections()
