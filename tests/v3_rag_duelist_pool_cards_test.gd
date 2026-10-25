extends SceneTree
## V3-1 Rag Duelist catalog contract. No live combat/reward/Rest behavior is assumed.

const ScriptClass = preload("res://data/cards/rag_duelist_pool_cards.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_rng_state()
	if failures.is_empty():
		print("v3_rag_duelist_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_rag_duelist_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"rag_duelist_needle_prick": {
			"name": "Needle Prick", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 4, "bleed": 2}, "plus_cost": 1,
			"plus_effects": {"damage": 6, "bleed": 3}},
		"rag_duelist_needle_lunge": {
			"name": "Needle Lunge", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 6, "move_self_forward": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 8, "move_self_forward": 1}},
		"rag_duelist_cape_guard": {
			"name": "Cape Guard", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block": 5, "riposte": 3, "duration": 1}, "plus_cost": 1,
			"plus_effects": {"block": 7, "riposte": 4, "duration": 1}},
		"rag_duelist_velvet_feint": {
			"name": "Velvet Feint", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"exposed": 1, "draw": 1}, "plus_cost": 0,
			"plus_effects": {"exposed": 1, "draw": 1}},
		"rag_duelist_duelist_reprise": {
			"name": "Duelist Reprise", "rarity": "uncommon", "cost": 1,
			"from": [1, 2], "target": "self", "to": [],
			"effects": {"riposte": 5, "duration": 1}, "plus_cost": 1,
			"plus_effects": {"riposte": 7, "duration": 1}},
		"rag_duelist_cape_flourish": {
			"name": "Cape Flourish", "rarity": "uncommon", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"dodge_next_attack": 1, "duration": 1}, "plus_cost": 0,
			"plus_effects": {"dodge_next_attack": 1, "duration": 1}},
		"rag_duelist_tattered_snare": {
			"name": "Tattered Snare", "rarity": "uncommon", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"tangled": 2}, "plus_cost": 1,
			"plus_effects": {"tangled": 3}},
		"rag_duelist_needle_barrage": {
			"name": "Needle Barrage", "rarity": "rare", "cost": 2,
			"from": [1], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 3, "hit_count": 3, "independent_hits": true}, "plus_cost": 2,
			"plus_effects": {"damage": 4, "hit_count": 3, "independent_hits": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "rag_duelist",
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
	var rarity_counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}

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
		rarity_counts[spec["rarity"]] += 1

		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and str(record.get(field)) == str(expected[field]),
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has effect descriptors")
		_check(base_id != plus_id, base_id + " upgrade has distinct stable ID")

	_check(rarity_counts["common"] == 4, "Exactly 4 common cards")
	_check(rarity_counts["uncommon"] == 3, "Exactly 3 uncommon cards")
	_check(rarity_counts["rare"] == 1, "Exactly 1 rare card")


func _test_special_descriptors() -> void:
	var catalog = ScriptClass.new()
	for suffix: String in ["", "_plus"]:
		var lunge: Dictionary = catalog.get_definition("rag_duelist_needle_lunge" + suffix)
		_check(lunge.get("effects").has("move_self_forward") and lunge.get("effects").get("move_self_forward") == 1,
			"Needle Lunge specifies exactly one slot of forward movement" + suffix)

		var flourish: Dictionary = catalog.get_definition("rag_duelist_cape_flourish" + suffix)
		_check(flourish.get("effects").has("dodge_next_attack") and flourish.get("effects").get("dodge_next_attack") == 1,
			"Cape Flourish specifically identifies dodging the next incoming attack" + suffix)

		var snare: Dictionary = catalog.get_definition("rag_duelist_tattered_snare" + suffix)
		_check(snare.get("effects").has("tangled"),
			"Tattered Snare specifies Tangled duration" + suffix)

		var barrage: Dictionary = catalog.get_definition("rag_duelist_needle_barrage" + suffix)
		_check(barrage.get("effects").has("hit_count") and barrage.get("effects").get("hit_count") == 3,
			"Needle Barrage specifies 3 hits" + suffix)
		_check(barrage.get("effects").has("independent_hits") and barrage.get("effects").get("independent_hits") == true,
			"Needle Barrage specifies independent hits for V3 Thorns" + suffix)

		var reprise: Dictionary = catalog.get_definition("rag_duelist_duelist_reprise" + suffix)
		_check(reprise.get("effects").has("riposte") and reprise.get("effects").has("duration"),
			"Riposte explicitly tracks value and duration" + suffix)


func _test_detached_results() -> void:
	var catalog = ScriptClass.new()
	var sample: Dictionary = catalog.get_definition("rag_duelist_needle_prick")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("rag_duelist_needle_prick")
	_check(pristine.get("effects") == {"damage": 4, "bleed": 2},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [1, 2],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "rag_duelist_needle_prick", "metadata is detached")

	var upgraded: Dictionary = catalog.get_definition("rag_duelist_cape_guard_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("effects") == {"block": 7, "riposte": 4, "duration": 1},
		"upgrade effects are detached")
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("to_positions") == [],
		"empty upgrade TO is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("rag_duelist_cape_guard") and all_ids.has("rag_duelist_cape_guard_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("rag_duelist_cape_guard"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("rag_duelist_cape_guard_plus"), "all-ID array is a fresh copy")
	_check(ScriptClass.new().get_definition("rag_duelist_needle_prick").get("effects") == pristine.get("effects"),
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog = ScriptClass.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("rag_duelist_cape_guard"),
		"", "rag_duelist_not_a_card", "rag_duelist_needle_prick+", "rag_duelist_cape_guard_plus_plus"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_rng_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var initial_state: int = rng.state
	var catalog = ScriptClass.new()
	var ids: Array[String] = catalog.get_all_card_ids()
	for id: String in ids:
		var def: Dictionary = catalog.get_definition(id)
	_check(rng.state == initial_state, "constructing/enumerating catalog consumes no run RNG")

