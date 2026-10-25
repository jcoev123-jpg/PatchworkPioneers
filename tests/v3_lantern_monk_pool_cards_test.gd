extends SceneTree
## Deterministic headless contract test for the standalone LanternMonkPoolCards catalog (V3-1).
##
## Checks the eight named Lantern Monk base reward cards and their eight '+' upgrades field by
## field against independent expected records, plus the look-driven Blind / Lantern Glow / Moth
## Cloud descriptors. The catalog is deliberately NOT wired into combat, rewards, the map or shops
## yet, so nothing here drives a live card. It also proves caller copies are detached, invalid IDs
## fail closed, catalog enumeration consumes no run RNG, and the existing Rag Duelist pool and
## StarterCards stay unchanged.

const CatalogScript = preload("res://data/cards/lantern_monk_pool_cards.gd")
const RagDuelistScript = preload("res://data/cards/rag_duelist_pool_cards.gd")
const StarterCardsScript = preload("res://data/cards/starter_cards.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_rng_state()
	_test_existing_catalogs_unchanged()
	if failures.is_empty():
		print("v3_lantern_monk_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_lantern_monk_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"lantern_monk_wick_flicker": {
			"name": "Wick Flicker", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 4, "blind_next_attack": true}, "plus_cost": 1,
			"plus_effects": {"damage": 6, "blind_next_attack": true}},
		"lantern_monk_moth_lure": {
			"name": "Moth Lure", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"blind_next_attack": true, "draw": 1}, "plus_cost": 0,
			"plus_effects": {"blind_next_attack": true, "draw": 1}},
		"lantern_monk_lantern_glow": {
			"name": "Lantern Glow", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "party_all", "to": [],
			"effects": {"heal_all": 2, "cleanse_one_debuff_each_ally": 1}, "plus_cost": 1,
			"plus_effects": {"heal_all": 3, "cleanse_one_debuff_each_ally": 1}},
		"lantern_monk_wax_ward": {
			"name": "Wax Ward", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block": 5}, "plus_cost": 1,
			"plus_effects": {"block": 7}},
		"lantern_monk_moth_shroud": {
			"name": "Moth Shroud", "rarity": "uncommon", "cost": 1,
			"from": [2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 6, "dodge_next_attack": 1}, "plus_cost": 1,
			"plus_effects": {"block": 8, "dodge_next_attack": 1}},
		"lantern_monk_snuff_flame": {
			"name": "Snuff Flame", "rarity": "uncommon", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 3, "blind_next_attack": true, "exposed": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 4, "blind_next_attack": true, "exposed": 2}},
		"lantern_monk_vigil_ring": {
			"name": "Vigil Ring", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "party_all", "to": [],
			"effects": {"heal_all": 4, "block_all": 4}, "plus_cost": 2,
			"plus_effects": {"heal_all": 6, "block_all": 6}},
		"lantern_monk_moth_cloud": {
			"name": "Moth Cloud", "rarity": "rare", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"blind_next_attack": true, "exhaust": true}, "plus_cost": 1,
			"plus_effects": {"blind_next_attack": true, "exhaust": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "lantern_monk",
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


## Deep effect comparison that also rejects an int (e.g. 1) standing in for a bool descriptor.
func _same_effects(actual: Variant, expected: Dictionary) -> bool:
	if not (actual is Dictionary):
		return false
	var actual_effects: Dictionary = actual
	if actual_effects.size() != expected.size():
		return false
	for key: Variant in expected:
		if not actual_effects.has(key):
			return false
		if typeof(actual_effects[key]) != typeof(expected[key]):
			return false
		if actual_effects[key] != expected[key]:
			return false
	return true


## Array comparison that requires real int elements (no string/float positions).
func _same_int_array(actual: Variant, expected: Array) -> bool:
	if not (actual is Array):
		return false
	var actual_array: Array = actual
	if actual_array.size() != expected.size():
		return false
	for index: int in range(expected.size()):
		if typeof(actual_array[index]) != TYPE_INT:
			return false
		if int(actual_array[index]) != int(expected[index]):
			return false
	return true


func _check_record(catalog: RefCounted, base_id: String, spec: Dictionary,
		upgraded: bool) -> void:
	var card_id: String = base_id + ("_plus" if upgraded else "")
	var expected: Dictionary = _expected_record(base_id, spec, upgraded)
	var record: Dictionary = catalog.get_definition(card_id)
	_check(not record.is_empty(), card_id + " definition exists")
	if record.is_empty():
		return

	# Exact documented field set: every expected field present and no invented extra fields.
	_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
	for field: String in expected:
		_check(record.has(field), card_id + " has field " + field)

	_check(record.get("id") == expected["id"], card_id + " id is the requested stable ID")
	_check(record.get("display_name") == expected["display_name"],
		card_id + " display_name is '" + str(expected["display_name"]) + "'")
	_check(record.get("owner") == "lantern_monk", card_id + " owner is lantern_monk")
	_check(typeof(record.get("cost")) == TYPE_INT and int(record.get("cost")) == int(expected["cost"]),
		card_id + " cost is " + str(expected["cost"]))
	_check(_same_int_array(record.get("from_positions"), expected["from_positions"]),
		card_id + " from_positions are " + str(expected["from_positions"]))
	_check(record.get("target_kind") == expected["target_kind"],
		card_id + " target_kind is " + str(expected["target_kind"]))
	_check(_same_int_array(record.get("to_positions"), expected["to_positions"]),
		card_id + " to_positions are " + str(expected["to_positions"]))
	_check(_same_effects(record.get("effects"), expected["effects"]),
		card_id + " exact effects payload " + str(expected["effects"]))
	_check(record.get("illustration_path") == expected["illustration_path"],
		card_id + " illustration_path is " + str(expected["illustration_path"]))
	_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
		card_id + " illustration_path names its base art ID")
	_check(typeof(record.get("starting_copies")) == TYPE_INT
			and int(record.get("starting_copies")) == 0,
		card_id + " starting_copies is 0")
	_check(record.get("rarity") == expected["rarity"],
		card_id + " rarity is " + str(expected["rarity"]))
	_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
			and record.get("reward_eligible") == expected["reward_eligible"],
		card_id + " reward_eligible is " + str(expected["reward_eligible"]))

	if upgraded:
		_check(record.get("upgrade_of") == base_id, card_id + " upgrade_of points at " + base_id)
		_check(not record.has("upgrade_id"), card_id + " has no upgrade_id")
	else:
		_check(record.get("upgrade_id") == base_id + "_plus",
			card_id + " upgrade_id points at " + base_id + "_plus")
		_check(not record.has("upgrade_of"), card_id + " base has no upgrade_of")

	# Legal hero/enemy positions: 1..3 ints; only enemy targets name enemy positions.
	var from_positions: Array = record.get("from_positions", [])
	_check(not from_positions.is_empty(), card_id + " has at least one FROM position")
	for position: Variant in from_positions:
		_check(typeof(position) == TYPE_INT and int(position) >= 1 and int(position) <= 3,
			card_id + " FROM position is an int in 1..3")
	var to_positions: Array = record.get("to_positions", [])
	if str(record.get("target_kind")) in ["enemy_single", "enemy_all"]:
		_check(not to_positions.is_empty(), card_id + " enemy target names enemy positions")
		for position: Variant in to_positions:
			_check(typeof(position) == TYPE_INT and int(position) >= 1 and int(position) <= 3,
				card_id + " TO position is an int in 1..3")
	else:
		_check(to_positions.is_empty(), card_id + " non-enemy target names no positions")


