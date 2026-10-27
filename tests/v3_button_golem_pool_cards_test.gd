extends SceneTree
## V3-1 Button Golem reward-pool catalog contract, plus the paid rules services over the four
## authentic Roll printings and the four reward-pool area printings (Popping Volley and
## Buttonstorm, base and "+").
## CATALOG + RULES SERVICE: the catalog checks below assert printed intent only, independently of
## any resolver. The appended cases drive real seeded CombatDeck/CombatParty/CombatEnemies state
## through those resolver classes; no live hand, reward, party-picker or starter-deck wiring is
## assumed or tested here (a later task owns that route).

const ScriptClass = preload("res://data/cards/button_golem_pool_cards.gd")
const StarterCardsScript = preload("res://data/cards/starter_cards.gd")
const ButtonGolemStarterScript = preload("res://data/cards/button_golem_starter_cards.gd")
const RollResolverScript = preload("res://scripts/combat_button_golem_roll_cards.gd")
const PopResolverScript = preload("res://scripts/combat_button_golem_pop_cards.gd")
const AreaResolverScript = preload("res://scripts/combat_button_golem_area_cards.gd")
const RewardOffersScript = preload("res://scripts/run_pool_card_reward_offers.gd")

## A pool catalog source that serves caller-supplied records, so a rewritten field or a relinked
## upgrade can be proven inert before any energy, hand, HP, Block, counter or RNG state moves.
class ForgedArea extends "res://scripts/combat_button_golem_area_cards.gd":
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		var record: Dictionary = forged.get(card_id, {})
		return record.duplicate(true)

## The four authentic Roll printings, each authenticated against its OWN authored catalog.
const ROLL_PRINTINGS := {
	"button_golem_starter_threadwheel_roll": {"catalog": "starter", "block": 5},
	"button_golem_starter_threadwheel_roll_plus": {"catalog": "starter", "block": 7},
	"button_golem_button_roll": {"catalog": "pool", "block": 5},
	"button_golem_button_roll_plus": {"catalog": "pool", "block": 8},
}

## The four authentic reward-pool area printings: Popping Volley prints damage per hit, Buttonstorm
## prints damage per earlier popped button, and each authors its own FROM seats and TO slots.
const AREA_PRINTINGS := {
	"button_golem_popping_volley": {"shape": "volley", "from": [1, 2], "magnitude": 3},
	"button_golem_popping_volley_plus": {"shape": "volley", "from": [1, 2], "magnitude": 4},
	"button_golem_buttonstorm": {"shape": "storm", "from": [1], "magnitude": 4},
	"button_golem_buttonstorm_plus": {"shape": "storm", "from": [1], "magnitude": 5},
}

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_rarity_and_cost_shape()
	_test_detached_results()
	_test_invalid_ids()
	_test_rng_state()
	_test_starter_and_reward_isolation()
	_test_roll_printings()
	_test_roll_paid_resolution()
	_test_roll_second_roll_from_new_seat()
	_test_roll_refusals()
	_test_area_printings()
	_test_area_volley_paid_resolution()
	_test_area_storm_paid_resolution()
	_test_area_storm_replay()
	_test_area_storm_reads_pop_counter()
	_test_area_refusals()
	_test_area_forged_catalog()
	if failures.is_empty():
		print("v3_button_golem_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_button_golem_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"button_golem_pop_button": {
			"name": "Pop Button", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"require_owner_block": 5, "spend_owner_block": 5, "damage": 9,
				"buttons_popped_gain": 1},
			"plus_cost": 1,
			"plus_effects": {"require_owner_block": 5, "spend_owner_block": 5, "damage": 12,
				"buttons_popped_gain": 1}},
		"button_golem_button_roll": {
			"name": "Button Roll", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"swap_with_target_ally": true, "block": 5},
			"plus_cost": 1,
			"plus_effects": {"swap_with_target_ally": true, "block": 8}},
		"button_golem_button_knuckle": {
			"name": "Button Knuckle", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 5, "pinned": true},
			"plus_cost": 1,
			"plus_effects": {"damage": 7, "pinned": true}},
		"button_golem_eyelet_guard": {
			"name": "Eyelet Guard", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block": 6, "thorns": 2, "duration": 1},
			"plus_cost": 1,
			"plus_effects": {"block": 9, "thorns": 3, "duration": 1}},
		"button_golem_sew_on": {
			"name": "Sew On", "rarity": "uncommon", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block_per_button_popped": 1},
			"plus_cost": 1,
			"plus_effects": {"block_per_button_popped": 2}},
		"button_golem_buttonhole_snag": {
			"name": "Buttonhole Snag", "rarity": "uncommon", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 3, "tangled": 2},
			"plus_cost": 1,
			"plus_effects": {"damage": 4, "tangled": 3}},
		"button_golem_popping_volley": {
			"name": "Popping Volley", "rarity": "uncommon", "cost": 2,
			"from": [1, 2], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage": 3, "hit_count": 2, "independent_hits": true,
				"living_targets_only": true},
			"plus_cost": 2,
			"plus_effects": {"damage": 4, "hit_count": 2, "independent_hits": true,
				"living_targets_only": true}},
		"button_golem_buttonstorm": {
			"name": "Buttonstorm", "rarity": "rare", "cost": 2,
			"from": [1], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage_per_button_popped": 4, "living_targets_only": true},
			"plus_cost": 2,
			"plus_effects": {"damage_per_button_popped": 5, "living_targets_only": true}},
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
		"starting_copies": 0,
		"rarity": spec["rarity"],
		"reward_eligible": not upgraded,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


func _test_all_base_and_upgrades() -> void:
	var catalog = ScriptClass.new()
	var cases: Dictionary = _cases()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen: Dictionary = {}
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id), base_id + " is a distinct base identifier")
		seen[base_id] = true
		_check(base_ids.has(base_id), base_id + " is listed as a base")
		_check(base_ids.count(base_id) == 1, base_id + " has one base-list occurrence")
		_check(not base_ids.has(plus_id), plus_id + " is not a reward base")
		_check(all_ids.has(base_id) and all_ids.has(plus_id), base_id + " both IDs discoverable")
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id), base_id + " both exist")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
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
			_check(record.get("effects") is Dictionary, card_id + " has effect descriptors")
			_check(record.get("owner") == "button_golem", card_id + " belongs to Button Golem")
			_check(record.get("starting_copies") == 0, card_id + " is not a starter copy")
			_check(record.get("reward_eligible") == not upgraded,
				card_id + " reward eligibility matches base/upgrade role")
		_check(base_id != plus_id, base_id + " upgrade has a distinct stable ID")


## These assertions check printed descriptor keys and numbers only (NOT live combat).
## The paid counterparts live elsewhere: CombatButtonGolemPopCards (Block payment plus the popped
## counter), CombatButtonGolemSewCards (per-pop Block) and CombatButtonGolemAreaCards, which owns the
## Popping Volley and Buttonstorm area attacks appended below.
func _test_special_descriptors() -> void:
	var catalog = ScriptClass.new()
	for suffix: String in ["", "_plus"]:
		var pop: Dictionary = catalog.get_definition("button_golem_pop_button" + suffix)
		var pop_effects: Dictionary = pop.get("effects", {})
		_check(pop_effects.get("require_owner_block") == 5,
			"printed descriptor (NOT live combat): Pop Button requires exactly 5 owner Block" + suffix)
		_check(pop_effects.get("spend_owner_block") == 5,
			"printed descriptor (NOT live combat): Pop Button spends exactly 5 owner Block" + suffix)
		_check(pop_effects.get("damage") == (12 if suffix == "_plus" else 9),
			"printed descriptor (NOT live combat): Pop Button deals its exact damage" + suffix)
		_check(pop_effects.get("buttons_popped_gain") == 1,
			"printed descriptor (NOT live combat): Pop Button counts one popped button" + suffix)

		var roll: Dictionary = catalog.get_definition("button_golem_button_roll" + suffix)
		var roll_effects: Dictionary = roll.get("effects", {})
		_check(roll.get("target_kind") == "ally_single" and roll.get("to_positions") == [],
			"printed descriptor (NOT live combat): Button Roll selects a living ally" + suffix)
		_check(roll_effects.get("swap_with_target_ally") == true,
			"printed descriptor (NOT live combat): Button Roll swaps with the target ally" + suffix)
		_check(roll_effects.get("block") == (8 if suffix == "_plus" else 5),
			"printed descriptor (NOT live combat): Button Roll gains its exact Block" + suffix)

		var sew: Dictionary = catalog.get_definition("button_golem_sew_on" + suffix)
		var sew_effects: Dictionary = sew.get("effects", {})
		_check(sew_effects.get("block_per_button_popped") == (2 if suffix == "_plus" else 1),
			"printed descriptor (NOT live combat): Sew On pays per popped button" + suffix)
		_check(sew_effects.size() == 1 and not sew_effects.has("buttons_popped_gain"),
			"printed descriptor (NOT live combat): Sew On references but never consumes popped buttons" + suffix)

		var storm: Dictionary = catalog.get_definition("button_golem_buttonstorm" + suffix)
		var storm_effects: Dictionary = storm.get("effects", {})
		_check(storm_effects.get("damage_per_button_popped") == (5 if suffix == "_plus" else 4),
			"printed descriptor (NOT live combat): Buttonstorm scales per popped button" + suffix)
		_check(storm_effects.get("living_targets_only") == true,
			"printed descriptor (NOT live combat): Buttonstorm skips dead enemies" + suffix)
		_check(storm_effects.size() == 2 and not storm_effects.has("spend_owner_block"),
			"printed descriptor (NOT live combat): Buttonstorm does not consume the popped count" + suffix)

		var volley: Dictionary = catalog.get_definition("button_golem_popping_volley" + suffix)
		var volley_effects: Dictionary = volley.get("effects", {})
		_check(volley_effects.get("damage") == (4 if suffix == "_plus" else 3)
			and volley_effects.get("hit_count") == 2,
			"printed descriptor (NOT live combat): Popping Volley is two exact damage hits" + suffix)
		_check(volley_effects.get("independent_hits") == true
			and volley_effects.get("living_targets_only") == true,
			"printed descriptor (NOT live combat): Popping Volley hits independently on living enemies" + suffix)


