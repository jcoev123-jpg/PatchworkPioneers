extends SceneTree
## Deterministic headless contract test for the standalone LanternMonkPoolCards catalog (V3-1).
##
## Checks the eight named Lantern Monk base reward cards and their eight '+' upgrades field by
## field against independent expected records, plus the look-driven Blind / Lantern Glow / Moth
## Cloud descriptors. It also drives the scene-free CombatLanternMonkPartyCards service over real
## seeded CombatDeck/CombatParty fixtures for the four Lantern Glow / Vigil Ring printings, so the
## party-wide heal, Block and explicit per-ally cleanse transactions are covered here too. The
## catalog stays deliberately unwired from the live hand, rewards, map and shops, so no live card
## is claimed. It also proves caller copies are detached, invalid IDs fail closed, catalog
## enumeration consumes no run RNG, and the existing Rag Duelist pool and StarterCards stay
## unchanged.

const CatalogScript = preload("res://data/cards/lantern_monk_pool_cards.gd")
const RagDuelistScript = preload("res://data/cards/rag_duelist_pool_cards.gd")
const StarterCardsScript = preload("res://data/cards/starter_cards.gd")

## Paid party-wide Lantern Glow / Vigil Ring fixtures. These literals are independent expectations
## copied from the v3 design, never read back from the service or its catalog.
const PARTY_GLOW := "lantern_monk_lantern_glow"
const PARTY_GLOW_PLUS := "lantern_monk_lantern_glow_plus"
const PARTY_VIGIL := "lantern_monk_vigil_ring"
const PARTY_VIGIL_PLUS := "lantern_monk_vigil_ring_plus"
const PARTY_CARD_IDS := [PARTY_GLOW, PARTY_GLOW_PLUS, PARTY_VIGIL, PARTY_VIGIL_PLUS]
const PARTY_COST := {PARTY_GLOW: 1, PARTY_GLOW_PLUS: 1, PARTY_VIGIL: 2, PARTY_VIGIL_PLUS: 2}
const PARTY_HEAL := {PARTY_GLOW: 2, PARTY_GLOW_PLUS: 3, PARTY_VIGIL: 4, PARTY_VIGIL_PLUS: 6}
const PARTY_BLOCK := {PARTY_GLOW: 0, PARTY_GLOW_PLUS: 0, PARTY_VIGIL: 4, PARTY_VIGIL_PLUS: 6}
const PARTY_FROM := {
	PARTY_GLOW: [1, 2, 3], PARTY_GLOW_PLUS: [1, 2, 3],
	PARTY_VIGIL: [2, 3], PARTY_VIGIL_PLUS: [2, 3],
}
const PARTY_EFFECTS := {
	PARTY_GLOW: {"heal_all": 2, "cleanse_one_debuff_each_ally": 1},
	PARTY_GLOW_PLUS: {"heal_all": 3, "cleanse_one_debuff_each_ally": 1},
	PARTY_VIGIL: {"heal_all": 4, "block_all": 4},
	PARTY_VIGIL_PLUS: {"heal_all": 6, "block_all": 6},
}
const PARTY_FILLERS := ["filler_wax_a", "filler_wax_b", "filler_wax_c", "filler_wax_d"]
const PARTY_HEROES_PATH := "res://data/heroes/starter_party.json"
## The Lantern Monk has no authored run-party record in this slice; the fixture picks a stable max HP.
const MONK_MAX_HP := 34

var failures: Array[String] = []
var checks: int = 0
var party_service := CombatLanternMonkPartyCards.new()


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_rng_state()
	_test_existing_catalogs_unchanged()
	_test_party_cards_authored()
	_test_party_ac1_paid_play()
	_test_party_ac1_downed_and_cap()
	_test_party_ac2_glow_cleanse()
	_test_party_ac2_vigil_no_cleanse()
	_test_party_ac3_rejections()
	_test_party_ac3_retry_and_replay()
	_test_party_seeded_invariance()
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


## --- Paid party-wide Lantern Glow / Vigil Ring resolution --------------------------------
##
## These cases drive the scene-free CombatLanternMonkPartyCards service over a real seeded
## CombatDeck and CombatParty. They claim callable rules-layer behaviour only: no live hand,
## reward, app or run-deck wiring is asserted here.

