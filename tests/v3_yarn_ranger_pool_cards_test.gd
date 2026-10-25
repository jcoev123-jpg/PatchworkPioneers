extends SceneTree
## V3-1 Yarn Ranger catalog contract. No live combat/reward/Rest behavior is assumed.

const YarnRangerPoolCards = preload("res://data/cards/yarn_ranger_pool_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_starters_unchanged()
	if failures.is_empty():
		print("v3_yarn_ranger_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_yarn_ranger_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"yarn_ranger_needle_arrow": {
			"name": "Needle Arrow", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 5, "unravel": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 7, "unravel": 2}},
		"yarn_ranger_tangle_bolas": {
			"name": "Tangle Bolas", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 2, "tangled": 2}, "plus_cost": 1,
			"plus_effects": {"damage": 3, "tangled": 3}},
		"yarn_ranger_reel_in": {
			"name": "Reel In", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [2, 3],
			"effects": {"pull_forward": 1, "tangled": 1}, "plus_cost": 1,
			"plus_effects": {"pull_forward": 1, "tangled": 2}},
		"yarn_ranger_knit_shield": {
			"name": "Knit Shield", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 6, "draw": 1}, "plus_cost": 1,
			"plus_effects": {"block": 8, "draw": 1}},
		"yarn_ranger_purling_barrage": {
			"name": "Purling Barrage", "rarity": "uncommon", "cost": 2,
			"from": [3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 3, "hit_count": 2, "unravel": 1}, "plus_cost": 2,
			"plus_effects": {"damage": 4, "hit_count": 2, "unravel": 2}},
		"yarn_ranger_snare_net": {
			"name": "Snare Net", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"tangled": 1, "living_targets_only": true}, "plus_cost": 2,
			"plus_effects": {"tangled": 2, "living_targets_only": true}},
		"yarn_ranger_unspool": {
			"name": "Unspool", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage": 7, "requires_target_status": "tangled", "living_targets_only": true}, "plus_cost": 2,
			"plus_effects": {"damage": 10, "requires_target_status": "tangled", "living_targets_only": true}},
		"yarn_ranger_endless_skein": {
			"name": "Endless Skein", "rarity": "rare", "cost": 3,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage": 4, "tangled": 2, "living_targets_only": true}, "plus_cost": 3,
			"plus_effects": {"damage": 6, "tangled": 3, "living_targets_only": true}},
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
	var catalog := YarnRangerPoolCards.new()
	var cases: Dictionary = _cases()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen: Dictionary = {}
	var thematic_count: int = 0
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
		
		# AC2 check
		var effects: Dictionary = spec["effects"]
		if effects.has("tangled") or effects.has("unravel") or effects.has("pull_forward") or effects.has("hit_count") or base_id == "yarn_ranger_unspool" or base_id == "yarn_ranger_knit_shield":
			thematic_count += 1
			
	_check(thematic_count >= 6, "at least six cards express thematic effects")


func _test_special_descriptors() -> void:
	var catalog := YarnRangerPoolCards.new()
	for suffix: String in ["", "_plus"]:
		var bolas: Dictionary = catalog.get_definition("yarn_ranger_tangle_bolas" + suffix)
		_check(bolas.get("effects").has("tangled"), "Tangle Bolas applies tangled" + suffix)
		var reel: Dictionary = catalog.get_definition("yarn_ranger_reel_in" + suffix)
		_check(reel.get("effects").has("pull_forward") and reel.get("effects").has("tangled"),
			"Reel In has pull_forward and tangled" + suffix)
		var unspool: Dictionary = catalog.get_definition("yarn_ranger_unspool" + suffix)
		_check(unspool.get("effects").has("requires_target_status") and unspool.get("effects").get("requires_target_status") == "tangled",
			"Unspool requires tangled status" + suffix)
		_check(unspool.get("effects").get("living_targets_only") == true,
			"Unspool specifies living targets only" + suffix)