## Rarity and cost shape for the eight named bases, tallied from their own fixture IDs.
func _test_rarity_and_cost_shape() -> void:
	var catalog = ScriptClass.new()
	var cases: Dictionary = _cases()
	var rarity_counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	for base_id: String in cases:
		var record: Dictionary = catalog.get_definition(base_id)
		var rarity: String = str(record.get("rarity", ""))
		if rarity_counts.has(rarity):
			rarity_counts[rarity] = int(rarity_counts[rarity]) + 1
	_check(rarity_counts["common"] == 4, "This catalog authors exactly 4 common bases")
	_check(rarity_counts["uncommon"] == 3, "This catalog authors exactly 3 uncommon bases")
	_check(rarity_counts["rare"] == 1, "This catalog authors exactly 1 rare base")

	var zero_cost: int = 0
	for card_id: String in catalog.get_all_card_ids():
		var record: Dictionary = catalog.get_definition(card_id)
		if int(record.get("cost", -1)) == 0:
			zero_cost += 1
		_check(int(record.get("cost", -1)) >= 1, card_id + " costs at least 1 (few 0-cost cards)")
	_check(zero_cost == 0, "The Button Golem reward pool contains zero 0-cost cards")


func _test_detached_results() -> void:
	var catalog = ScriptClass.new()
	var sample: Dictionary = catalog.get_definition("button_golem_pop_button")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["spend_owner_block"] = -99
	sample["effects"]["buttons_popped_gain"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["upgrade_id"] = "mutated_plus"
	var pristine: Dictionary = catalog.get_definition("button_golem_pop_button")
	_check(pristine.get("effects") == {"require_owner_block": 5, "spend_owner_block": 5,
		"damage": 9, "buttons_popped_gain": 1},
		"Pop Button effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [1, 2], "Pop Button FROM array is detached")
	_check(pristine.get("to_positions") == [1, 2], "Pop Button TO array is detached")
	_check(pristine.get("id") == "button_golem_pop_button", "record metadata is detached")
	_check(pristine.get("upgrade_id") == "button_golem_pop_button_plus",
		"upgrade pointer metadata is detached")

	var upgraded: Dictionary = catalog.get_definition("button_golem_eyelet_guard_plus")
	upgraded["effects"]["block"] = 900
	upgraded["effects"]["thorns"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	upgraded["upgrade_of"] = "mutated"
	_check(catalog.get_definition("button_golem_eyelet_guard_plus").get("effects")
		== {"block": 9, "thorns": 3, "duration": 1},
		"upgraded effects are deeply detached")
	_check(catalog.get_definition("button_golem_eyelet_guard_plus").get("from_positions")
		== [1, 2, 3], "upgraded FROM is detached")
	_check(catalog.get_definition("button_golem_eyelet_guard_plus").get("to_positions") == [],
		"empty upgraded TO is detached")
	_check(catalog.get_definition("button_golem_eyelet_guard_plus").get("upgrade_of")
		== "button_golem_eyelet_guard", "upgrade_of pointer is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("button_golem_buttonstorm") and all_ids.has("button_golem_sew_on_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("button_golem_buttonstorm"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("button_golem_sew_on_plus"), "all-ID array is a fresh copy")
	_check(ScriptClass.new().get_definition("button_golem_pop_button").get("effects")
		== pristine.get("effects"), "fresh instance retains the canonical definition")


func _test_invalid_ids() -> void:
	var catalog = ScriptClass.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("button_golem_pop_button"),
		"", "button_golem_not_a_card", "button_golem_pop_button+",
		"button_golem_pop_button_plus_plus", "button_golem_sew_on_plus_plus"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_rng_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8675309
	var initial_state: int = rng.state
	var catalog = ScriptClass.new()
	for id: String in catalog.get_all_card_ids():
		var definition: Dictionary = catalog.get_definition(id)
		_check(not definition.is_empty(), id + " resolves during RNG guard")
	for id: String in catalog.get_base_ids():
		_check(catalog.get_upgrade_id(id) != "", id + " has an upgrade during RNG guard")
	catalog.get_definition("button_golem_unknown")
	catalog.get_definition(17)
	_check(rng.state == initial_state,
		"constructing and querying the catalog consumes no seeded run RNG")


func _test_starter_and_reward_isolation() -> void:
	var catalog = ScriptClass.new()
	var starter := StarterCardsScript.new()
	var deck: Array[String] = starter.get_starting_deck()
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "authored starter_deck.json parses as array")
	_check(not deck.is_empty(), "current three-hero starter deck is non-empty")
	if not parsed is Array:
		return
	_check(deck == parsed, "StarterCards deck and JSON stay identical in membership and order")
	var heroes: Dictionary = {"warden": true, "seamstress": true, "tinker": true}
	for card_id: String in deck:
		var starter_record: Dictionary = starter.get_definition(card_id)
		_check(not starter_record.is_empty(), card_id + " is still a shared starter definition")
		_check(heroes.has(str(starter_record.get("owner", ""))),
			card_id + " still belongs to one of the three current heroes")
		_check(not card_id.begins_with("button_golem_"),
			card_id + " is not a Button Golem pool card")

	for card_id: String in catalog.get_all_card_ids():
		_check(not starter.has_card(card_id), card_id + " has not entered StarterCards")
		_check(not deck.has(card_id), card_id + " is absent from the live starting deck")
		_check(not parsed.has(card_id), card_id + " is absent from the authored starter deck")

	# The live D2-1 reward adapter still enumerates only the three wired hero pools.
	var rewarded_ids: Dictionary = {}
	for candidate: Dictionary in RewardOffersScript.get_authored_base_candidates():
		rewarded_ids[str(candidate.get("id", ""))] = true
	for base_id: String in catalog.get_base_ids():
		_check(not rewarded_ids.has(base_id), base_id + " is not registered as a playable reward")


# ---------------------------------------------------------------------------------------------
# Threadwheel Roll / Button Roll: paid ally swap plus printed self Block on the Button Golem.
# ---------------------------------------------------------------------------------------------

## AC2: the four authentic Roll printings, each read back from its OWN authored catalog with
## authored metadata, exact effects and base/plus links (never a catalog total or ID list).
func _test_roll_printings() -> void:
	var resolver = RollResolverScript.new()
	_check(ROLL_PRINTINGS.size() == 4, "four distinct Roll printings are enumerated")
	for card_id: String in ROLL_PRINTINGS:
		var definition: Dictionary = _roll_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			card_id + " is authentically authored in its own catalog")
		_check(resolver.is_supported_card(card_id),
			card_id + " is a resolver-supported Roll printing")
		_check(definition.get("owner") == "button_golem", card_id + " is owned by the Golem")
		_check(definition.get("cost") == 1, card_id + " costs exactly one energy")
		_check(definition.get("target_kind") == "ally_single",
			card_id + " selects one ally, never an enemy slot")
		_check(definition.get("from_positions") == [1, 2, 3],
			card_id + " plays from any hero seat 1-3")
		_check(definition.get("to_positions") == [],
			card_id + " authors no TO restriction, so any living ally may be chosen")
		_check(definition.get("effects") == _roll_expected_effects(card_id),
			card_id + " prints exactly " + str(_roll_expected_effects(card_id)))
		_check(_roll_printed_block(card_id) == int(ROLL_PRINTINGS[card_id]["block"]),
			card_id + " prints " + str(ROLL_PRINTINGS[card_id]["block"]) + " Block")
		var base_id: String = card_id.trim_suffix("_plus")
		_check(_roll_definition(base_id).get("upgrade_id") == base_id + "_plus",
			base_id + " still links to its authored upgrade")
		_check(_roll_definition(base_id + "_plus").get("upgrade_of") == base_id,
			base_id + "_plus still points back at its base")
	# Other Golem cards, other heroes, aliases and malformed values are not Roll cards.
	for rejected in ["button_golem_starter_button_fist", "button_golem_starter_loose_pop",
			"button_golem_pop_button", "button_golem_eyelet_guard", "button_golem_sew_on",
			"button_golem_button_roll_plus_plus", "button_golem_starter_threadwheel_roll_plus_plus",
			"button_golem_threadwheel_roll", "warden_strike", ""]:
		_check(not resolver.is_supported_card(rejected), str(rejected) + " is not a Roll printing")
	for malformed in [null, 0, 3.5, false, [], {}, StringName("button_golem_button_roll")]:
		_check(not resolver.is_supported_card(malformed),
			"malformed card id is not a Roll printing: " + str(malformed))


## AC1: every printing from every Golem seat onto every other seat, including the 1<->3 Roll.
## Real seeded deck and real party; every actor record is compared, not just the receipt.
func _test_roll_paid_resolution() -> void:
	var cases := 0
	for card_id: String in ROLL_PRINTINGS:
		for golem_seat in [1, 2, 3]:
			for ally_seat in [1, 2, 3]:
				if ally_seat == golem_seat:
					continue
				_play_roll_success(card_id, golem_seat, ally_seat)
				cases += 1
	_check(cases == 24,
		"every Roll printing is exercised from every seat onto every other seat")


func _play_roll_success(card_id: String, golem_seat: int, ally_seat: int) -> void:
	var label := "%s from seat %d onto seat %d" % [card_id, golem_seat, ally_seat]
	var deck := _roll_deck([card_id])
	_check(deck.hand.has(card_id) and deck.hand.count(card_id) == 1,
		label + ": the exact Roll ID is genuinely held once")
	var party := _roll_party(golem_seat)
	_check(party.gain_block(golem_seat, 4), label + ": the Golem starts with four Block")
	_check(party.gain_block(ally_seat, 6), label + ": the selected ally starts with six Block")
	party._heroes[golem_seat - 1]["buttons_popped"] = 2
	party._heroes[golem_seat - 1]["statuses"] = {"weak": 1}
	party._heroes[ally_seat - 1]["statuses"] = {"exposed": 2}
	deck.discard_pile.append("warden_strike")
	var before := _roll_snapshot(deck, party)
	var ally_id: String = str(before["heroes"][ally_seat - 1]["id"])
	var ally_hp: int = int(before["heroes"][ally_seat - 1]["hp"])
	var expected_gain: int = _roll_printed_block(card_id)
	var receipt: Dictionary = RollResolverScript.new().play_card(
		deck, party, card_id, ally_seat)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid Roll resolves")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == 1,
		label + ": the receipt reports the printed card and cost")
	_check(receipt.get("from_position") == golem_seat
		and receipt.get("target_position") == ally_seat,
		label + ": the receipt reports both real seats")
	_check(receipt.get("block_gained") == expected_gain,
		label + ": it gains exactly " + str(expected_gain) + " Block")
	_check(receipt.get("block_after") == 4 + expected_gain,
		label + ": the receipt reports the resulting Block")
	_check(deck.energy == before["energy"] - 1
		and deck.combat_state.energy == before["state_energy"] - 1,
		label + ": exactly one energy left the deck state")
	_check(deck.hand.is_empty() and deck.discard_pile == before["discard"] + [card_id]
		and deck.draw_pile == before["draw"] and deck.turn_active,
		label + ": exactly one held copy moved to discard with no other deck change")
	var moved_golem: Dictionary = party.get_hero(ally_seat)
	_check(moved_golem.get("id") == "button_golem"
		and moved_golem.get("position") == ally_seat,
		label + ": the Golem really sits in the ally's former seat")
	_check(moved_golem.get("block") == 4 + expected_gain,
		label + ": the Golem's own four Block are retained and the printed Block added")
	_check(moved_golem.get("hp") == 44 and moved_golem.get("buttons_popped") == 2
		and moved_golem.get("statuses") == {"weak": 1},
		label + ": HP, popped buttons and statuses follow the Golem")
	var moved_ally: Dictionary = party.get_hero(golem_seat)
	_check(moved_ally.get("id") == ally_id and moved_ally.get("position") == golem_seat,
		label + ": the selected ally really sits in the Golem's former seat")
	_check(moved_ally.get("block") == 6 and moved_ally.get("hp") == ally_hp
		and moved_ally.get("statuses") == {"exposed": 2},
		label + ": the ally keeps its own Block, HP and statuses and gains nothing")
	var expected_heroes: Array = before["heroes"].duplicate(true)
	var expected_golem: Dictionary = expected_heroes[golem_seat - 1].duplicate(true)
	var expected_ally: Dictionary = expected_heroes[ally_seat - 1].duplicate(true)
	expected_golem["position"] = ally_seat
	expected_golem["block"] = 4 + expected_gain
	expected_ally["position"] = golem_seat
	expected_heroes[golem_seat - 1] = expected_ally
	expected_heroes[ally_seat - 1] = expected_golem
	_check(party.get_heroes() == expected_heroes,
		label + ": only the two seats moved and only the Golem gained Block")
	receipt["ok"] = false
	receipt["block_gained"] = -1
	receipt["block_after"] = -1
	_check(party.get_hero(ally_seat).get("block") == 4 + expected_gain
		and deck.discard_pile == before["discard"] + [card_id],
		label + ": mutating the receipt leaves the real state untouched")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": the paid Roll consumes no seeded RNG draw")