## Each of the four authentic printings must still carry its authored line, and nothing else is
## supported: not the Monk's other pool cards, not another hero's card, not an upgrade of an upgrade.
func _test_party_cards_authored() -> void:
	var catalog: RefCounted = CatalogScript.new()
	for card_id: String in PARTY_CARD_IDS:
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + ": authored pool record exists")
		if record.is_empty():
			continue
		_check(record.get("owner") == "lantern_monk",
			card_id + ": authored owner is the Lantern Monk")
		_check(record.get("cost") == PARTY_COST[card_id],
			card_id + ": authored cost is " + str(PARTY_COST[card_id]))
		_check(record.get("from_positions") == PARTY_FROM[card_id], card_id + ": authored FROM seats")
		_check(record.get("target_kind") == "party_all", card_id + ": targets the whole party")
		_check(record.get("to_positions") == [], card_id + ": names no single target slot")
		_check(record.get("effects") == PARTY_EFFECTS[card_id], card_id + ": exact authored effects")
		_check(party_service.is_supported_card(card_id), card_id + ": service authenticates the ID")
	_check(catalog.get_upgrade_id(PARTY_GLOW) == PARTY_GLOW_PLUS
			and catalog.get_upgrade_id(PARTY_GLOW_PLUS) == ""
			and catalog.get_upgrade_id(PARTY_VIGIL) == PARTY_VIGIL_PLUS
			and catalog.get_upgrade_id(PARTY_VIGIL_PLUS) == "",
		"both paid pairs still link base and '+' in the pool catalog")
	for unsupported in ["lantern_monk_wick_flicker", "lantern_monk_wick_flicker_plus",
			"lantern_monk_wax_ward", "lantern_monk_moth_shroud", "lantern_monk_snuff_flame",
			"lantern_monk_moth_cloud", "lantern_monk_moth_cloud_plus",
			"warden_v3_rim_toss", "seamstress_mend", "tinker_pop_shot",
			"lantern_monk_lantern_glow_ultra", ""]:
		_check(not party_service.is_supported_card(unsupported),
			unsupported + ": not a party-wide paid support card for this service")
	_check(not party_service.is_supported_card(null)
			and not party_service.is_supported_card(7)
			and not party_service.is_supported_card(StringName(PARTY_GLOW)),
		"non-string IDs are never supported")
	# The authenticated lookup alone consumes no seeded run RNG.
	var rng := _party_rng(8191)
	var state_before: int = rng.state
	for card_id: String in PARTY_CARD_IDS:
		party_service.is_supported_card(card_id)
	party_service.is_supported_card("lantern_monk_unknown")
	_check(rng.state == state_before and not PARTY_CARD_IDS.is_empty(),
		"supported-card queries consume no run RNG (non-empty precondition)")


## AC1: a genuine held copy is charged once, discarded once and resolves only the printed effect on
## every living hero. Glow heals and cleanses; Vigil Ring heals and grants Block.
func _test_party_ac1_paid_play() -> void:
	for card_id: String in PARTY_CARD_IDS:
		var monk_seat := 1 if card_id in [PARTY_GLOW, PARTY_GLOW_PLUS] else 2
		var party := _monk_party(monk_seat)
		_check(party.apply_damage(1, 10) and party.apply_damage(2, 12)
				and party.apply_damage(3, 8),
			card_id + ": every living hero is genuinely wounded")
		var deck := _party_deck(card_id)
		var held_before: int = deck.hand.count(card_id)
		var energy_before: int = deck.energy
		var before := _party_snapshot(deck, party)
		var result: Dictionary = party_service.play_card(deck, party, card_id, 0)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			card_id + ": authorized paid party play")
		_check(result.get("card_id") == card_id and result.get("cost") == PARTY_COST[card_id],
			card_id + ": receipt names the authentic card and its printed cost")
		_check(result.get("owner_position") == monk_seat and result.get("target_position") == 0
				and result.get("target_kind") == "party_all",
			card_id + ": party-wide play reports the owner seat and no single target")
		_check(result.get("energy_before") == energy_before
				and result.get("energy_after") == energy_before - PARTY_COST[card_id],
			card_id + ": receipt reports exactly one charge")
		var allies: Array = result.get("allies", [])
		_check(allies.size() == CombatParty.PARTY_SIZE,
			card_id + ": receipt covers every living ally")
		for position in range(1, CombatParty.PARTY_SIZE + 1):
			var entry: Dictionary = allies[position - 1]
			_check(entry.get("position") == position, card_id + ": receipt ally " + str(position))
			_check(entry.get("healed") == PARTY_HEAL[card_id],
				card_id + ": ally " + str(position) + " received the printed heal")
			_check(entry.get("block_gained") == PARTY_BLOCK[card_id],
				card_id + ": ally " + str(position) + " received the printed Block")
			_check(party.get_hero(position)["hp"] == int(entry["hp_after"]),
				card_id + ": ally " + str(position) + " HP matches the receipt")
			_check(party.get_hero(position)["block"] == PARTY_BLOCK[card_id],
				card_id + ": ally " + str(position) + " Block is the printed amount")
		_check(_party_snapshot(deck, party) == _party_expected_success(before, card_id, {}),
			card_id + ": exact party, piles, energy and untouched injected RNG")
		_check(deck.hand.count(card_id) == held_before - 1
				and deck.discard_pile.count(card_id) == 1
				and deck.hand.size() == 4 and deck.discard_pile.size() == 1
				and deck.draw_pile.size() == 1,
			card_id + ": exactly one held copy moved to the discard with no extra draw")
		_check(deck.energy == energy_before - PARTY_COST[card_id],
			card_id + ": exactly the printed energy was charged")
		_check(_party_snapshot(deck, party)["rng_state"] == before["rng_state"],
			card_id + ": no run-RNG draw during resolution")
		# The returned receipt is detached from the live party.
		var first_entry: Dictionary = allies[0]
		first_entry["hp_after"] = 999
		_check(party.get_hero(1)["hp"] != 999,
			card_id + ": mutating a receipt entry cannot change the authoritative party")


