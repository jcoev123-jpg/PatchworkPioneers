extends SceneTree
## V3-1 Button Golem reward-pool catalog contract, plus the paid Roll rules service over the four
## authentic Threadwheel Roll / Button Roll printings.
## CATALOG + RULES SERVICE: the catalog checks below assert printed intent only (Pop Button and
## Sew On stay descriptor-only in this slice). The appended Roll cases drive a real seeded
## CombatDeck and CombatParty through CombatButtonGolemRollCards; no live hand, reward,
## party-picker or starter-deck wiring is assumed or tested here.

const ScriptClass = preload("res://data/cards/button_golem_pool_cards.gd")
const StarterCardsScript = preload("res://data/cards/starter_cards.gd")
const ButtonGolemStarterScript = preload("res://data/cards/button_golem_starter_cards.gd")
const RollResolverScript = preload("res://scripts/combat_button_golem_roll_cards.gd")
const RewardOffersScript = preload("res://scripts/run_pool_card_reward_offers.gd")

## The four authentic Roll printings, each authenticated against its OWN authored catalog.
const ROLL_PRINTINGS := {
	"button_golem_starter_threadwheel_roll": {"catalog": "starter", "block": 5},
	"button_golem_starter_threadwheel_roll_plus": {"catalog": "starter", "block": 7},
	"button_golem_button_roll": {"catalog": "pool", "block": 5},
	"button_golem_button_roll_plus": {"catalog": "pool", "block": 8},
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
## A future resolver owns Block payment, target availability and popped-button bookkeeping.
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