## AC2: a second Roll binds the Golem at its UPDATED seat, awards the Block to that Golem and
## leaves the unrelated third hero, the popped-button count and the RNG state untouched.
func _test_roll_second_roll_from_new_seat() -> void:
	var first_id := "button_golem_starter_threadwheel_roll"
	var second_id := "button_golem_button_roll_plus"
	var deck := _roll_deck([first_id, second_id], 424242)
	_check(deck.hand.has(first_id) and deck.hand.has(second_id),
		"both authentic Roll copies are genuinely held")
	var party := _roll_party(1)
	_check(party.gain_block(1, 3), "the first Roll starts from three Block")
	party._heroes[0]["buttons_popped"] = 2
	party._heroes[0]["statuses"] = {"weak": 1}
	var rng_before: int = deck._rng.state
	var first: Dictionary = RollResolverScript.new().play_card(deck, party, first_id, 3)
	_check(first.get("ok") == true and first.get("from_position") == 1
		and first.get("target_position") == 3 and first.get("block_gained") == 5,
		"the first Roll moves the Golem from seat 1 onto seat 3 for five Block")
	_check(party.get_hero(3).get("id") == "button_golem"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("block") == 8,
		"the Golem is authentically seated in seat 3 with eight Block")
	_check(party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(1).get("position") == 1,
		"the seamstress really moved to seat 1")
	_check(deck.energy == 2 and deck.discard_pile == [first_id],
		"the first Roll spends one energy and discards one copy")
	var unrelated_before: Dictionary = party.get_hero(1)
	var second: Dictionary = RollResolverScript.new().play_card(deck, party, second_id, 2)
	_check(second.get("ok") == true and second.get("from_position") == 3
		and second.get("target_position") == 2 and second.get("block_gained") == 8,
		"the second Roll finds the live Golem at its updated seat 3 and gains eight Block")
	_check(second.get("block_after") == 16, "the second Roll stacks onto the retained eight Block")
	_check(party.get_hero(2).get("id") == "button_golem"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("block") == 16,
		"the Golem now sits in seat 2 with sixteen Block")
	_check(party.get_hero(3).get("id") == "warden"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("block") == 0,
		"the selected warden moved to seat 3 and gained no Block")
	_check(party.get_hero(1) == unrelated_before,
		"the unrelated third hero keeps its seat, HP and statuses")
	_check(party.get_hero(2).get("buttons_popped") == 2
		and party.get_hero(2).get("statuses") == {"weak": 1},
		"the Golem's popped-button count and statuses follow it across both Rolls")
	_check(deck.energy == 1 and deck.hand.is_empty()
		and deck.discard_pile == [first_id, second_id],
		"each Roll spends one energy and discards exactly one copy")
	_check(deck._rng.state == rng_before, "two Rolls consume no seeded RNG draw")