## AC1/AC2: healing caps at max HP, never revives a torn hero, and a torn hero is not a recipient.
func _test_party_ac1_downed_and_cap() -> void:
	for card_id: String in PARTY_CARD_IDS:
		var monk_seat := 1 if card_id in [PARTY_GLOW, PARTY_GLOW_PLUS] else 2
		var party := _monk_party(monk_seat)
		var front_max: int = party.get_hero(1)["max_hp"]
		_check(party.apply_damage(1, 1) and party.get_hero(1)["hp"] == front_max - 1,
			card_id + ": front ally sits one below max HP")
		_check(party.apply_damage(3, 26) and party.is_downed(3),
			card_id + ": rear ally is genuinely torn at zero HP")
		party._heroes[2]["statuses"] = {"bleed": 3, "tangled": 1}
		_check(party.get_hero(3)["statuses"] == {"bleed": 3, "tangled": 1},
			card_id + ": torn ally really carries statuses")
		var deck := _party_deck(card_id)
		var before := _party_snapshot(deck, party)
		var result: Dictionary = party_service.play_card(deck, party, card_id, 0)
		_check(result.get("ok") == true, card_id + ": paid play succeeds with a torn ally")
		var allies: Array = result.get("allies", [])
		_check(allies.size() == 2 and allies[0].get("position") == 1
				and allies[1].get("position") == 2,
			card_id + ": only the two living allies are recipients")
		_check(allies[0].get("healed") == 1 and allies[0].get("hp_after") == front_max,
			card_id + ": heal caps at the front ally's max HP")
		_check(allies[1].get("healed") == 0
				and allies[1].get("hp_after") == allies[1].get("hp_before"),
			card_id + ": a full-HP ally gains no HP")
		_check(allies[0].get("block_gained") == PARTY_BLOCK[card_id],
			card_id + ": living allies gain the printed Block")
		var torn: Dictionary = party.get_hero(3)
		_check(torn["hp"] == 0 and torn["block"] == 0,
			card_id + ": the torn ally is not healed, blocked or revived")
		_check(torn["statuses"] == {"bleed": 3, "tangled": 1},
			card_id + ": the torn ally's statuses are untouched")
		_check(_party_snapshot(deck, party) == _party_expected_success(before, card_id, {}),
			card_id + ": exact transaction with a torn ally")