func _test_detached_results() -> void:
	var catalog := YarnRangerPoolCards.new()
	var sample: Dictionary = catalog.get_definition("yarn_ranger_needle_arrow")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["unravel"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("yarn_ranger_needle_arrow")
	_check(pristine.get("effects") == {"damage": 5, "unravel": 1},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [2, 3],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2, 3],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "yarn_ranger_needle_arrow", "metadata is detached")
	var upgraded: Dictionary = catalog.get_definition("yarn_ranger_knit_shield_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("yarn_ranger_knit_shield_plus").get("effects") == {"block": 8, "draw": 1},
		"upgrade effects are detached")
	_check(catalog.get_definition("yarn_ranger_knit_shield_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("yarn_ranger_knit_shield_plus").get("to_positions") == [],
		"empty upgrade TO is detached")
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("yarn_ranger_needle_arrow") and all_ids.has("yarn_ranger_knit_shield_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("yarn_ranger_needle_arrow"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("yarn_ranger_knit_shield_plus"), "all-ID array is a fresh copy")
	_check(YarnRangerPoolCards.new().get_definition("yarn_ranger_needle_arrow") == pristine,
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog := YarnRangerPoolCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("yarn_ranger_needle_arrow"),
		"", "yarn_ranger_not_a_card", "yarn_ranger_needle_arrow+", "yarn_ranger_knit_shield_plus_plus"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_starters_unchanged() -> void:
	var starter := StarterCards.new()
	var pool := YarnRangerPoolCards.new()
	var deck: Array[String] = starter.get_starting_deck()
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "authored starter_deck.json parses as array")
	if not parsed is Array:
		return
	var expected_starters: Dictionary = {
		"warden_strike": {"count": 2, "effects": {"damage": 6}, "owner": "warden"},
		"warden_brace": {"count": 1, "effects": {"block": 7}, "owner": "warden"},
		"warden_shield_bash": {"count": 1, "effects": {"damage": 8, "weak": 1}, "owner": "warden"},
		"seamstress_prick": {"count": 2, "effects": {"damage": 3, "bleed": 2}, "owner": "seamstress"},
		"seamstress_mend": {"count": 1, "effects": {"heal": 5}, "owner": "seamstress"},
		"seamstress_stitch_up": {"count": 1, "effects": {"block": 5}, "owner": "seamstress"},
		"tinker_pop_shot": {"count": 2, "effects": {"damage": 5}, "owner": "tinker"},
		"tinker_scrap_bomb": {"count": 1, "effects": {"damage": 4}, "owner": "tinker"},
		"tinker_tune_up": {"count": 1, "effects": {"draw": 1}, "owner": "tinker"}
	}
	var total_count: int = 0
	for id: String in expected_starters:
		total_count += int(expected_starters[id]["count"])
	_check(deck.size() == total_count and parsed.size() == total_count, "shared starter deck size is unchanged")
	for id: String in expected_starters:
		var starter_record: Dictionary = starter.get_definition(id)
		_check(not starter_record.is_empty(), id + " remains a StarterCards definition")
		_check(starter_record.get("owner") == expected_starters[id]["owner"], id + " owner unchanged")
		_check(starter_record.get("effects") == expected_starters[id]["effects"], id + " printed effects unchanged")
		_check(starter_record.get("starting_copies") == expected_starters[id]["count"],
			id + " catalog multiplicity unchanged")
		_check(deck.count(id) == expected_starters[id]["count"], id + " runtime deck copies unchanged")
		_check(parsed.count(id) == expected_starters[id]["count"], id + " JSON deck copies unchanged")
	_check(deck == parsed, "StarterCards deck and JSON stay identical in membership and order")
	for id: String in pool.get_all_card_ids():
		_check(not starter.has_card(id), id + " has not entered StarterCards")
		_check(not deck.has(id) and not parsed.has(id), id + " is absent from both starter decks")