## AC3: every unsupported, unpayable or unlawful Roll refuses with a complete before/after
## snapshot of the deck, the actor records and the seeded RNG.
func _test_roll_refusals() -> void:
	_expect_roll_refusal("unknown Roll id", _roll_deck(["button_golem_unknown_roll"]),
		_roll_party(1), "button_golem_unknown_roll", 2, "unsupported_card")
	_expect_roll_refusal("other Button Golem card held",
		_roll_deck(["button_golem_starter_button_fist"]), _roll_party(1),
		"button_golem_starter_button_fist", 2, "unsupported_card")
	for malformed_id in [null, 0, 3.5, false, [], {}, StringName("button_golem_button_roll")]:
		_expect_roll_refusal("malformed card id " + str(malformed_id),
			_roll_deck(["button_golem_button_roll"]), _roll_party(1), malformed_id, 2,
			"unsupported_card")
	_expect_roll_refusal("supported Roll not in hand", _roll_deck(["button_golem_button_roll"]),
		_roll_party(1), "button_golem_button_roll_plus", 2, "card_not_held")
	_expect_roll_refusal("non-Roll card in hand", _roll_deck(["button_golem_eyelet_guard"]),
		_roll_party(1), "button_golem_button_roll", 2, "card_not_held")
	var inactive := _roll_inactive_deck("button_golem_button_roll")
	_check(not inactive.turn_active and inactive.energy == 0 and inactive.hand.is_empty(),
		"inactive-turn fixture really has not started its turn")
	_expect_roll_refusal("inactive turn", inactive, _roll_party(1),
		"button_golem_button_roll", 2, "inactive_turn")
	var broke := _roll_deck(["button_golem_button_roll"])
	_check(broke.try_spend_energy(3) and broke.energy == 0 and broke.hand.size() == 1,
		"energy-short fixture is genuinely broke and still holds the card")
	_expect_roll_refusal("insufficient energy", broke, _roll_party(1),
		"button_golem_button_roll", 2, "insufficient_energy")
	_expect_roll_refusal("target is the Golem itself", _roll_deck(["button_golem_button_roll"]),
		_roll_party(2), "button_golem_button_roll", 2, "invalid_target")
	for bad_target in [0, 4, -1, 99]:
		_expect_roll_refusal("target outside hero seats " + str(bad_target),
			_roll_deck(["button_golem_button_roll"]), _roll_party(1),
			"button_golem_button_roll", bad_target, "invalid_target")
	var torn_target := _roll_party(1)
	_check(torn_target.apply_damage(3, 400) and torn_target.is_downed(3),
		"torn-target fixture has a genuinely downed ally")
	_expect_roll_refusal("Torn selected ally", _roll_deck(["button_golem_button_roll"]),
		torn_target, "button_golem_button_roll", 3, "target_torn")
	var torn_golem := _roll_party(1)
	_check(torn_golem.apply_damage(1, 400) and torn_golem.is_downed(1),
		"torn-Golem fixture has a genuinely downed Golem")
	_expect_roll_refusal("Torn Golem", _roll_deck(["button_golem_button_roll"]),
		torn_golem, "button_golem_button_roll", 2, "owner_torn")
	_expect_roll_refusal("no Button Golem in the party",
		_roll_deck(["button_golem_button_roll"]),
		_roll_party_of(["warden", "seamstress", "tinker"]), "button_golem_button_roll", 2,
		"owner_missing")
	var duplicate_golem := _roll_party(1)
	duplicate_golem._heroes[1]["id"] = "button_golem"
	_check(duplicate_golem.get_hero(2).get("id") == "button_golem",
		"duplicate-Golem fixture really carries a second Golem record")
	_expect_roll_refusal("two Button Golems", _roll_deck(["button_golem_button_roll"]),
		duplicate_golem, "button_golem_button_roll", 3, "duplicate_owner")
	var duplicate_hero := _roll_party(1)
	duplicate_hero._heroes[2]["id"] = "warden"
	_check(duplicate_hero.get_hero(2).get("id") == duplicate_hero.get_hero(3).get("id"),
		"duplicate-hero fixture really repeats a non-Golem id")
	_expect_roll_refusal("duplicate non-Golem hero id",
		_roll_deck(["button_golem_button_roll"]), duplicate_hero, "button_golem_button_roll", 2,
		"invalid_roster")
	var malformed_position := _roll_party(1)
	malformed_position._heroes[1]["position"] = 3
	_check(malformed_position.get_hero(2).get("position") == 3,
		"malformed-position fixture really stores an out-of-order seat")
	_expect_roll_refusal("malformed actor position", _roll_deck(["button_golem_button_roll"]),
		malformed_position, "button_golem_button_roll", 2, "invalid_roster")
	for bad_status in [{"weak": "1"}, {"tangled": 1.5}, {"bleed": -1}, {"unknown": 1}]:
		var malformed_statuses := _roll_party(1)
		malformed_statuses._heroes[0]["statuses"] = bad_status
		_check(malformed_statuses.get_hero(1).get("statuses") == bad_status,
			"malformed-status fixture really stores " + str(bad_status))
		_expect_roll_refusal("malformed status map " + str(bad_status),
			_roll_deck(["button_golem_button_roll"]), malformed_statuses,
			"button_golem_button_roll", 2, "malformed_statuses")
	var tangled_golem := _roll_party(1)
	tangled_golem._heroes[0]["statuses"] = {"tangled": 1}
	_expect_roll_refusal("positive Tangled on the Golem",
		_roll_deck(["button_golem_button_roll"]), tangled_golem, "button_golem_button_roll", 2,
		"tangled")
	var tangled_ally := _roll_party(1)
	tangled_ally._heroes[2]["statuses"] = {"tangled": 3}
	_expect_roll_refusal("positive Tangled on the selected ally",
		_roll_deck(["button_golem_button_roll"]), tangled_ally, "button_golem_button_roll", 3,
		"tangled")
	var full := _roll_party(1)
	_check(full.gain_block(1, CombatParty.MAX_INT - 4),
		"near-cap fixture holds MAX_INT - 4 Block")
	_expect_roll_refusal("resulting Block above MAX_INT",
		_roll_deck(["button_golem_button_roll"]), full, "button_golem_button_roll", 2,
		"block_overflow")
	_expect_roll_refusal("invalid party", _roll_deck(["button_golem_button_roll"]),
		CombatParty.new([]), "button_golem_button_roll", 2, "invalid_roster")
	_expect_roll_refusal("missing deck", null, _roll_party(1), "button_golem_button_roll", 2,
		"invalid_request")

	# Zero Tangled is expired, not a blocker.
	var zero_tangled := _roll_party(1)
	zero_tangled._heroes[0]["statuses"] = {"tangled": 0}
	zero_tangled._heroes[2]["statuses"] = {"tangled": 0}
	var zero_deck := _roll_deck(["button_golem_button_roll"])
	var zero_receipt: Dictionary = RollResolverScript.new().play_card(
		zero_deck, zero_tangled, "button_golem_button_roll", 3)
	_check(zero_receipt.get("ok") == true and zero_receipt.get("block_gained") == 5,
		"a zero Tangled counter on both participants is expired and the Roll is legal")
	_check(zero_tangled.get_hero(3).get("id") == "button_golem"
		and zero_tangled.get_hero(3).get("block") == 5,
		"the zero-Tangled Roll really swapped and granted Block")
	_check(zero_deck.energy == 2 and zero_deck.discard_pile == ["button_golem_button_roll"],
		"the zero-Tangled Roll still pays and discards")

	# A gain ending exactly at MAX_INT is legal; the same gain one point higher is not.
	var exact := _roll_party(2)
	_check(exact.gain_block(2, CombatParty.MAX_INT - 5),
		"exact-cap fixture holds MAX_INT - 5 Block")
	var exact_deck := _roll_deck(["button_golem_button_roll"])
	var exact_receipt: Dictionary = RollResolverScript.new().play_card(
		exact_deck, exact, "button_golem_button_roll", 1)
	_check(exact_receipt.get("ok") == true
		and exact_receipt.get("block_after") == CombatParty.MAX_INT,
		"a gain ending exactly at MAX_INT succeeds")
	_check(exact.get_hero(1).get("id") == "button_golem"
		and exact.get_hero(1).get("block") == CombatParty.MAX_INT,
		"exactly MAX_INT Block is committed to the Golem's new seat")
	_check(exact_deck.energy == 2
		and exact_deck.discard_pile == ["button_golem_button_roll"],
		"the exact-MAX_INT Roll still pays and discards")


func _expect_roll_refusal(label: String, deck: CombatDeck, party: CombatParty,
		card_id: Variant, target_position: int, reason: String) -> void:
	var before := _roll_snapshot(deck, party)
	var receipt: Dictionary = RollResolverScript.new().play_card(
		deck, party, card_id, target_position)
	_check(receipt.get("ok") == false, label + ": refused")
	_check(receipt.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(receipt.get("reason")) + ")")
	for key: String in ["ok", "reason", "card_id", "cost", "from_position",
			"target_position", "block_gained", "block_after"]:
		_check(receipt.has(key), label + ": refusal receipt carries " + key)
	_check(receipt.get("block_gained") == 0 and receipt.get("block_after") == 0,
		label + ": refusal reports no Block")
	_check(_roll_snapshot(deck, party) == before,
		label + ": hand, piles, energy, actor records and seeded RNG are unchanged")


## Detached before/after state for refusals: piles, turn, energy, seeded RNG and actor records.
func _roll_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
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
	return snapshot


func _roll_definition(card_id: String) -> Dictionary:
	var spec: Dictionary = ROLL_PRINTINGS.get(card_id, {})
	if spec.is_empty():
		return {}
	if spec["catalog"] == "starter":
		return ButtonGolemStarterScript.new().get_definition(card_id)
	return ScriptClass.new().get_definition(card_id)


## The complete printed effect set for one Roll printing, keyed as its own catalog authored it.
func _roll_expected_effects(card_id: String) -> Dictionary:
	var block: int = int(ROLL_PRINTINGS[card_id]["block"])
	if ROLL_PRINTINGS[card_id]["catalog"] == "starter":
		return {"swap_with_ally": 1, "block_self": block}
	return {"swap_with_target_ally": true, "block": block}


## The Block magnitude read back from the authored catalog record, not from a test constant.
func _roll_printed_block(card_id: String) -> int:
	var effects: Dictionary = _roll_definition(card_id).get("effects", {})
	if effects.has("block_self"):
		return int(effects["block_self"])
	return int(effects.get("block", 0))


## A real three-hero party with the Button Golem genuinely sitting in the requested seat.
func _roll_party(golem_seat: int) -> CombatParty:
	var order: Array = ["warden", "seamstress"]
	order.insert(golem_seat - 1, "button_golem")
	var party := _roll_party_of(order)
	_check(party.get_hero(golem_seat).get("id") == "button_golem"
		and party.get_hero(golem_seat).get("position") == golem_seat,
		"fixture has the Golem living in seat " + str(golem_seat))
	return party