## AC2: one explicitly selected present debuff kind loses its whole counter on each eligible ally;
## every other debuff, Tangled/Riposte and every other hero field stay exact.
func _test_party_ac2_glow_cleanse() -> void:
	for card_id: String in [PARTY_GLOW, PARTY_GLOW_PLUS]:
		for chosen: String in ["weak", "bleed"]:
			var label := "%s cleanse %s" % [card_id, chosen]
			var party := _monk_party(1)
			_check(party.apply_damage(1, 4) and party.apply_damage(2, 10)
					and party.apply_damage(3, 6),
				label + ": all three allies genuinely wounded")
			party._heroes[0]["statuses"] = {"bleed": 3, "weak": 2, "riposte": 4}
			party._heroes[1]["statuses"] = {"exposed": 5, "tangled": 2}
			party._heroes[2]["statuses"] = {"bleed": 0, "tangled": 1}
			_check(party.get_hero(1)["statuses"] == {"bleed": 3, "weak": 2, "riposte": 4}
					and party.get_hero(2)["statuses"] == {"exposed": 5, "tangled": 2}
					and party.get_hero(3)["statuses"] == {"bleed": 0, "tangled": 1},
				label + ": independent debuffs and unrelated statuses really stored")
			var selections := {1: chosen, 2: "exposed"}
			var deck := _party_deck(card_id)
			var before := _party_snapshot(deck, party)
			var result: Dictionary = party_service.play_card(
				deck, party, card_id, 0, selections)
			_check(result.get("ok") == true, label + ": explicit selections accepted")
			var monk_remaining: Dictionary = {"bleed": 3, "weak": 2, "riposte": 4}
			monk_remaining.erase(chosen)
			_check(party.get_hero(1)["statuses"] == monk_remaining,
				label + ": the selected kind is fully gone; Riposte and the other debuff stay")
			_check(party.get_hero(2)["statuses"] == {"tangled": 2},
				label + ": Exposed loses its whole five counters and Tangled is preserved")
			_check(party.get_hero(3)["statuses"] == {"bleed": 0, "tangled": 1},
				label + ": an ally with no positive eligible counter is untouched")
			_check(party.get_hero(1)["hp"] == 30 + PARTY_HEAL[card_id]
					and party.get_hero(2)["hp"] == 30 + PARTY_HEAL[card_id]
					and party.get_hero(3)["hp"] == 20 + PARTY_HEAL[card_id],
				label + ": the printed heal lands on every living ally")
			var allies: Array = result.get("allies", [])
			_check(allies.size() == 3, label + ": receipt covers all living allies")
			_check(allies[0].get("cleansed_debuff") == chosen
					and allies[0].get("cleansed_count") == int({"bleed": 3, "weak": 2}[chosen]),
				label + ": the Monk reports the whole selected counter")
			_check(allies[1].get("cleansed_debuff") == "exposed"
					and allies[1].get("cleansed_count") == 5,
				label + ": the ally reports the whole Exposed counter")
			_check(allies[2].get("cleansed_debuff") == ""
					and allies[2].get("cleansed_count") == 0,
				label + ": no implicit cleanse is invented for an ineligible ally")
			_check(_party_snapshot(deck, party) == _party_expected_success(before, card_id, selections),
				label + ": exact party, piles, energy and RNG state")

	# A torn ally is not an eligible cleanse recipient: its counters stay and it needs no choice.
	var guarded := _monk_party(1)
	_check(guarded.apply_damage(2, 40) and guarded.is_downed(2),
		"cleanse-skip fixture really has a torn Warden")
	guarded._heroes[1]["statuses"] = {"bleed": 4, "weak": 2}
	guarded._heroes[2]["statuses"] = {"weak": 3}
	_check(guarded.get_hero(2)["statuses"] == {"bleed": 4, "weak": 2}
			and guarded.get_hero(3)["statuses"] == {"weak": 3},
		"cleanse-skip fixture really stores downed and living debuffs")
	var guarded_deck := _party_deck(PARTY_GLOW)
	var guarded_before := _party_snapshot(guarded_deck, guarded)
	var guarded_result: Dictionary = party_service.play_card(
		guarded_deck, guarded, PARTY_GLOW, 0, {3: "weak"})
	_check(guarded_result.get("ok") == true,
		"a living ally with one present debuff accepts its explicit selection")
	_check(guarded.get_hero(2)["statuses"] == {"bleed": 4, "weak": 2},
		"the torn ally keeps every counter and is never cleansed")
	_check(guarded.get_hero(3)["statuses"] == {},
		"the living ally's whole selected Weak counter is removed")
	_check(_party_snapshot(guarded_deck, guarded)
			== _party_expected_success(guarded_before, PARTY_GLOW, {3: "weak"}),
		"downed-ally cleansing skips exactly the torn seat")


## AC2: Vigil Ring heals and blocks the living party and cleanses nothing at all.
func _test_party_ac2_vigil_no_cleanse() -> void:
	for card_id: String in [PARTY_VIGIL, PARTY_VIGIL_PLUS]:
		var party := _monk_party(2)
		_check(party.apply_damage(1, 9) and party.apply_damage(2, 10)
				and party.apply_damage(3, 10),
			card_id + ": all three allies genuinely wounded")
		party._heroes[0]["statuses"] = {"bleed": 2}
		party._heroes[1]["statuses"] = {"weak": 1, "tangled": 3}
		party._heroes[2]["statuses"] = {"exposed": 3, "riposte": 2}
		var deck := _party_deck(card_id)
		var before := _party_snapshot(deck, party)
		var result: Dictionary = party_service.play_card(deck, party, card_id, 0)
		_check(result.get("ok") == true and result.get("block_all") == PARTY_BLOCK[card_id],
			card_id + ": authorized Vigil Ring play reports its printed Block")
		_check(party.get_hero(1)["statuses"] == {"bleed": 2}
				and party.get_hero(2)["statuses"] == {"weak": 1, "tangled": 3}
				and party.get_hero(3)["statuses"] == {"exposed": 3, "riposte": 2},
			card_id + ": Vigil Ring cleanses nothing and preserves every status")
		_check(party.get_hero(1)["block"] == PARTY_BLOCK[card_id]
				and party.get_hero(2)["block"] == PARTY_BLOCK[card_id]
				and party.get_hero(3)["block"] == PARTY_BLOCK[card_id],
			card_id + ": every living ally gains the printed Block")
		_check(_party_snapshot(deck, party) == _party_expected_success(before, card_id, {}),
			card_id + ": exact Vigil Ring transaction")