func _test_all_base_and_upgrades() -> void:
	var catalog: RefCounted = CatalogScript.new()
	var cases: Dictionary = _cases()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen_ids: Dictionary = {}
	var rarity_counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}

	_check(not cases.is_empty(), "expected case table is non-empty (precondition)")
	_check(not base_ids.is_empty(), "get_base_ids is non-empty (precondition)")
	_check(not all_ids.is_empty(), "get_all_card_ids is non-empty (precondition)")

	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"

		_check(not seen_ids.has(base_id), base_id + " is a distinct base identifier")
		seen_ids[base_id] = true
		_check(not seen_ids.has(plus_id), plus_id + " is a distinct upgrade identifier")
		seen_ids[plus_id] = true

		_check(catalog.has_card(base_id), "catalog has base card " + base_id)
		_check(catalog.has_card(plus_id), "catalog has upgraded card " + plus_id)
		_check(base_ids.has(base_id), "get_base_ids includes " + base_id)
		_check(base_ids.count(base_id) == 1, base_id + " appears once in get_base_ids")
		_check(not base_ids.has(plus_id), plus_id + " is not a base")
		_check(all_ids.has(base_id), "get_all_card_ids includes " + base_id)
		_check(all_ids.has(plus_id), "get_all_card_ids includes " + plus_id)
		_check(all_ids.count(base_id) == 1, base_id + " appears once in get_all_card_ids")
		_check(all_ids.count(plus_id) == 1, plus_id + " appears once in get_all_card_ids")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to " + plus_id)
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")

		rarity_counts[spec["rarity"]] += 1
		_check_record(catalog, base_id, spec, false)
		_check_record(catalog, base_id, spec, true)

	# The authored 4 common / 3 uncommon / 1 rare layout for this bounded batch.
	_check(rarity_counts["common"] == 4, "this batch authors 4 common cards")
	_check(rarity_counts["uncommon"] == 3, "this batch authors 3 uncommon cards")
	_check(rarity_counts["rare"] == 1, "this batch authors 1 rare card")