func _roll_party_of(order: Array) -> CombatParty:
	var hp := {"button_golem": 44, "warden": 40, "seamstress": 30, "tinker": 26}
	var definitions: Array = []
	for hero_id: String in order:
		definitions.append({"id": hero_id, "max_hp": hp[hero_id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"fixture has three distinct living heroes")
	return party


func _roll_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real seeded CombatDeck that starts the shared three-energy turn with the named cards held.
func _roll_deck(ids: Array, seed_value: int = 2981793) -> CombatDeck:
	var cards: Array[String] = []
	for id: Variant in ids:
		cards.append(str(id))
	var deck := CombatDeck.new(cards, _roll_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == mini(cards.size(), CombatDeck.TURN_DRAW),
		"seeded real CombatDeck starts a three-energy turn")
	return deck


func _roll_inactive_deck(card_id: String) -> CombatDeck:
	var cards: Array[String] = [card_id]
	return CombatDeck.new(cards, _roll_rng(2981793))


# ---------------------------------------------------------------------------------------------
# Popping Volley / Buttonstorm: paid enemy_all area attacks over the real shared combat state.
# ---------------------------------------------------------------------------------------------

## AC1/AC2: the four authentic area printings, each read back from its OWN pool record with the
## authored seats, target kind, printed effects and base/plus link (never a catalog total).
func _test_area_printings() -> void:
	var catalog = ScriptClass.new()
	var resolver = AreaResolverScript.new()
	_check(AREA_PRINTINGS.size() == 4, "four distinct area printings are enumerated")
	for card_id: String in AREA_PRINTINGS:
		var spec: Dictionary = AREA_PRINTINGS[card_id]
		var definition: Dictionary = catalog.get_definition(card_id)
		var upgraded: bool = card_id.ends_with("_plus")
		var base_id: String = card_id.trim_suffix("_plus")
		_check(not definition.is_empty() and definition.get("id") == card_id,
			card_id + " is authentically authored in the Button Golem pool")
		_check(resolver.is_supported_card(card_id),
			card_id + " is a resolver-supported area printing")
		_check(definition.get("owner") == "button_golem", card_id + " is owned by the Golem")
		_check(definition.get("cost") == 2, card_id + " costs exactly two energy")
		_check(definition.get("target_kind") == "enemy_all", card_id + " targets every enemy")
		_check(definition.get("from_positions") == spec["from"],
			card_id + " plays from its authored seats " + str(spec["from"]))
		_check(definition.get("to_positions") == [1, 2, 3],
			card_id + " reaches enemy slots 1-3")
		_check(definition.get("effects") == _area_expected_effects(card_id),
			card_id + " prints exactly " + str(_area_expected_effects(card_id)))
		_check(definition.get("starting_copies") == 0, card_id + " is never a starter copy")
		_check(definition.get("reward_eligible") == not upgraded,
			card_id + " reward eligibility matches its base/upgrade role")
		_check(catalog.get_upgrade_id(base_id) == base_id + "_plus",
			base_id + " still links to its authored upgrade")
		_check(catalog.get_definition(base_id + "_plus").get("upgrade_of") == base_id,
			base_id + "_plus still points back at its base")
	# Every other pool or starter card, an alias and a malformed value is not an area printing.
	for rejected in ["button_golem_pop_button", "button_golem_pop_button_plus",
			"button_golem_button_roll", "button_golem_button_knuckle", "button_golem_eyelet_guard",
			"button_golem_sew_on", "button_golem_buttonhole_snag",
			"button_golem_starter_button_fist", "button_golem_starter_loose_pop",
			"button_golem_popping_volley_plus_plus", "button_golem_popping_volley+", ""]:
		_check(not resolver.is_supported_card(rejected), str(rejected) + " is not an area printing")
	for malformed in [null, 0, 3.5, false, [], {}, StringName("button_golem_popping_volley")]:
		_check(not resolver.is_supported_card(malformed),
			"malformed card id is not an area printing: " + str(malformed))


func _area_expected_effects(card_id: String) -> Dictionary:
	var spec: Dictionary = AREA_PRINTINGS[card_id]
	var magnitude: int = int(spec["magnitude"])
	if spec["shape"] == "volley":
		return {"damage": magnitude, "hit_count": 2, "independent_hits": true,
			"living_targets_only": true}
	return {"damage_per_button_popped": magnitude, "living_targets_only": true}


## AC1: both printings from both legal Volley seats, with a real seeded deck and a real roster:
## an Exposed first slot, a two-HP second slot that dies to its first Weak-adjusted hit, and a
## Blocked + Tangled third slot. A further pass pre-kills the middle slot instead, proving slain
## slots are skipped and positions never compact.
func _test_area_volley_paid_resolution() -> void:
	for card_id: String in ["button_golem_popping_volley", "button_golem_popping_volley_plus"]:
		var base: int = int(AREA_PRINTINGS[card_id]["magnitude"])
		for seat in [1, 2]:
			_play_volley_success(card_id, seat, base, false)
		_play_volley_success(card_id, 1, base, true)


func _play_volley_success(card_id: String, seat: int, base: int, preslain: bool) -> void:
	var label := "%s from seat %d%s" % [card_id, seat,
		" past a pre-slain slot" if preslain else ""]
	var deck := _area_deck(card_id)
	var party := _roll_party(seat)
	party._heroes[seat - 1]["statuses"] = {"weak": 1}
	party._heroes[seat - 1]["buttons_popped"] = 2
	_check(party.gain_block(seat, 4), label + ": the Golem starts with four Block")
	var enemies := _volley_enemies()
	if preslain:
		_check(enemies.apply_damage(2, 2) and enemies.is_slain(2),
			label + ": the middle slot is genuinely slain before the volley")
	var before := _area_snapshot(deck, party, enemies)
	var receipt: Dictionary = AreaResolverScript.new().play_card(deck, party, enemies, card_id, 0)

	# Independent per-hit expectations from the shared status rules, never from the resolver.
	var rules := CombatStatuses.new()
	var attacker := {"weak": 1}
	var exposed_hit: int = rules.adjusted_attack_damage(base, attacker, {"exposed": 1})
	var tangled_hit: int = rules.adjusted_attack_damage(base, attacker, {"tangled": 1})
	var merged_tangled: int = rules.adjusted_attack_damage(2 * base, attacker, {"tangled": 1})
	var weak_hit: int = rules.adjusted_attack_damage(base, attacker, {})
	_check(weak_hit >= 2, label + ": the Weak-adjusted first hit is still lethal to the two-HP slot")
	_check(tangled_hit * 2 != merged_tangled,
		label + ": two separate Tangled hits differ from one merged " + str(2 * base) + "-damage hit")

	var expected_positions: Array = [1, 3] if preslain else [1, 2, 3]
	var expected_calls: Array = []
	for position: int in expected_positions:
		var hit_total := 2
		if position == 2:
			hit_total = 1
		for hit_index in range(1, hit_total + 1):
			expected_calls.append([position, hit_index])

	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid area attack resolves")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == 2
		and receipt.get("energy_spent") == 2, label + ": it charges exactly two energy")
	_check(receipt.get("owner_position") == seat and receipt.get("target_position") == 0,
		label + ": the receipt binds the real Golem seat and no selected enemy slot")
	_check(receipt.get("buttons_popped") == 2 and receipt.get("base_damage") == base
		and receipt.get("hit_count") == 2,
		label + ": the receipt reports the read counter and printed per-hit base")
	_check(receipt.get("targets") == expected_positions,
		label + ": every living slot is targeted and the dead slot is skipped")

	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == expected_calls.size(),
		label + ": " + str(expected_calls.size()) + " hits are reported")
	for index in range(mini(hits.size(), expected_calls.size())):
		var hit: Dictionary = hits[index]
		var position: int = expected_calls[index][0]
		var hit_index: int = expected_calls[index][1]
		var expected_damage: int = weak_hit
		if position == 1:
			expected_damage = exposed_hit
		elif position == 3:
			expected_damage = tangled_hit
		var expected_absorbed := 0
		if position == 3 and hit_index == 1:
			expected_absorbed = 2
		var expected_hp_loss: int = expected_damage - expected_absorbed
		if position == 2:
			expected_hp_loss = mini(2, expected_hp_loss)
		_check(hit.get("position") == position and hit.get("hit") == hit_index,
			label + ": hit " + str(index + 1) + " is slot " + str(position)
			+ " hit " + str(hit_index))
		_check(hit.get("base_damage") == base, label + ": hit " + str(index + 1)
			+ " is printed base " + str(base))
		_check(hit.get("damage") == expected_damage, label + ": hit " + str(index + 1)
			+ " is status-adjusted on its own to " + str(expected_damage))
		_check(hit.get("block_absorbed") == expected_absorbed,
			label + ": hit " + str(index + 1) + " absorbs " + str(expected_absorbed) + " Block")
		_check(hit.get("hp_loss") == expected_hp_loss,
			label + ": hit " + str(index + 1) + " loses " + str(expected_hp_loss) + " HP")

	if not preslain:
		var second_hits := 0
		for hit: Dictionary in hits:
			if hit.get("position") == 2:
				second_hits += 1
		_check(second_hits == 1,
			label + ": a foe slain by the first hit never receives its second hit")

	# The deck charged exactly two energy and discarded exactly one genuinely held copy.
	var expected_hand: Array = before["hand"].duplicate()
	expected_hand.erase(card_id)
	_check(deck.energy == before["energy"] - 2 and deck.energy == 1,
		label + ": exactly two energy left the shared turn")
	_check(deck.hand == expected_hand and deck.discard_pile == before["discard"] + [card_id],
		label + ": exactly one held copy moved to the discard pile")
	_check(deck.draw_pile == before["draw"] and deck.draw_pile.size() == 2,
		label + ": the draw pile is untouched and nothing was drawn or shuffled")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": resolution consumes no seeded RNG draw")
	_check(party.get_heroes() == before["heroes"],
		label + ": no hero HP, Block, status or popped-button record changed")

	var slot_one: Dictionary = enemies.get_enemy(1)
	_check(slot_one.get("hp") == 20 - 2 * exposed_hit and slot_one.get("block") == 0
		and slot_one.get("position") == 1 and slot_one.get("statuses") == {"exposed": 1},
		label + ": the Exposed slot took two separate adjusted hits and kept its slot")
	var slot_three: Dictionary = enemies.get_enemy(3)
	_check(slot_three.get("hp") == 20 - 2 * tangled_hit + 2 and slot_three.get("block") == 0
		and slot_three.get("position") == 3 and slot_three.get("statuses") == {"tangled": 1},
		label + ": the Blocked Tangled slot absorbs Block per hit and keeps its slot")
	if preslain:
		_check(enemies.get_enemy(2) == before["enemies"][1],
			label + ": the already-dead slot keeps its exact record")
		for hit: Dictionary in hits:
			_check(hit.get("position") != 2, label + ": the dead slot is never targeted")
	else:
		_check(enemies.is_slain(2) and enemies.get_enemy(2).get("position") == 2,
			label + ": the slain foe keeps its position and the roster never compacts")
	if not hits.is_empty():
		receipt["hits"][0]["damage"] = -99
		_check(enemies.get_enemy(1).get("hp") == 20 - 2 * exposed_hit,
			label + ": mutating the receipt leaves the real roster untouched")