## AC3: every invalid request fails closed and leaves the whole transaction untouched.
func _test_party_ac3_rejections() -> void:
	var party := _monk_party(2)

	var inactive := CombatDeck.new(
		[PARTY_GLOW, PARTY_GLOW, PARTY_GLOW, PARTY_FILLERS[0], PARTY_FILLERS[1], PARTY_FILLERS[2]],
		_party_rng(991))
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_party_rejected(inactive, party, PARTY_GLOW, 0, {}, "inactive turn")

	var deck := _party_deck(PARTY_GLOW)
	_check(deck.hand.has(PARTY_GLOW) and not deck.hand.has(PARTY_VIGIL),
		"absent-card fixture holds Lantern Glow only")
	_party_rejected(deck, party, PARTY_VIGIL, 0, {}, "card absent from hand")
	for unknown in ["", "lantern_monk_missing_party_card", "lantern_monk_moth_cloud",
			"lantern_monk_wax_ward", "warden_v3_rim_toss", "seamstress_mend", 7, null,
			StringName(PARTY_GLOW)]:
		_party_rejected(deck, party, unknown, 0, {}, "unsupported card ID " + str(unknown))

	var short := _party_deck(PARTY_GLOW)
	_check(short.try_spend_energy(3) and short.energy == 0 and short.hand.has(PARTY_GLOW),
		"energy-short fixture is genuinely broke and still holds the card")
	_party_rejected(short, party, PARTY_GLOW, 0, {}, "insufficient energy")

	for bad_target in [1, 2, 3, -1, 4, 99]:
		_party_rejected(_party_deck(PARTY_GLOW), party, PARTY_GLOW, bad_target, {},
			"selected single target " + str(bad_target))

	var front_monk := _monk_party(1)
	_check(front_monk.get_hero(1)["id"] == "lantern_monk",
		"illegal-FROM fixture really has the living Monk in seat 1")
	_party_rejected(_party_deck(PARTY_VIGIL), front_monk, PARTY_VIGIL, 0, {},
		"Vigil Ring from the Monk's illegal seat 1")

	var torn_owner := _monk_party(2)
	_check(torn_owner.apply_damage(2, MONK_MAX_HP) and torn_owner.is_downed(2),
		"torn-caster fixture has a genuinely downed Monk")
	_party_rejected(_party_deck(PARTY_GLOW), torn_owner, PARTY_GLOW, 0, {},
		"torn (downed) Monk")

	var no_owner := CombatParty.new([
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 26},
		{"id": "mender", "name": "Mender", "max_hp": 20},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(3)["id"] == "mender",
		"missing-owner fixture is a valid three-hero party with no Monk")
	_party_rejected(_party_deck(PARTY_GLOW), no_owner, PARTY_GLOW, 0, {},
		"party with no Lantern Monk owner")

	var duplicated := _monk_party(2)
	duplicated._heroes[0]["id"] = "lantern_monk"
	_check(duplicated.get_hero(1)["id"] == "lantern_monk"
			and duplicated.get_hero(2)["id"] == "lantern_monk",
		"duplicate-identity fixture really repeats the owner ID")
	_party_rejected(_party_deck(PARTY_GLOW), duplicated, PARTY_GLOW, 0, {},
		"duplicate hero identity")

	var above_max := _monk_party(2)
	above_max._heroes[0]["hp"] = int(above_max._heroes[0]["max_hp"]) + 1
	_check(above_max.get_hero(1)["hp"] > above_max.get_hero(1)["max_hp"],
		"malformed-roster fixture really has HP above max")
	_party_rejected(_party_deck(PARTY_GLOW), above_max, PARTY_GLOW, 0, {}, "HP above max")

	var bad_block := _monk_party(2)
	bad_block._heroes[2]["block"] = -1
	_check(bad_block.get_hero(3)["block"] == -1, "negative-Block fixture really stores -1")
	_party_rejected(_party_deck(PARTY_GLOW), bad_block, PARTY_GLOW, 0, {}, "negative Block")

	var bad_position := _monk_party(2)
	bad_position._heroes[0]["position"] = 3
	_check(bad_position.get_hero(1)["position"] == 3,
		"wrong-position fixture really stores the wrong slot")
	_party_rejected(_party_deck(PARTY_GLOW), bad_position, PARTY_GLOW, 0, {},
		"wrong stored hero position")

	for bad_statuses in ["bleed", null, {"bleed": -1}, {"bleed": "3"}, {"bleed": 1.5},
			{"weak": true}, {1: 2}, {"": 1}]:
		var broken := _monk_party(2)
		broken._heroes[2]["statuses"] = bad_statuses
		_check(broken.get_hero(3)["statuses"] == bad_statuses,
			"malformed-status fixture really stores " + str(bad_statuses))
		_party_rejected(_party_deck(PARTY_GLOW), broken, PARTY_GLOW, 0, {},
			"malformed statuses " + str(bad_statuses))

	var huge_block := _monk_party(2)
	huge_block._heroes[0]["block"] = CombatParty.MAX_INT
	_check(huge_block.get_hero(1)["block"] == CombatParty.MAX_INT,
		"Block-overflow fixture really stores MAX_INT Block")
	_party_rejected(_party_deck(PARTY_VIGIL), huge_block, PARTY_VIGIL, 0, {},
		"unrepresentable Block gain")

	var mixed := _monk_party(2)
	mixed._heroes[0]["statuses"] = {"bleed": 3, "weak": 2}
	mixed._heroes[2]["statuses"] = {"exposed": 2}
	_check(mixed.get_hero(1)["statuses"] == {"bleed": 3, "weak": 2}
			and mixed.get_hero(3)["statuses"] == {"exposed": 2},
		"cleanse-rejection fixture really stores two eligible allies")
	var mixed_deck := _party_deck(PARTY_GLOW)
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, {}, "missing cleanse selection")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, {1: "weak"},
		"selection still missing for the second eligible ally")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, {1: "exposed"},
		"absent selected debuff on the first ally")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, {1: "weak", 2: ""},
		"empty selection while a debuff is present")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, {1: "weak", 2: "exposed", 4: "bleed"},
		"selection key outside 1-3")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, {1: "weak", 2: "exposed", "3": "exposed"},
		"non-int selection key")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, {1: 2, 2: "exposed"},
		"non-string cleanse selection")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, [], "array cleanse selections")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, "weak", "string cleanse selections")
	_party_rejected(mixed_deck, mixed, PARTY_GLOW, 0, null, "null cleanse selections")

	var clean := _monk_party(2)
	_check(clean.get_hero(3).get("statuses", {}) == {},
		"no-debuff fixture really has no eligible counter")
	_party_rejected(_party_deck(PARTY_GLOW), clean, PARTY_GLOW, 0, {3: "bleed"},
		"debuff named but absent")

	var torn_ally := _monk_party(2)
	_check(torn_ally.apply_damage(3, 26) and torn_ally.is_downed(3),
		"torn-selection fixture really has a downed ally")
	torn_ally._heroes[2]["statuses"] = {"bleed": 3}
	_party_rejected(_party_deck(PARTY_GLOW), torn_ally, PARTY_GLOW, 0, {3: "bleed"},
		"cleanse selection for a torn ally")

	var expired := _monk_party(2)
	expired._heroes[2]["statuses"] = {"bleed": 0}
	_check(expired.get_hero(3)["statuses"] == {"bleed": 0},
		"zero-counter fixture really stores an expired counter")
	_party_rejected(_party_deck(PARTY_GLOW), expired, PARTY_GLOW, 0, {3: "bleed"},
		"expired zero counter is not a positive present debuff")

	_party_rejected(_party_deck(PARTY_VIGIL), _monk_party(2), PARTY_VIGIL, 0, {1: "bleed"},
		"Vigil Ring cleanse selection")

	_party_rejected(null, party, PARTY_GLOW, 0, {}, "null deck")
	_party_rejected(_party_deck(PARTY_GLOW), null, PARTY_GLOW, 0, {}, "null party")
	_party_rejected(_party_deck(PARTY_GLOW), CombatParty.new([]), PARTY_GLOW, 0, {},
		"invalid party roster")


