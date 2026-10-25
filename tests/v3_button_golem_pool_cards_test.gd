extends SceneTree
## V3-1 Button Golem reward-pool catalog contract.
## DESCRIPTOR-ONLY: this test never plays these cards and assumes no live combat, reward,
## party-picker or starter-deck behavior. Every effect below is printed intent for a later
## wiring task; Pop Button does not actually spend Block and Sew On does not actually count buttons.

const ScriptClass = preload("res://data/cards/button_golem_pool_cards.gd")
const StarterCardsScript = preload("res://data/cards/starter_cards.gd")
const RewardOffersScript = preload("res://scripts/run_pool_card_reward_offers.gd")

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