## AC2: both Buttonstorm printings for popped-button counters 0, 1 and 3 from the only legal seat.
## The middle slot is already slain; damage is the printed per-pop value times the earlier count,
## then ordinary status adjustment and Block-before-HP, with the counter read and never spent.
func _test_area_storm_paid_resolution() -> void:
	for card_id: String in ["button_golem_buttonstorm", "button_golem_buttonstorm_plus"]:
		var per_pop: int = int(AREA_PRINTINGS[card_id]["magnitude"])
		for counter in [0, 1, 3]:
			_play_storm_success(card_id, per_pop, counter)


func _play_storm_success(card_id: String, per_pop: int, counter: int,
		seed_value: int = 907311) -> Dictionary:
	var label := "%s with %d popped buttons" % [card_id, counter]
	var deck := _area_deck(card_id, seed_value)
	var party := _roll_party(1)
	party._heroes[0]["buttons_popped"] = counter
	_check(party.get_hero(1).get("buttons_popped") == counter,
		label + ": the Golem really carries the prior popped-button count")
	_check(party.gain_block(1, 4), label + ": the Golem starts with four Block")
	var enemies := _storm_enemies()
	var before := _area_snapshot(deck, party, enemies)
	var receipt: Dictionary = AreaResolverScript.new().play_card(deck, party, enemies, card_id, 0)

	var base: int = per_pop * counter
	var rules := CombatStatuses.new()
	var exposed_damage: int = rules.adjusted_attack_damage(base, {}, {"exposed": 1})
	var tangled_damage: int = rules.adjusted_attack_damage(base, {}, {"tangled": 1})
	var absorbed: int = mini(2, exposed_damage)
	if base == 0:
		_check(exposed_damage == 0 and tangled_damage == 0,
			label + ": zero raw damage stays zero under both statuses, never an invented bonus")

	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid Buttonstorm resolves")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == 2
		and receipt.get("energy_spent") == 2, label + ": it charges exactly two energy")
	_check(receipt.get("owner_position") == 1 and receipt.get("target_position") == 0,
		label + ": the receipt binds the Golem in seat 1 and no selected enemy slot")
	_check(receipt.get("buttons_popped") == counter and receipt.get("base_damage") == base
		and receipt.get("hit_count") == 1,
		label + ": one hit of the printed " + str(per_pop) + " per prior pop")
	_check(receipt.get("targets") == [1, 3],
		label + ": only the living enemy slots are targeted")

	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == 2, label + ": the two living enemies take exactly one hit each")
	if hits.size() == 2:
		var first: Dictionary = hits[0]
		_check(first.get("position") == 1 and first.get("hit") == 1
			and first.get("base_damage") == base and first.get("damage") == exposed_damage
			and first.get("block_absorbed") == absorbed
			and first.get("hp_loss") == exposed_damage - absorbed,
			label + ": the Exposed slot takes one adjusted Block-before-HP hit")
		var third: Dictionary = hits[1]
		_check(third.get("position") == 3 and third.get("hit") == 1
			and third.get("base_damage") == base and third.get("damage") == tangled_damage
			and third.get("block_absorbed") == 0 and third.get("hp_loss") == tangled_damage,
			label + ": the Tangled slot takes one adjusted hit")
	_check(enemies.get_enemy(1).get("hp") == 40 - exposed_damage + absorbed
		and enemies.get_enemy(1).get("block") == 2 - absorbed,
		label + ": the first slot's Block absorbs before its HP loss")
	_check(enemies.get_enemy(3).get("hp") == 40 - tangled_damage
		and enemies.get_enemy(3).get("block") == 0,
		label + ": the third slot loses exactly its adjusted damage in HP")
	_check(enemies.is_slain(2) and enemies.get_enemy(2) == before["enemies"][1],
		label + ": the already-dead middle slot is never hit and keeps its record")
	if counter == 0:
		_check(hits.size() == 2 and hits[0].get("damage") == 0 and hits[1].get("damage") == 0,
			label + ": a zero counter is a valid paid zero-damage hit, not a refusal")
		_check(enemies.get_enemy(1).get("block") == 2 and enemies.get_enemy(1).get("hp") == 40,
			label + ": zero damage touches neither Block nor HP")

	_check(party.get_heroes() == before["heroes"],
		label + ": the counter, hero Block, HP and statuses are unchanged")
	_check(party.get_hero(1).get("buttons_popped") == counter,
		label + ": the popped-button count is read, never consumed or incremented")
	var expected_hand: Array = before["hand"].duplicate()
	expected_hand.erase(card_id)
	_check(deck.energy == before["energy"] - 2 and deck.energy == 1,
		label + ": exactly two energy left the shared turn")
	_check(deck.hand == expected_hand and deck.discard_pile == before["discard"] + [card_id],
		label + ": exactly one held copy moved to the discard pile")
	_check(deck.draw_pile == before["draw"] and deck.draw_pile.size() == 2,
		label + ": the draw pile is untouched and nothing was drawn, shuffled or refilled")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": resolution consumes no seeded RNG draw")
	return {"receipt": receipt, "snapshot": _area_snapshot(deck, party, enemies)}


## AC2: identical seeds and identical requests replay identically, receipts included.
func _test_area_storm_replay() -> void:
	var first: Array = []
	var second: Array = []
	for card_id: String in ["button_golem_buttonstorm", "button_golem_buttonstorm_plus"]:
		var per_pop: int = int(AREA_PRINTINGS[card_id]["magnitude"])
		for counter in [0, 1, 3]:
			first.append(_play_storm_success(card_id, per_pop, counter, 881231))
			second.append(_play_storm_success(card_id, per_pop, counter, 881231))
	_check(first.size() == 6 and second.size() == 6,
		"same-seed Buttonstorm replay covers both printings and counters 0, 1 and 3")
	_check(first == second,
		"same-seed Buttonstorm replay produces identical receipts and final state")


## AC2: the counter Buttonstorm scales from is the one a genuine Block-paid Pop Button writes,
## and the storm neither consumes it nor touches the Golem's remaining Block.
func _test_area_storm_reads_pop_counter() -> void:
	var pop_id := "button_golem_pop_button"
	var storm_id := "button_golem_buttonstorm"
	var deck := _area_deck_of([pop_id, storm_id], 424242)
	_check(deck.hand.has(pop_id) and deck.hand.has(storm_id),
		"the Pop and the storm are genuinely held together")
	var party := _roll_party(1)
	_check(party.gain_block(1, 5), "the Golem holds the five Block the Pop costs")
	var enemies := _area_targets()
	var before := _area_snapshot(deck, party, enemies)
	var pop: Dictionary = PopResolverScript.new().play_card(deck, party, enemies, pop_id, 1)
	_check(pop.get("ok") == true and party.get_hero(1).get("buttons_popped") == 1,
		"a real paid Pop Button writes one popped button on the Golem")
	_check(party.get_hero(1).get("block") == 0 and deck.energy == 2,
		"the Pop spends its five Block and one energy")
	var storm: Dictionary = AreaResolverScript.new().play_card(deck, party, enemies, storm_id, 0)
	_check(storm.get("ok") == true and storm.get("buttons_popped") == 1
		and storm.get("base_damage") == 4,
		"the storm reads the counter the Pop wrote and prints four damage from it")
	_check(party.get_hero(1).get("buttons_popped") == 1
		and party.get_hero(1).get("block") == 0,
		"the storm consumes neither the counter nor the Golem's Block")
	_check(enemies.get_enemy(1).get("hp") == 20 - 9 - 4
		and enemies.get_enemy(2).get("hp") == 20 - 4,
		"both enemies take the storm's one hit after the Pop's single-target hit")
	_check(deck.energy == before["energy"] - 3 and deck.discard_pile == [pop_id, storm_id]
		and deck.hand.is_empty() and deck.draw_pile == before["draw"],
		"the two plays spend three energy and discard their own held copies only")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		"the Pop and the storm consume no seeded RNG draw")