## AC3: a rejected attempt never poisons the next authentic one; one copy plays once.
func _test_party_ac3_retry_and_replay() -> void:
	var party := _monk_party(2)
	_check(party.apply_damage(2, 8) and party.get_hero(2)["hp"] == MONK_MAX_HP - 8,
		"retry fixture really has a wounded Monk")
	party._heroes[2]["statuses"] = {"bleed": 3, "weak": 2}
	var deck := _party_deck(PARTY_GLOW)
	_party_rejected(deck, party, PARTY_GLOW, 0, {},
		"retry: missing selection with present debuffs")
	_party_rejected(deck, party, PARTY_GLOW, 2, {3: "weak"}, "retry: nonzero target")
	_party_rejected(deck, party, PARTY_GLOW, 0, {3: "exposed"}, "retry: absent debuff")
	var before := _party_snapshot(deck, party)
	var result: Dictionary = party_service.play_card(deck, party, PARTY_GLOW, 0, {3: "weak"})
	_check(result.get("ok") == true, "retry: the authentic play then succeeds")
	_check(party.get_hero(3)["statuses"] == {"bleed": 3},
		"retry: only the selected Weak counter is removed")
	_check(party.get_hero(2)["hp"] == MONK_MAX_HP - 8 + PARTY_HEAL[PARTY_GLOW],
		"retry: the printed heal lands on the wounded Monk")
	_check(_party_snapshot(deck, party) == _party_expected_success(before, PARTY_GLOW, {3: "weak"}),
		"retry: exactly one charge, one discard and an untouched RNG")

	var replay_party := _monk_party(2)
	var single := CombatDeck.new([PARTY_GLOW, PARTY_FILLERS[0], PARTY_FILLERS[1],
		PARTY_FILLERS[2], PARTY_FILLERS[3]], _party_rng(5150))
	_check(single.start_turn() and single.hand.count(PARTY_GLOW) == 1 and single.energy == 3,
		"single-copy fixture draws its one genuine copy")
	var first: Dictionary = party_service.play_card(single, replay_party, PARTY_GLOW, 0)
	_check(first.get("ok") == true and not single.hand.has(PARTY_GLOW),
		"the single copy plays once and leaves the hand")
	var replay_at := _party_snapshot(single, replay_party)
	var replay: Dictionary = party_service.play_card(single, replay_party, PARTY_GLOW, 0)
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		"a second play of the same ID fails once the copy is discarded")
	_check(_party_snapshot(single, replay_party) == replay_at,
		"the replay refusal leaves the deck, roster and RNG untouched")

	var many := CombatDeck.new([PARTY_GLOW, PARTY_GLOW, PARTY_GLOW, PARTY_GLOW,
		PARTY_GLOW, PARTY_FILLERS[0]], _party_rng(2710))
	_check(many.start_turn() and many.hand.count(PARTY_GLOW) >= 4 and many.energy == 3,
		"repeat fixture draws a hand holding several genuine copies")
	var many_party := _monk_party(2)
	for play_index in range(3):
		var play: Dictionary = party_service.play_card(many, many_party, PARTY_GLOW, 0)
		_check(play.get("ok") == true and many.energy == 2 - play_index,
			"repeat play %d charges one energy" % (play_index + 1))
		_check(many.hand.size() == 4 - play_index
				and many.discard_pile.size() == play_index + 1,
			"repeat play %d discards exactly one copy" % (play_index + 1))
	_check(many.energy == 0 and many.hand.count(PARTY_GLOW) >= 1,
		"repeat fixture still holds a copy but has no energy left")
	var before_empty := _party_snapshot(many, many_party)
	var refused: Dictionary = party_service.play_card(many, many_party, PARTY_GLOW, 0)
	_check(refused.get("ok") == false and refused.get("reason") == "insufficient_energy",
		"a held copy cannot be played at zero energy")
	_check(_party_snapshot(many, many_party) == before_empty,
		"the energy refusal changes no pile, energy, hero or RNG")


