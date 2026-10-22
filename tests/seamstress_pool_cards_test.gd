extends SceneTree
## D2-1 Seamstress catalog contract. No live combat/reward/Rest behavior is assumed.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_starters_unchanged()
	if failures.is_empty():
		print("seamstress_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("seamstress_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"seamstress_running_stitch": {
			"name": "Running Stitch", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 2, "bleed": 3}, "plus_cost": 1,
			"plus_effects": {"damage": 3, "bleed": 4}},
		"seamstress_needle_pin": {
			"name": "Needle Pin", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 3, "pinned": true}, "plus_cost": 1,
			"plus_effects": {"damage": 4, "pinned": true}},
		"seamstress_darning": {
			"name": "Darning", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"heal": 4, "block": 3}, "plus_cost": 1,
			"plus_effects": {"heal": 6, "block": 4}},
		"seamstress_snag": {
			"name": "Snag", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"unravel": 3, "weak": 1}, "plus_cost": 1,
			"plus_effects": {"unravel": 4, "weak": 1}},
		"seamstress_thread_whip": {
			"name": "Thread Whip", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 6}, "plus_cost": 1,
			"plus_effects": {"damage": 8}},
		"seamstress_thimble_tea": {
			"name": "Thimble Tea", "rarity": "common", "cost": 0,
			"from": [2, 3], "target": "ally_single", "to": [],
			"effects": {"heal": 3}, "plus_cost": 0,
			"plus_effects": {"heal": 4}},
		"seamstress_hemorrhage_hem": {
			"name": "Hemorrhage Hem", "rarity": "uncommon", "cost": 2,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"bleed_multiplier": 2}, "plus_cost": 1,
			"plus_effects": {"bleed_multiplier": 2}},
		"seamstress_unpick": {
			"name": "Unpick", "rarity": "uncommon", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"unravel": 5}, "plus_cost": 1,
			"plus_effects": {"unravel": 7}},
		"seamstress_blanket_stitch": {
			"name": "Blanket Stitch", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"bleed": 2}, "plus_cost": 2,
			"plus_effects": {"bleed": 3}},
		"seamstress_field_mend": {
			"name": "Field Mend", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "party_all", "to": [],
			"effects": {"heal": 4}, "plus_cost": 2,
			"plus_effects": {"heal": 6}},
		"seamstress_red_thread": {
			"name": "Red Thread", "rarity": "rare", "cost": 2,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"bleed": 6, "exposed": 1}, "plus_cost": 2,
			"plus_effects": {"bleed": 8, "exposed": 1}},
		"seamstress_tailors_trance": {
			"name": "Tailor's Trance", "rarity": "rare", "cost": 1,
			"from": [2, 3], "target": "self", "to": [],
			"effects": {"energy": 1, "draw": 2}, "plus_cost": 1,
			"plus_effects": {"energy": 1, "draw": 3}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "seamstress",
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
	var catalog := SeamstressPoolCards.new()
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
		_check(not base_ids.has(plus_id), plus_id + " is not a base")
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
		_check(base_id != plus_id, base_id + " upgrade has distinct stable ID")


func _test_special_descriptors() -> void:
	var catalog := SeamstressPoolCards.new()
	for suffix: String in ["", "_plus"]:
		var hem: Dictionary = catalog.get_definition("seamstress_hemorrhage_hem" + suffix)
		_check(hem.get("effects") == {"bleed_multiplier": 2},
			"hem doubles existing Bleed, including zero; never adds flat Bleed" + suffix)
		var darning: Dictionary = catalog.get_definition("seamstress_darning" + suffix)
		_check(darning.get("target_kind") == "ally_single" and darning.get("to_positions") == [],
			"Darning chooses exactly one ally for both effects" + suffix)
		_check(darning.get("effects") == ({"heal": 6, "block": 4} if suffix != "" else {"heal": 4, "block": 3}),
			"Darning combines heal and Block on the chosen ally" + suffix)
		var blanket: Dictionary = catalog.get_definition("seamstress_blanket_stitch" + suffix)
		_check(blanket.get("target_kind") == "enemy_all" and blanket.get("to_positions") == [1, 2, 3],
			"Blanket Stitch applies its printed Bleed to each living enemy" + suffix)
		var field_mend: Dictionary = catalog.get_definition("seamstress_field_mend" + suffix)
		_check(field_mend.get("target_kind") == "party_all" and field_mend.get("to_positions") == [],
			"Field Mend heals all living allies" + suffix)


func _test_detached_results() -> void:
	var catalog := SeamstressPoolCards.new()
	var sample: Dictionary = catalog.get_definition("seamstress_running_stitch")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("seamstress_running_stitch")
	_check(pristine.get("effects") == {"damage": 2, "bleed": 3},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [1, 2, 3],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2, 3],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "seamstress_running_stitch", "metadata is detached")
	var upgraded: Dictionary = catalog.get_definition("seamstress_darning_plus")
	upgraded["effects"]["heal"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("seamstress_darning_plus").get("effects") == {"heal": 6, "block": 4},
		"upgrade effects are detached")
	_check(catalog.get_definition("seamstress_darning_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("seamstress_darning_plus").get("to_positions") == [],
		"empty upgrade TO is detached")
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("seamstress_darning") and all_ids.has("seamstress_darning_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("seamstress_darning"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("seamstress_darning_plus"), "all-ID array is a fresh copy")
	_check(SeamstressPoolCards.new().get_definition("seamstress_running_stitch") == pristine,
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog := SeamstressPoolCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("seamstress_darning"),
		"", "seamstress_not_a_card", "seamstress_running_stitch+", "seamstress_darning_plus_plus"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_starters_unchanged() -> void:
	var starter := StarterCards.new()
	var pool := SeamstressPoolCards.new()
	var deck: Array[String] = starter.get_starting_deck()
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "authored starter_deck.json parses as array")
	if not parsed is Array:
		return
	_check(deck.size() == 12 and parsed.size() == 12, "shared starter deck still has twelve cards")
	var expected_starters: Dictionary = {
		"seamstress_prick": {"count": 2, "effects": {"damage": 3, "bleed": 2}},
		"seamstress_mend": {"count": 1, "effects": {"heal": 5}},
		"seamstress_stitch_up": {"count": 1, "effects": {"block": 5}},
	}
	for id: String in expected_starters:
		var starter_record: Dictionary = starter.get_definition(id)
		_check(not starter_record.is_empty(), id + " remains a StarterCards definition")
		_check(starter_record.get("owner") == "seamstress", id + " remains Seamstress-owned")
		_check(starter_record.get("effects") == expected_starters[id]["effects"], id + " printed effects unchanged")
		_check(starter_record.get("starting_copies") == expected_starters[id]["count"],
			id + " catalog multiplicity unchanged")
		_check(deck.count(id) == expected_starters[id]["count"], id + " runtime deck copies unchanged")
		_check(parsed.count(id) == expected_starters[id]["count"], id + " JSON deck copies unchanged")
	_check(deck == parsed, "StarterCards deck and JSON stay identical in membership and order")
	for id: String in pool.get_all_card_ids():
		_check(not starter.has_card(id), id + " has not entered StarterCards")
		_check(not deck.has(id) and not parsed.has(id), id + " is absent from both starter decks")