## AC3: every unsupported, forged, unpayable or unlawful area play refuses with a complete
## before/after snapshot of the deck, the actor records, the enemies and the seeded RNG.
func _test_area_refusals() -> void:
	var volley := "button_golem_popping_volley"
	var storm := "button_golem_buttonstorm"
	for rejected in ["button_golem_unknown_area", "button_golem_pop_button",
			"button_golem_button_roll", "button_golem_sew_on", "button_golem_starter_button_fist",
			"button_golem_popping_volley_plus_plus", "button_golem_popping_volley+", ""]:
		_expect_area_refusal("unsupported area id " + str(rejected), _area_deck_of([volley]),
			_roll_party(1), _area_targets(), rejected, 0, "unsupported_card")
	for malformed in [null, 0, 3.5, false, [], {}, StringName(volley)]:
		_expect_area_refusal("malformed area id " + str(malformed), _area_deck_of([volley]),
			_roll_party(1), _area_targets(), malformed, 0, "unsupported_card")
	_expect_area_refusal("supported area printing not in hand", _area_deck_of([volley]),
		_roll_party(1), _area_targets(), "button_golem_popping_volley_plus", 0, "card_not_held")
	_expect_area_refusal("a different Golem card held in its place",
		_area_deck_of(["button_golem_pop_button"]), _roll_party(1), _area_targets(), volley, 0,
		"card_not_held")
	var inactive := _area_inactive_deck(volley)
	_check(not inactive.turn_active and inactive.energy == 0 and inactive.hand.is_empty(),
		"inactive-turn fixture really has not started its turn")
	_expect_area_refusal("inactive turn", inactive, _roll_party(1), _area_targets(), volley, 0,
		"inactive_turn")
	var broke := _area_deck(volley)
	_check(broke.try_spend_energy(2) and broke.energy == 1 and broke.hand.has(volley),
		"energy-short fixture is genuinely broke and still holds the card")
	_expect_area_refusal("insufficient energy", broke, _roll_party(1), _area_targets(), volley, 0,
		"insufficient_energy")
	for bad_target in [1, 3, -1, 99]:
		_expect_area_refusal("enemy_all with a selected slot " + str(bad_target),
			_area_deck(volley), _roll_party(1), _area_targets(), volley, bad_target,
			"invalid_target")
	_expect_area_refusal("no Button Golem in the party", _area_deck(volley),
		_roll_party_of(["warden", "seamstress", "tinker"]), _area_targets(), volley, 0,
		"owner_missing")
	var duplicate_golem := _roll_party(1)
	duplicate_golem._heroes[1]["id"] = "button_golem"
	_check(duplicate_golem.get_hero(2).get("id") == "button_golem",
		"duplicate-Golem fixture really carries a second Golem record")
	_expect_area_refusal("two Button Golems", _area_deck(volley), duplicate_golem,
		_area_targets(), volley, 0, "duplicate_owner")
	var torn_golem := _roll_party(1)
	_check(torn_golem.apply_damage(1, 400) and torn_golem.is_downed(1),
		"torn-Golem fixture has a genuinely downed Golem")
	_expect_area_refusal("Torn Golem", _area_deck(volley), torn_golem, _area_targets(), volley,
		0, "owner_torn")
	_expect_area_refusal("Popping Volley from illegal seat 3", _area_deck(volley),
		_roll_party(3), _area_targets(), volley, 0, "invalid_owner_position")
	_expect_area_refusal("Buttonstorm from illegal seat 2", _area_deck(storm), _roll_party(2),
		_area_targets(), storm, 0, "invalid_owner_position")
	var all_slain := _area_targets()
	_check(all_slain.apply_damage(1, 20) and all_slain.apply_damage(2, 20)
		and all_slain.is_defeated(), "all-dead fixture really has no living enemy")
	_expect_area_refusal("every enemy already slain", _area_deck(volley), _roll_party(1),
		all_slain, volley, 0, "no_living_targets")
	_expect_area_refusal("invalid party", _area_deck(volley), CombatParty.new([]),
		_area_targets(), volley, 0, "invalid_roster")
	_expect_area_refusal("invalid enemy roster", _area_deck(volley), _roll_party(1),
		CombatEnemies.new([]), volley, 0, "invalid_roster")
	var bad_position := _roll_party(1)
	bad_position._heroes[1]["position"] = 3
	_check(bad_position.get_hero(2).get("position") == 3,
		"malformed-position fixture really stores an out-of-order seat")
	_expect_area_refusal("malformed actor position", _area_deck(volley), bad_position,
		_area_targets(), volley, 0, "invalid_roster")
	var duplicate_hero := _roll_party(1)
	duplicate_hero._heroes[2]["id"] = "warden"
	_check(duplicate_hero.get_hero(2).get("id") == duplicate_hero.get_hero(3).get("id"),
		"duplicate-hero fixture really repeats a non-Golem id")
	_expect_area_refusal("duplicate non-Golem hero id", _area_deck(volley), duplicate_hero,
		_area_targets(), volley, 0, "invalid_roster")
	var bad_hp := _roll_party(1)
	bad_hp._heroes[0]["hp"] = 999
	_expect_area_refusal("hero HP above its maximum", _area_deck(volley), bad_hp,
		_area_targets(), volley, 0, "invalid_roster")
	var bad_block := _roll_party(1)
	bad_block._heroes[0]["block"] = -1
	_expect_area_refusal("negative hero Block", _area_deck(volley), bad_block, _area_targets(),
		volley, 0, "invalid_roster")
	var bad_enemy_hp := _area_targets()
	bad_enemy_hp._enemies[0]["hp"] = 99
	_expect_area_refusal("enemy HP above its maximum", _area_deck(volley), _roll_party(1),
		bad_enemy_hp, volley, 0, "invalid_roster")
	var bad_enemy_block := _area_targets()
	bad_enemy_block._enemies[0]["block"] = -1
	_expect_area_refusal("negative enemy Block", _area_deck(volley), _roll_party(1),
		bad_enemy_block, volley, 0, "invalid_roster")
	for bad_status in [{"weak": "1"}, {"tangled": 1.5}, {"bleed": -1}, {"unknown": 1},
			{"riposte": null}]:
		var hero_statuses := _roll_party(1)
		hero_statuses._heroes[0]["statuses"] = bad_status
		_check(hero_statuses.get_hero(1).get("statuses") == bad_status,
			"malformed hero status fixture really stores " + str(bad_status))
		_expect_area_refusal("malformed hero status map " + str(bad_status), _area_deck(volley),
			hero_statuses, _area_targets(), volley, 0, "malformed_statuses")
	for bad_enemy_status in [{"weak": "1"}, {"exposed": -2}, {"unknown": 1}]:
		var enemy_statuses := _area_targets()
		enemy_statuses._enemies[0]["statuses"] = bad_enemy_status
		_check(enemy_statuses.get_enemy(1).get("statuses") == bad_enemy_status,
			"malformed enemy status fixture really stores " + str(bad_enemy_status))
		_expect_area_refusal("malformed enemy status map " + str(bad_enemy_status),
			_area_deck(volley), _roll_party(1), enemy_statuses, volley, 0,
			"malformed_statuses")
	for bad_counter in ["3", -1, 2.5, null, true]:
		var bad_count := _roll_party(1)
		bad_count._heroes[0]["buttons_popped"] = bad_counter
		_check(bad_count.get_hero(1).get("buttons_popped") == bad_counter,
			"malformed counter fixture really stores " + str(bad_counter))
		for card_id: String in [volley, storm]:
			_expect_area_refusal("malformed popped-button count " + str(bad_counter)
				+ " for " + card_id, _area_deck(card_id), bad_count, _area_targets(), card_id, 0,
				"malformed_button_count")
	var product_overflow := _roll_party(1)
	product_overflow._heroes[0]["buttons_popped"] = CombatParty.MAX_INT
	_expect_area_refusal("per-pop product above MAX_INT", _area_deck(storm), product_overflow,
		_area_targets(), storm, 0, "arithmetic_overflow")
	var adjusted_overflow := _roll_party(1)
	adjusted_overflow._heroes[0]["buttons_popped"] = CombatParty.MAX_INT / 4
	var exposed_targets := _area_targets()
	_check(exposed_targets.apply_statuses({1: {"exposed": 1}}),
		"overflow fixture marks the first enemy Exposed")
	_expect_area_refusal("status-adjusted damage above MAX_INT", _area_deck(storm),
		adjusted_overflow, exposed_targets, storm, 0, "arithmetic_overflow")
	_expect_area_refusal("missing deck", null, _roll_party(1), _area_targets(), volley, 0,
		"invalid_request")
	_expect_area_refusal("missing party", _area_deck(volley), null, _area_targets(), volley, 0,
		"invalid_request")
	_expect_area_refusal("missing enemies", _area_deck(volley), _roll_party(1), null, volley, 0,
		"invalid_request")
	var broken_deck := _area_deck(volley)
	broken_deck.combat_state = null
	_check(broken_deck.combat_state == null and broken_deck.hand.has(volley),
		"broken-deck fixture really has no combat state and still holds the card")
	_expect_area_refusal("deck without combat state", broken_deck, _roll_party(1),
		_area_targets(), volley, 0, "invalid_deck")


func _expect_area_refusal(label: String, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: Variant, target_position: int, reason: String) -> void:
	var before := _area_snapshot(deck, party, enemies)
	var receipt: Dictionary = AreaResolverScript.new().play_card(deck, party, enemies, card_id,
		target_position)
	_check(receipt.get("ok") == false, label + ": refused")
	_check(receipt.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(receipt.get("reason")) + ")")
	for key: String in ["ok", "reason", "card_id", "cost", "owner_position", "target_position",
			"buttons_popped", "base_damage", "hit_count", "energy_spent", "targets", "hits"]:
		_check(receipt.has(key), label + ": refusal receipt carries " + key)
	_check(receipt.get("energy_spent") == 0 and receipt.get("targets") == []
		and receipt.get("hits") == [], label + ": refusal reports no spend and no hits")
	_check(_area_snapshot(deck, party, enemies) == before,
		label + ": deck, party, enemies and seeded RNG are unchanged")