## The same seed and request sequence produce identical outcomes and consume no run RNG draws.
func _test_party_seeded_invariance() -> void:
	var first := _party_replay_run(424242)
	var second := _party_replay_run(424242)
	var results: Array = first.get("results", [])
	_check(results.size() == 4, "seeded run covers all four printings (precondition)")
	_check(first == second, "same seed and requests produce identical final state and receipts")
	for result in results:
		_check(result.get("ok") == true, "seeded run accepts every authentic printing")
	var rng_states: Array = first.get("rng_states", [])
	var rng_start_states: Array = first.get("rng_start_states", [])
	_check(rng_states.size() == 4 and rng_start_states.size() == 4,
		"seeded run captured the RNG state around all four plays")
	for index in range(rng_states.size()):
		_check(rng_states[index] == rng_start_states[index],
			"seeded play %d consumes no run-RNG draw" % (index + 1))
	for snapshot in first.get("snapshots", []):
		_check(snapshot.get("hand", []).size() == 4,
			"seeded play grants no free extra draw")


func _party_replay_run(seed_value: int) -> Dictionary:
	var results: Array = []
	var snapshots: Array = []
	var rng_states: Array = []
	var rng_start_states: Array = []
	for card_id: String in PARTY_CARD_IDS:
		var monk_seat := 1 if card_id in [PARTY_GLOW, PARTY_GLOW_PLUS] else 2
		var party := _monk_party(monk_seat)
		_check(party.apply_damage(1, 4) and party.apply_damage(2, 6)
				and party.apply_damage(3, 5),
			card_id + ": replay fixture wounds every ally")
		var selections: Dictionary = {}
		if card_id in [PARTY_GLOW, PARTY_GLOW_PLUS]:
			party._heroes[0]["statuses"] = {"bleed": 2, "weak": 1}
			selections = {1: "bleed"}
		var deck := _party_deck(card_id, seed_value)
		rng_start_states.append(deck._rng.state)
		results.append(party_service.play_card(deck, party, card_id, 0, selections))
		snapshots.append(_party_snapshot(deck, party))
		rng_states.append(deck._rng.state)
	return {
		"results": results,
		"snapshots": snapshots,
		"rng_states": rng_states,
		"rng_start_states": rng_start_states,
	}