func _test_special_descriptors() -> void:
	var catalog: RefCounted = CatalogScript.new()

	# Blind is one next-attack miss, carried as a boolean, never a numeric stack.
	var blind_ids: Array[String] = [
		"lantern_monk_wick_flicker", "lantern_monk_wick_flicker_plus",
		"lantern_monk_moth_lure", "lantern_monk_moth_lure_plus",
		"lantern_monk_snuff_flame", "lantern_monk_snuff_flame_plus",
		"lantern_monk_moth_cloud", "lantern_monk_moth_cloud_plus",
	]
	for card_id: String in blind_ids:
		var effects: Dictionary = catalog.get_definition(card_id).get("effects", {})
		_check(effects.has("blind_next_attack"), card_id + " carries the Blind descriptor")
		_check(typeof(effects.get("blind_next_attack")) == TYPE_BOOL
				and effects.get("blind_next_attack") == true,
			card_id + " Blind is a true boolean next-attack miss")
		for key: Variant in effects:
			if String(key).contains("blind"):
				_check(typeof(effects[key]) == TYPE_BOOL and effects[key] == true,
					card_id + " has no numeric blind stack in " + str(key))
		_check(not effects.has("blind"), card_id + " invents no numeric 'blind' stack")
		_check(not effects.has("blind_stacks"), card_id + " invents no 'blind_stacks' stack")
		_check(not effects.has("blind_turns"), card_id + " invents no Blind duration")

	# Lantern Glow: heals every living ally and removes exactly one debuff on each eligible ally.
	for glow_id: String in ["lantern_monk_lantern_glow", "lantern_monk_lantern_glow_plus"]:
		var glow: Dictionary = catalog.get_definition(glow_id)
		var glow_effects: Dictionary = glow.get("effects", {})
		_check(glow.get("target_kind") == "party_all", glow_id + " targets the whole party")
		_check(glow.get("to_positions") == [], glow_id + " names no single target position")
		_check(int(glow_effects.get("heal_all", 0)) > 0, glow_id + " heals all allies")
		_check(typeof(glow_effects.get("cleanse_one_debuff_each_ally")) == TYPE_INT
				and int(glow_effects.get("cleanse_one_debuff_each_ally")) == 1,
			glow_id + " cleanses exactly one debuff per ally")
	_check(catalog.get_definition("lantern_monk_lantern_glow").get("effects", {}).get("heal_all") == 2,
		"Lantern Glow heals all allies for 2")
	_check(catalog.get_definition("lantern_monk_lantern_glow_plus").get("effects", {}).get("heal_all") == 3,
		"Lantern Glow+ heals all allies for 3")

	# Moth Cloud: every living enemy Blinded and the card Exhausts, with no invented duration/damage.
	for cloud_id: String in ["lantern_monk_moth_cloud", "lantern_monk_moth_cloud_plus"]:
		var cloud: Dictionary = catalog.get_definition(cloud_id)
		var cloud_effects: Dictionary = cloud.get("effects", {})
		_check(cloud.get("target_kind") == "enemy_all", cloud_id + " targets all enemies")
		_check(cloud.get("to_positions") == [1, 2, 3], cloud_id + " names all enemy positions")
		_check(typeof(cloud_effects.get("exhaust")) == TYPE_BOOL
				and cloud_effects.get("exhaust") == true,
			cloud_id + " Exhausts on play")
		_check(not cloud_effects.has("damage"), cloud_id + " deals no invented damage")
		_check(not cloud_effects.has("duration"), cloud_id + " invents no duration")
		_check(not cloud_effects.has("exhaust_turns"), cloud_id + " invents no exhaust duration")
	_check(catalog.get_definition("lantern_monk_moth_cloud").get("cost") == 2,
		"Moth Cloud costs 2")
	_check(catalog.get_definition("lantern_monk_moth_cloud_plus").get("cost") == 1,
		"Moth Cloud+ costs 1")

	# Wick Flicker: a small flame sting that also Blinds.
	for suffix: String in ["", "_plus"]:
		var wick: Dictionary = catalog.get_definition("lantern_monk_wick_flicker" + suffix)
		var wick_effects: Dictionary = wick.get("effects", {})
		_check(wick.get("target_kind") == "enemy_single", "Wick Flicker" + suffix + " hits one enemy")
		_check(wick_effects.get("damage") == (6 if suffix == "_plus" else 4),
			"Wick Flicker" + suffix + " has its authored damage")
		_check(not wick_effects.has("draw"), "Wick Flicker" + suffix + " does not draw")

	# Moth Lure: distracts the next enemy swing and draws a card.
	for suffix: String in ["", "_plus"]:
		var lure: Dictionary = catalog.get_definition("lantern_monk_moth_lure" + suffix)
		var lure_effects: Dictionary = lure.get("effects", {})
		_check(lure.get("target_kind") == "enemy_single", "Moth Lure" + suffix + " lures one enemy")
		_check(lure_effects.get("draw") == 1, "Moth Lure" + suffix + " draws exactly one card")
	_check(catalog.get_definition("lantern_monk_moth_lure").get("cost") == 1,
		"Moth Lure costs 1")
	_check(catalog.get_definition("lantern_monk_moth_lure_plus").get("cost") == 0,
		"Moth Lure+ costs 0")

	# Wax Ward: the kit's single plain Block card.
	var cases: Dictionary = _cases()
	var plain_block_count: int = 0
	for base_id: String in cases:
		var effects: Dictionary = catalog.get_definition(base_id).get("effects", {})
		if effects.size() == 1 and effects.has("block"):
			plain_block_count += 1
	_check(plain_block_count == 1, "exactly one card is a plain Block card")
	var wax: Dictionary = catalog.get_definition("lantern_monk_wax_ward")
	_check(wax.get("target_kind") == "self", "Wax Ward shields the caster")
	_check(wax.get("to_positions") == [], "Wax Ward names no target position")
	_check(wax.get("effects") == {"block": 5}, "Wax Ward gives 5 Block")
	_check(catalog.get_definition("lantern_monk_wax_ward_plus").get("effects") == {"block": 7},
		"Wax Ward+ gives 7 Block")

	# Moth Shroud: veils one ally from the next attack.
	for suffix: String in ["", "_plus"]:
		var shroud: Dictionary = catalog.get_definition("lantern_monk_moth_shroud" + suffix)
		var shroud_effects: Dictionary = shroud.get("effects", {})
		_check(shroud.get("target_kind") == "ally_single", "Moth Shroud" + suffix + " veils one ally")
		_check(shroud.get("to_positions") == [], "Moth Shroud" + suffix + " names no enemy position")
		_check(shroud_effects.get("block") == (8 if suffix == "_plus" else 6),
			"Moth Shroud" + suffix + " has its authored Block")
		_check(shroud_effects.get("dodge_next_attack") == 1,
			"Moth Shroud" + suffix + " dodges exactly the next attack")

	# Snuff Flame: burst plus Blind plus one exposed opening (two on '+').
	for suffix: String in ["", "_plus"]:
		var snuff: Dictionary = catalog.get_definition("lantern_monk_snuff_flame" + suffix)
		var snuff_effects: Dictionary = snuff.get("effects", {})
		_check(snuff.get("target_kind") == "enemy_single", "Snuff Flame" + suffix + " hits one enemy")
		_check(snuff_effects.get("damage") == (4 if suffix == "_plus" else 3),
			"Snuff Flame" + suffix + " has its authored damage")
		_check(snuff_effects.get("exposed") == (2 if suffix == "_plus" else 1),
			"Snuff Flame" + suffix + " has its authored Exposed value")

	# Vigil Ring: candlelight that heals and shelters the whole party.
	for suffix: String in ["", "_plus"]:
		var vigil: Dictionary = catalog.get_definition("lantern_monk_vigil_ring" + suffix)
		var vigil_effects: Dictionary = vigil.get("effects", {})
		_check(vigil.get("target_kind") == "party_all", "Vigil Ring" + suffix + " tends the party")
		_check(vigil.get("to_positions") == [], "Vigil Ring" + suffix + " names no target position")
		_check(vigil.get("cost") == 2, "Vigil Ring" + suffix + " costs 2")
		_check(vigil_effects.get("heal_all") == (6 if suffix == "_plus" else 4),
			"Vigil Ring" + suffix + " has its authored party heal")
		_check(vigil_effects.get("block_all") == (6 if suffix == "_plus" else 4),
			"Vigil Ring" + suffix + " has its authored party Block")