## AC3: a rewritten, relinked or unauthentic pool record is refused before any state moves.
func _test_area_forged_catalog() -> void:
	var catalog = ScriptClass.new()
	for card_id: String in AREA_PRINTINGS:
		var base_id: String = card_id.trim_suffix("_plus")
		var plus_id: String = base_id + "_plus"
		var authentic_base: Dictionary = catalog.get_definition(base_id)
		var authentic_plus: Dictionary = catalog.get_definition(plus_id)
		_check(not authentic_base.is_empty() and not authentic_plus.is_empty(),
			card_id + ": both authored records load for forgery")
		if authentic_base.is_empty() or authentic_plus.is_empty():
			continue
		var upgraded: bool = card_id.ends_with("_plus")
		var authentic: Dictionary = authentic_plus if upgraded else authentic_base
		var link_key := "upgrade_of" if upgraded else "upgrade_id"
		var fields: Array[String] = ["id", "owner", "cost", "from_positions", "to_positions",
			"target_kind", "effects", "starting_copies", "reward_eligible", link_key]
		var replacements: Dictionary = {
			"id": "button_golem_forged_area", "owner": "warden", "cost": 1,
			"from_positions": [1, 2, 3], "to_positions": [1], "target_kind": "enemy_single",
			"effects": {"damage": 99, "hit_count": 3},
			"starting_copies": 1,
			"reward_eligible": not bool(authentic.get("reward_eligible", false)),
			"upgrade_id": "button_golem_forged_area",
			"upgrade_of": "button_golem_forged_area",
		}
		for field: String in fields:
			var omitted: Dictionary = authentic.duplicate(true)
			omitted.erase(field)
			_forge_area_refused(card_id + ": record without " + field, card_id,
				_area_forged_records(base_id, authentic_base, plus_id, authentic_plus,
					card_id, omitted))
			var altered: Dictionary = authentic.duplicate(true)
			altered[field] = replacements[field]
			_forge_area_refused(card_id + ": record with a rewritten " + field, card_id,
				_area_forged_records(base_id, authentic_base, plus_id, authentic_plus,
					card_id, altered))
		var extra_effect: Dictionary = authentic.duplicate(true)
		extra_effect["effects"]["buttons_popped_gain"] = 1
		_forge_area_refused(card_id + ": record with an invented effect", card_id,
			_area_forged_records(base_id, authentic_base, plus_id, authentic_plus, card_id,
				extra_effect))
		var typed_cost: Dictionary = authentic.duplicate(true)
		typed_cost["cost"] = float(typed_cost["cost"])
		_forge_area_refused(card_id + ": record with a non-integer cost", card_id,
			_area_forged_records(base_id, authentic_base, plus_id, authentic_plus, card_id,
				typed_cost))
		var magnitude_key: String = "damage" \
			if str(AREA_PRINTINGS[card_id]["shape"]) == "volley" else "damage_per_button_popped"
		var typed_magnitude: Dictionary = authentic.duplicate(true)
		typed_magnitude["effects"][magnitude_key] = float(typed_magnitude["effects"][magnitude_key])
		_forge_area_refused(card_id + ": record with a non-integer magnitude", card_id,
			_area_forged_records(base_id, authentic_base, plus_id, authentic_plus, card_id,
				typed_magnitude))
		if str(AREA_PRINTINGS[card_id]["shape"]) == "volley":
			var typed_hit_count: Dictionary = authentic.duplicate(true)
			typed_hit_count["effects"]["hit_count"] = 2.0
			_forge_area_refused(card_id + ": record with a non-integer hit count", card_id,
				_area_forged_records(base_id, authentic_base, plus_id, authentic_plus, card_id,
					typed_hit_count))
			var merged_hits: Dictionary = authentic.duplicate(true)
			merged_hits["effects"]["independent_hits"] = 1
			_forge_area_refused(card_id + ": record that merges the two hits", card_id,
				_area_forged_records(base_id, authentic_base, plus_id, authentic_plus, card_id,
					merged_hits))
		var base_relinked: Dictionary = authentic_base.duplicate(true)
		base_relinked["upgrade_id"] = "button_golem_forged_area"
		_forge_area_refused(card_id + ": base record relinked away", card_id,
			_area_forged_records(base_id, base_relinked, plus_id, authentic_plus, card_id,
				authentic if upgraded else base_relinked))
		var plus_relinked: Dictionary = authentic_plus.duplicate(true)
		plus_relinked["upgrade_of"] = "button_golem_forged_area"
		_forge_area_refused(card_id + ": plus record relinked away", card_id,
			_area_forged_records(base_id, authentic_base, plus_id, plus_relinked, card_id,
				plus_relinked if upgraded else authentic))
		# The authentic records through the same seam still play the paid card.
		_forge_area_applied(card_id, _area_forged_records(base_id, authentic_base, plus_id,
			authentic_plus, card_id, authentic))


## The two records served to one forged resolver: the authentic pair with the target replaced.
func _area_forged_records(base_id: String, base_record: Dictionary, plus_id: String,
		plus_record: Dictionary, target_id: String, target_record: Dictionary) -> Dictionary:
	var records: Dictionary = {base_id: base_record, plus_id: plus_record}
	records[target_id] = target_record
	return records


func _forge_area_refused(label: String, card_id: String, records: Dictionary) -> void:
	var forged := ForgedArea.new()
	forged.forged = records
	var deck := _area_deck(card_id)
	var party := _roll_party(1)
	var enemies := _area_targets()
	var before := _area_snapshot(deck, party, enemies)
	var receipt: Dictionary = forged.play_card(deck, party, enemies, card_id, 0)
	_check(receipt.get("ok") == false and receipt.get("reason") == "catalog_mismatch",
		label + ": the forged record is refused as catalog_mismatch")
	_check(_area_snapshot(deck, party, enemies) == before,
		label + ": the forged record spends, discards and damages nothing")


func _forge_area_applied(card_id: String, records: Dictionary) -> void:
	var forged := ForgedArea.new()
	forged.forged = records
	var deck := _area_deck(card_id)
	var party := _roll_party(1)
	party._heroes[0]["buttons_popped"] = 2
	var enemies := _area_targets()
	var receipt: Dictionary = forged.play_card(deck, party, enemies, card_id, 0)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		card_id + ": the authentic records through the same seam still play")
	_check(deck.energy == 1 and deck.discard_pile == [card_id],
		card_id + ": the restored record spends exactly two energy and one held copy")
	_check(enemies.get_enemy(1).get("hp") < 20 and enemies.get_enemy(2).get("hp") < 20,
		card_id + ": the restored record really damages every living enemy")


func _volley_enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "area_brute", "max_hp": 20},
		{"id": "area_cog", "max_hp": 2},
		{"id": "area_spool", "max_hp": 20},
	])
	_check(enemies.is_valid() and enemies.get_enemy(2).get("max_hp") == 2,
		"volley fixture has three genuine slots and a two-HP middle slot")
	_check(enemies.apply_statuses({1: {"exposed": 1}}),
		"volley fixture marks the first slot Exposed through the roster API")
	_check(enemies.gain_block(3, 2), "volley fixture gives the third slot two Block")
	# The roster's status API only accepts Bleed/Weak/Exposed, so the applied Tangled count is
	# written onto the authoritative record directly, as the party status fixtures do.
	enemies._enemies[2]["statuses"] = {"tangled": 1}
	_check(enemies.get_enemy(3).get("statuses") == {"tangled": 1},
		"volley fixture stores a Tangled count on the third slot")
	return enemies


func _storm_enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "storm_brute", "max_hp": 40},
		{"id": "storm_cog", "max_hp": 10},
		{"id": "storm_spool", "max_hp": 40},
	])
	_check(enemies.is_valid(), "storm fixture has three genuine slots")
	_check(enemies.apply_statuses({1: {"exposed": 1}}),
		"storm fixture marks the first slot Exposed")
	_check(enemies.gain_block(1, 2), "storm fixture gives the first slot two Block")
	_check(enemies.apply_damage(2, 10) and enemies.is_slain(2),
		"storm fixture has a genuinely slain middle slot")
	enemies._enemies[2]["statuses"] = {"tangled": 1}
	_check(enemies.get_enemy(3).get("statuses") == {"tangled": 1},
		"storm fixture stores a Tangled count on the third slot")
	return enemies


func _area_targets() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "area_brute", "max_hp": 20},
		{"id": "area_cog", "max_hp": 20},
	])
	_check(enemies.is_valid(), "refusal fixture has a valid two-enemy roster")
	return enemies


## Seeded real CombatDeck that holds the exact printing plus filler, so the draw pile stays
## non-empty and nothing can be drawn without changing the seeded RNG state.
func _area_deck(card_id: String, seed_value: int = 907311) -> CombatDeck:
	var deck := _area_deck_of([card_id, "warden_strike", "warden_brace",
		"seamstress_stitch", "tinker_scrap", "seamstress_bind", "tinker_bolt"], seed_value)
	_check(deck.hand.has(card_id) and deck.hand.size() == 5 and deck.draw_pile.size() == 2,
		"the exact area printing is genuinely held with two cards left to draw")
	return deck


func _area_deck_of(ids: Array, seed_value: int = 907311) -> CombatDeck:
	var cards: Array[String] = []
	for id: Variant in ids:
		cards.append(str(id))
	var deck := CombatDeck.new(cards, _roll_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == mini(cards.size(), CombatDeck.TURN_DRAW),
		"seeded real CombatDeck starts a three-energy turn")
	return deck


func _area_inactive_deck(card_id: String) -> CombatDeck:
	var cards: Array[String] = [card_id, "warden_strike"]
	return CombatDeck.new(cards, _roll_rng(2981793))


## Detached before/after state for refusals: piles, turn, energy, seeded RNG and actor records.
func _area_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var snapshot: Dictionary = {}
	if deck != null:
		snapshot["draw"] = deck.draw_pile.duplicate(true)
		snapshot["hand"] = deck.hand.duplicate(true)
		snapshot["discard"] = deck.discard_pile.duplicate(true)
		if deck.combat_state != null:
			snapshot["turn"] = deck.turn_active
			snapshot["energy"] = deck.energy
			snapshot["state_turn"] = deck.combat_state.player_turn_active
			snapshot["state_energy"] = deck.combat_state.energy
		else:
			snapshot["combat_state"] = "missing"
		if deck._rng != null:
			snapshot["rng_state"] = deck._rng.state
			snapshot["rng_seed"] = deck._rng.seed
	if party != null:
		snapshot["party_valid"] = party.is_valid()
		snapshot["heroes"] = party.get_heroes()
	if enemies != null:
		snapshot["enemies_valid"] = enemies.is_valid()
		snapshot["enemies"] = enemies.get_enemies()
	return snapshot

