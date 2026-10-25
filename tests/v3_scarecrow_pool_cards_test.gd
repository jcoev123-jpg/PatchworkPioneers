extends SceneTree
## V3-1 Scarecrow catalog contract. Printed descriptors only: nothing here proves the abilities
## already resolve in live combat, the shared hand, rewards or the starter deck.

const ScriptClass = preload("res://data/cards/scarecrow_pool_cards.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_rarity_distribution()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_starters_unchanged()
	_test_rng_state()
	if failures.is_empty():
		print("v3_scarecrow_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_scarecrow_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"scarecrow_pitchfork_prick": {
			"name": "Pitchfork Prick", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 5, "bleed": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 7, "bleed": 2}},
		"scarecrow_crow_peck": {
			"name": "Crow Peck", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_back", "to": [1, 2, 3],
			"effects": {"damage": 4, "ignore_block": true}, "plus_cost": 1,
			"plus_effects": {"damage": 6, "ignore_block": true}},
		"scarecrow_sack_grin": {
			"name": "Sack Grin", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"weak": 1, "cannot_buff_next_turn": true}, "plus_cost": 1,
			"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
		"scarecrow_straw_wrap": {
			"name": "Straw Wrap", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 6, "draw": 1}, "plus_cost": 1,
			"plus_effects": {"block": 8, "draw": 1}},
		"scarecrow_crow_flock": {
			"name": "Crow Flock", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"weak": 1, "cannot_buff_next_turn": true}, "plus_cost": 2,
			"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
		"scarecrow_re_stuff": {
			"name": "Re-Stuff", "rarity": "uncommon", "cost": 2,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"max_hp_loss": 2, "heal": 10}, "plus_cost": 2,
			"plus_effects": {"max_hp_loss": 2, "heal": 13}},
		"scarecrow_pitchfork_hook": {
			"name": "Pitchfork Hook", "rarity": "uncommon", "cost": 2,
			"from": [1, 2], "target": "enemy_single", "to": [2, 3],
			"effects": {"damage": 7, "pull_forward": 1}, "plus_cost": 2,
			"plus_effects": {"damage": 10, "pull_forward": 1}},
		"scarecrow_harvest_fright": {
			"name": "Harvest Fright", "rarity": "rare", "cost": 3,
			"from": [1, 2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage": 4, "weak": 2, "cannot_buff_next_turn": true},
			"plus_cost": 3,
			"plus_effects": {"damage": 6, "weak": 3, "cannot_buff_next_turn": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "scarecrow",
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
		_check(base_id.begins_with("scarecrow_"), base_id + " uses the Scarecrow ID prefix")
		_check(plus_id == base_id + "_plus", base_id + " upgrade ID is its base ID plus _plus")
		_check(base_ids.has(base_id), base_id + " is listed as a base")
		_check(base_ids.count(base_id) == 1, base_id + " has one base-list occurrence")
		_check(not base_ids.has(plus_id), plus_id + " is never a base candidate")
		_check(all_ids.has(base_id) and all_ids.has(plus_id), base_id + " both IDs discoverable")
		_check(all_ids.count(base_id) == 1 and all_ids.count(plus_id) == 1,
			base_id + " base and upgrade each appear once in the ID listing")
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
			_check(record.get("owner") == "scarecrow", card_id + " is Scarecrow-owned")
			_check(record.get("starting_copies") == 0, card_id + " is never a starter copy")
			_check(record.get("reward_eligible") == not upgraded,
				card_id + " reward eligibility matches its base/plus role")
			_check(String(record.get("illustration_path")).ends_with("/" + base_id + ".png"),
				card_id + " points at the shared base art path")
		_check(base_id != plus_id, base_id + " upgrade has a distinct stable ID")
		_check(catalog.get_definition(plus_id).get("upgrade_of") == base_id,
			plus_id + " records its base card")
		_check(not catalog.get_definition(base_id).has("upgrade_of"),
			base_id + " is not itself an upgrade")


func _test_rarity_distribution() -> void:
	var cases: Dictionary = _cases()
	var counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	for base_id: String in cases:
		counts[cases[base_id]["rarity"]] += 1
	_check(counts["common"] == 4, "four authored commons")
	_check(counts["uncommon"] == 3, "three authored uncommons")
	_check(counts["rare"] == 1, "one authored rare")


## The five signature mechanics, as authored metadata only (never as live combat behavior).
func _test_special_descriptors() -> void:
	var catalog = ScriptClass.new()

	var peck: Dictionary = catalog.get_definition("scarecrow_crow_peck")
	var peck_plus: Dictionary = catalog.get_definition("scarecrow_crow_peck_plus")
	_check(not peck.is_empty() and not peck_plus.is_empty(), "Crow Peck fixture loaded")
	_check(peck.get("target_kind") == "enemy_back" and peck_plus.get("target_kind") == "enemy_back",
		"Crow Peck targets the backmost living enemy, not a fixed position")
	_check(peck.get("effects") == {"damage": 4, "ignore_block": true}
			and peck_plus.get("effects") == {"damage": 6, "ignore_block": true},
		"Crow Peck carries Block-bypassing damage on base and plus")
	_check(peck.get("from_positions") == [1, 2, 3] and peck_plus.get("from_positions") == [1, 2, 3],
		"Crow Peck is usable from every hero position")
	_check(peck.get("to_positions") == [1, 2, 3] and peck_plus.get("to_positions") == [1, 2, 3],
		"Crow Peck keeps its position/target pair after upgrade")

	for base_id: String in ["scarecrow_sack_grin", "scarecrow_crow_flock",
			"scarecrow_harvest_fright"]:
		for upgraded: bool in [false, true]:
			var card_id: String = base_id + ("_plus" if upgraded else "")
			var record: Dictionary = catalog.get_definition(card_id)
			var effects: Dictionary = record.get("effects", {})
			_check(effects.get("cannot_buff_next_turn") == true,
				card_id + " carries Fear's buff lock")
			_check(typeof(effects.get("cannot_buff_next_turn")) == TYPE_BOOL,
				card_id + " expresses the buff lock as one-turn metadata, not a duration counter")
			_check(effects.has("weak"), card_id + " carries Fear's Weak")
	var sack: Dictionary = catalog.get_definition("scarecrow_sack_grin")
	var sack_plus: Dictionary = catalog.get_definition("scarecrow_sack_grin_plus")
	_check((sack.get("effects") as Dictionary).get("weak") == 1
			and (sack_plus.get("effects") as Dictionary).get("weak") == 2,
		"Sack Grin+ raises only Weak")
	var flock: Dictionary = catalog.get_definition("scarecrow_crow_flock")
	_check(flock.get("target_kind") == "enemy_all" and flock.get("to_positions") == [1, 2, 3],
		"Crow Flock applies Fear to every enemy")
	var fright_plus: Dictionary = catalog.get_definition("scarecrow_harvest_fright_plus")
	_check(fright_plus.get("effects") == {"damage": 6, "weak": 3, "cannot_buff_next_turn": true},
		"Harvest Fright+ scales damage and Weak but locks buffs for the same single turn")

	var re_stuff: Dictionary = catalog.get_definition("scarecrow_re_stuff")
	var re_stuff_plus: Dictionary = catalog.get_definition("scarecrow_re_stuff_plus")
	_check(re_stuff.get("target_kind") == "self" and re_stuff.get("to_positions") == [],
		"Re-Stuff targets only the acting Scarecrow")
	_check(re_stuff.get("effects") == {"max_hp_loss": 2, "heal": 10}
			and re_stuff_plus.get("effects") == {"max_hp_loss": 2, "heal": 13},
		"Re-Stuff trades 2 max HP for a heal, and the max-HP cost never scales")
	_check((re_stuff_plus.get("effects") as Dictionary).get("max_hp_loss") == 2,
		"Re-Stuff+ keeps the permanent 2 max-HP cost")

	var hook: Dictionary = catalog.get_definition("scarecrow_pitchfork_hook")
	var hook_plus: Dictionary = catalog.get_definition("scarecrow_pitchfork_hook_plus")
	_check(hook.get("target_kind") == "enemy_single" and hook.get("from_positions") == [1, 2],
		"Pitchfork Hook is a front/middle enemy attack")
	_check(hook.get("to_positions") == [2, 3] and hook_plus.get("to_positions") == [2, 3],
		"Pitchfork Hook can only hook an enemy that has room in front of it")
	_check((hook.get("effects") as Dictionary).get("pull_forward") == 1
			and (hook_plus.get("effects") as Dictionary).get("pull_forward") == 1,
		"Pitchfork Hook pulls exactly one position, unscaled by the upgrade")
	_check(hook.get("effects") == {"damage": 7, "pull_forward": 1}
			and hook_plus.get("effects") == {"damage": 10, "pull_forward": 1},
		"Pitchfork Hook+ raises only its damage")


func _test_detached_results() -> void:
	var catalog = ScriptClass.new()
	var sample: Dictionary = catalog.get_definition("scarecrow_pitchfork_prick")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("scarecrow_pitchfork_prick")
	_check(pristine.get("effects") == {"damage": 5, "bleed": 1},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [1, 2],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "scarecrow_pitchfork_prick", "metadata is detached")

	var upgraded: Dictionary = catalog.get_definition("scarecrow_straw_wrap_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("scarecrow_straw_wrap_plus").get("effects") == {"block": 8, "draw": 1},
		"upgrade effects are detached")
	_check(catalog.get_definition("scarecrow_straw_wrap_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("scarecrow_straw_wrap_plus").get("to_positions") == [],
		"empty upgrade TO is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("scarecrow_straw_wrap") and all_ids.has("scarecrow_straw_wrap_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("scarecrow_straw_wrap"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("scarecrow_straw_wrap_plus"), "all-ID array is a fresh copy")
	_check(ScriptClass.new().get_definition("scarecrow_pitchfork_prick").get("effects") == pristine.get("effects"),
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog = ScriptClass.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("scarecrow_crow_peck"),
		"", "scarecrow_not_a_card", "crow_peck", "scarecrow_crow_peck+",
		"scarecrow_crow_peck_plus_plus", "SCARECROW_CROW_PECK", " scarecrow_crow_peck"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_starters_unchanged() -> void:
	var starter := StarterCards.new()
	var pool = ScriptClass.new()
	var deck: Array[String] = starter.get_starting_deck()
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "authored starter_deck.json parses as array")
	if not parsed is Array:
		return
	_check(deck.has("warden_strike") and deck.has("tinker_pop_shot"),
		"StarterCards still builds a populated starting deck")
	# Named starters of the three live heroes only: the roster and its totals may grow later.
	var expected_starters: Dictionary = {
		"warden_strike": {"owner": "warden", "count": 2, "effects": {"damage": 6}},
		"warden_brace": {"owner": "warden", "count": 1, "effects": {"block": 7}},
		"warden_shield_bash": {"owner": "warden", "count": 1, "effects": {"damage": 8, "weak": 1}},
		"seamstress_prick": {"owner": "seamstress", "count": 2, "effects": {"damage": 3, "bleed": 2}},
		"seamstress_mend": {"owner": "seamstress", "count": 1, "effects": {"heal": 5}},
		"seamstress_stitch_up": {"owner": "seamstress", "count": 1, "effects": {"block": 5}},
		"tinker_pop_shot": {"owner": "tinker", "count": 2, "effects": {"damage": 5}},
		"tinker_scrap_bomb": {"owner": "tinker", "count": 1, "effects": {"damage": 4}},
		"tinker_tune_up": {"owner": "tinker", "count": 1, "effects": {"draw": 1}},
	}
	for id: String in expected_starters:
		var starter_record: Dictionary = starter.get_definition(id)
		_check(not starter_record.is_empty(), id + " remains a StarterCards definition")
		_check(starter_record.get("owner") == expected_starters[id]["owner"],
			id + " remains owned by its live hero")
		_check(starter_record.get("effects") == expected_starters[id]["effects"],
			id + " printed effects unchanged")
		_check(starter_record.get("starting_copies") == expected_starters[id]["count"],
			id + " catalog multiplicity unchanged")
		_check(deck.count(id) == expected_starters[id]["count"], id + " runtime deck copies unchanged")
		_check(parsed.count(id) == expected_starters[id]["count"], id + " JSON deck copies unchanged")
	_check(not starter.has_card("scarecrow_crow_peck"),
		"Scarecrow pool cards have not entered StarterCards")
	for id: String in pool.get_all_card_ids():
		_check(not starter.has_card(id), id + " is not a starter definition")
		_check(not deck.has(id), id + " is absent from the runtime starter deck")
		_check(not parsed.has(id), id + " is absent from the authored starter deck")


func _test_rng_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var initial_state: int = rng.state
	var catalog = ScriptClass.new()
	var ids: Array[String] = catalog.get_all_card_ids()
	for id: String in ids:
		var definition: Dictionary = catalog.get_definition(id)
		_check(not definition.is_empty(), id + " resolves while enumerating")
	catalog.get_base_ids()
	catalog.has_card("scarecrow_crow_peck")
	catalog.get_upgrade_id("scarecrow_crow_peck")
	catalog.get_definition("unknown_scarecrow_card")
	_check(rng.state == initial_state, "constructing and enumerating the catalog consumes no run RNG")