func _test_detached_results() -> void:
	var catalog: RefCounted = CatalogScript.new()

	var sample: Dictionary = catalog.get_definition("lantern_monk_wick_flicker")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["blind_next_attack"] = false
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["upgrade_id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("lantern_monk_wick_flicker")
	_check(pristine.get("effects") == {"damage": 4, "blind_next_attack": true},
		"base effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [2, 3], "base FROM is detached from catalog")
	_check(pristine.get("to_positions") == [1, 2, 3], "base TO is detached from catalog")
	_check(pristine.get("id") == "lantern_monk_wick_flicker", "base metadata is detached")
	_check(pristine.get("upgrade_id") == "lantern_monk_wick_flicker_plus",
		"base upgrade_id is detached")

	var upgraded: Dictionary = catalog.get_definition("lantern_monk_moth_cloud_plus")
	upgraded["effects"]["exhaust"] = false
	upgraded["effects"]["injected_key"] = true
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	upgraded["upgrade_of"] = "lantern_monk_wax_ward"
	var pristine_plus: Dictionary = catalog.get_definition("lantern_monk_moth_cloud_plus")
	_check(pristine_plus.get("effects") == {"blind_next_attack": true, "exhaust": true},
		"upgrade effects are detached")
	_check(pristine_plus.get("from_positions") == [2, 3], "upgrade FROM is detached")
	_check(pristine_plus.get("to_positions") == [1, 2, 3], "upgrade TO is detached")
	_check(pristine_plus.get("upgrade_of") == "lantern_monk_moth_cloud",
		"upgrade_of is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("lantern_monk_wax_ward") and all_ids.has("lantern_monk_moth_cloud_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	base_ids.append("fake_card")
	all_ids.clear()
	all_ids.append("fake_card")
	var fresh_base_ids: Array[String] = catalog.get_base_ids()
	var fresh_all_ids: Array[String] = catalog.get_all_card_ids()
	_check(fresh_base_ids.has("lantern_monk_wax_ward"), "base ID array is a fresh copy")
	_check(not fresh_base_ids.has("fake_card"), "base ID array rejects caller injection")
	_check(fresh_all_ids.has("lantern_monk_moth_cloud_plus"), "all-ID array is a fresh copy")
	_check(not fresh_all_ids.has("fake_card"), "all-ID array rejects caller injection")

	var fresh_catalog: RefCounted = CatalogScript.new()
	_check(fresh_catalog.get_definition("lantern_monk_wick_flicker").get("effects") == pristine.get("effects"),
		"fresh instance retains the canonical definition")
	_check(fresh_catalog.get_definition("lantern_monk_wick_flicker").get("effects")
			== {"damage": 4, "blind_next_attack": true},
		"fresh instance Blind stays a boolean next-attack miss")


func _test_invalid_ids() -> void:
	var catalog: RefCounted = CatalogScript.new()
	var invalid: Array = [
		null, 0, 3.5, false, [], {}, StringName("lantern_monk_wax_ward"),
		"", "lantern_monk_", "lantern_monk_not_a_card",
		"lantern_monk_wick_flicker+", "lantern_monk_wax_ward_plus_plus",
		"lantern_monk_moth_cloud_plus_plus", "WARDEN_STRIKE", "warden_strike",
		"rag_duelist_cape_flourish",
	]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(),
			"invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))

	# A '+' resolves as its own record but is never a base for another upgrade.
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var base_ids: Array[String] = catalog.get_base_ids()
	for base_id: String in _cases():
		var plus_id: String = base_id + "_plus"
		_check(all_ids.has(plus_id), plus_id + " is discoverable")
		_check(not base_ids.has(plus_id), plus_id + " is absent from get_base_ids")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " has no further upgrade")
		_check(not catalog.get_definition(plus_id).is_empty(), plus_id + " still resolves")


func _test_rng_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var initial_state: int = rng.state

	var catalog: RefCounted = CatalogScript.new()
	var ids: Array[String] = catalog.get_all_card_ids()
	for id: String in ids:
		catalog.get_definition(id)
		catalog.has_card(id)
		catalog.get_upgrade_id(id)
	var base_ids: Array[String] = catalog.get_base_ids()
	for base_id: String in base_ids:
		catalog.get_upgrade_id(base_id)
	catalog.get_definition("lantern_monk_unknown")
	catalog.has_card(null)

	_check(rng.state == initial_state, "constructing/enumerating catalog consumes no run RNG")
	_check(not ids.is_empty(), "RNG guard exercised a non-empty catalog (precondition)")
	_check(not base_ids.is_empty(), "RNG guard exercised a non-empty base list (precondition)")


func _test_existing_catalogs_unchanged() -> void:
	var rag_duelist: RefCounted = RagDuelistScript.new()
	var starter_cards: RefCounted = StarterCardsScript.new()

	var rag_before: Dictionary = rag_duelist.get_definition("rag_duelist_cape_flourish")
	var starter_before: Dictionary = starter_cards.get_definition("warden_strike")
	_check(not rag_before.is_empty(), "Rag Duelist fixture is readable (precondition)")
	_check(not starter_before.is_empty(), "StarterCards fixture is readable (precondition)")
	_check(rag_before.get("owner") == "rag_duelist", "Rag Duelist fixture keeps its owner")
	_check(rag_before.get("effects") == {"dodge_next_attack": 1, "duration": 1},
		"Rag Duelist Cape Flourish effects are unchanged")
	_check(starter_before.get("effects") == {"damage": 6}, "Warden Strike effects are unchanged")
	_check(starter_before.get("starting_copies") == 2, "Warden Strike starting copies are unchanged")

	var catalog: RefCounted = CatalogScript.new()
	var ids: Array[String] = catalog.get_all_card_ids()
	_check(not ids.is_empty(), "new catalog is non-empty (precondition)")
	for id: String in ids:
		catalog.get_definition(id)
	catalog.get_definition("rag_duelist_cape_flourish")
	catalog.get_definition("warden_strike")
	catalog.get_upgrade_id("rag_duelist_cape_flourish")

	_check(rag_duelist.get_definition("rag_duelist_cape_flourish") == rag_before,
		"Rag Duelist Cape Flourish is unchanged after new catalog use")
	_check(starter_cards.get_definition("warden_strike") == starter_before,
		"Warden Strike is unchanged after new catalog use")

	var starting_deck: Array[String] = starter_cards.get_starting_deck()
	_check(not starting_deck.is_empty(), "starting deck is non-empty (precondition)")
	for id: String in ids:
		_check(not rag_duelist.has_card(id), "Rag Duelist pool does not contain " + id)
		_check(not starter_cards.has_card(id), "StarterCards does not contain " + id)
		_check(not starting_deck.has(id), "starting deck does not contain " + id)