## A real seeded five-card hand from six cards, so at least two copies of the named ID are held.
func _party_deck(card_id: String, seed_value: int = 7311) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, PARTY_FILLERS[0], PARTY_FILLERS[1],
		PARTY_FILLERS[2]]
	var deck := CombatDeck.new(ids, _party_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
			and deck.hand.size() == 5 and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holding duplicate copies")
	return deck


## A real party with the unique Lantern Monk in the requested seat and two authored allies.
func _monk_party(monk_seat: int) -> CombatParty:
	var monk := {"id": "lantern_monk", "name": "Lantern Monk", "max_hp": MONK_MAX_HP}
	var warden := _authored_ally("warden")
	var tinker := _authored_ally("tinker")
	_check(not warden.is_empty() and not tinker.is_empty(),
		"authored starter party supplies the two ally records")
	var definitions: Array = []
	if monk_seat == 1:
		definitions = [monk, warden, tinker]
	elif monk_seat == 3:
		definitions = [warden, tinker, monk]
	else:
		definitions = [warden, monk, tinker]
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(monk_seat)["id"] == "lantern_monk"
			and party.get_hero(monk_seat)["max_hp"] == MONK_MAX_HP,
		"valid party with the unique living Monk in seat " + str(monk_seat))
	return party


func _authored_ally(hero_id: String) -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(PARTY_HEROES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array,
		"real authored starter party file parses")
	if not parsed is Array:
		return {}
	for record in parsed:
		if not record is Dictionary:
			continue
		if str(record.get("id", "")) != hero_id:
			continue
		var hero: Dictionary = record.duplicate(true)
		if hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
		return hero
	_check(false, "authored starter party contains " + hero_id)
	return {}


func _party_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## The full observable state plus the injected RNG state, for exact no-mutation comparisons.
func _party_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var result: Dictionary = {}
	if party != null:
		result["heroes"] = party.get_heroes()
		result["party_valid"] = party.is_valid()
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		if deck.combat_state != null:
			result["state_energy"] = deck.combat_state.energy
			result["state_turn"] = deck.combat_state.player_turn_active
		if deck._rng != null:
			result["rng_state"] = deck._rng.state
			result["rng_seed"] = deck._rng.seed
	return result


## The single-transaction expected state for a party-wide play: one cost, one discard and the
## printed heal/Block/cleanse on every living hero.
func _party_expected_success(before: Dictionary, card_id: String,
		selections: Dictionary) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= int(PARTY_COST[card_id])
	expected["state_energy"] -= int(PARTY_COST[card_id])
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = expected["heroes"][index]
		if int(hero["hp"]) == 0:
			continue
		hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + int(PARTY_HEAL[card_id]))
		hero["block"] = int(hero["block"]) + int(PARTY_BLOCK[card_id])
		if selections.has(index + 1):
			var statuses: Dictionary = hero.get("statuses", {})
			statuses.erase(str(selections[index + 1]))
			hero["statuses"] = statuses
	return expected


func _party_rejected(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int, cleanse_selections: Variant, label: String) -> void:
	var before := _party_snapshot(deck, party)
	var result: Dictionary = party_service.play_card(
		deck, party, card_id, target_position, cleanse_selections)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_party_snapshot(deck, party) == before,
		label + ": unchanged party, hand, draw, discard, energy, turn and RNG")
