extends SceneTree
## V3-1 Scarecrow dedicated starter-card catalog contract.
## Catalog data only: no live party admission, shared hand, reward offer or combat effect resolution is
## assumed or claimed here. The existing ScarecrowPoolCards registry stays reward-only.

const ScarecrowStarterCards = preload("res://data/cards/scarecrow_starter_cards.gd")
const ScarecrowPoolCards = preload("res://data/cards/scarecrow_pool_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_each_base_and_upgrade()
	_test_look_descriptors()
	_test_starter_projection()
	_test_detached_records()
	_test_invalid_and_upgraded_ids()
	_test_deterministic_and_rng_free()
	_test_existing_catalogs_unchanged()
	if failures.is_empty():
		print("v3_scarecrow_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_scarecrow_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Literal, independent expectations for each of the four authored base/"+" pairs.
func _cases() -> Dictionary:
	return {
		"scarecrow_fork_jab": {
			"name": "Fork Jab", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 4, "bleed": 1},
			"plus_cost": 1, "plus_effects": {"damage": 6, "bleed": 2}},
		"scarecrow_sack_glare": {
			"name": "Sack Glare", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"weak": 1, "cannot_buff_next_turn": true},
			"plus_cost": 1,
			"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
		"scarecrow_crow_dive": {
			"name": "Crow Dive", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_back", "to": [1, 2, 3],
			"effects": {"damage": 3, "ignore_block": true},
			"plus_cost": 1, "plus_effects": {"damage": 5, "ignore_block": true}},
		"scarecrow_straw_padding": {
			"name": "Straw Padding", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 4, "draw": 1},
			"plus_cost": 1, "plus_effects": {"block": 6, "draw": 1}},
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
		"starting_copies": 0 if upgraded else 1,
		"reward_eligible": false,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


func _test_each_base_and_upgrade() -> void:
	var catalog := ScarecrowStarterCards.new()
	var cases: Dictionary = _cases()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen: Dictionary = {}
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id), base_id + " is a distinct base identifier")
		seen[base_id] = true
		_check(not seen.has(plus_id), plus_id + " is a distinct upgrade identifier")
		seen[plus_id] = true
		_check(base_id.begins_with("scarecrow_"), base_id + " uses the Scarecrow ID prefix")
		_check(all_ids.count(base_id) == 1, base_id + " appears exactly once in the ID listing")
		_check(all_ids.count(plus_id) == 1, plus_id + " appears exactly once in the ID listing")
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id),
			base_id + " base and upgrade both exist")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + "_plus is not authored")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			if record.is_empty():
				continue
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has an effect dictionary")
			_check(record.get("owner") == "scarecrow", card_id + " is Scarecrow-owned")
			_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
				and record.get("reward_eligible") == false, card_id + " is never reward eligible")
			_check(not record.has("rarity"), card_id + " carries no reward rarity")
			_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
				card_id + " shares its base illustration path")
			var effects: Dictionary = record.get("effects")
			_check(effects.size() == (expected["effects"] as Dictionary).size(),
				card_id + " prints exactly the documented effects")
		_check(catalog.get_definition(base_id).get("starting_copies") == 1,
			base_id + " starts with one copy")
		_check(catalog.get_definition(plus_id).get("starting_copies") == 0,
			plus_id + " adds no starting copy")
		_check(not catalog.get_definition(base_id).has("upgrade_of"),
			base_id + " is not itself an upgrade")
		_check(not catalog.get_definition(plus_id).has("upgrade_id"),
			plus_id + " has no onward upgrade link")
		_check(catalog.get_definition(plus_id).get("upgrade_of") == base_id,
			plus_id + " points back to its base")
		_check(catalog.get_definition(base_id).get("illustration_path")
			== catalog.get_definition(plus_id).get("illustration_path"),
			base_id + " base and upgrade share one illustration path")


## The printed look descriptors: pitchfork Bleed, Fear's Weak plus one-turn buff lock,
## the crow's Block-bypassing back-row hit, and straw's Block plus a single shared-hand draw.
func _test_look_descriptors() -> void:
	var catalog := ScarecrowStarterCards.new()
	for suffix: String in ["", "_plus"]:
		var fork: Dictionary = catalog.get_definition("scarecrow_fork_jab" + suffix)
		_check(fork.get("target_kind") == "enemy_single",
			"Fork Jab targets one enemy" + suffix)
		_check(fork.get("from_positions") == [1, 2] and fork.get("to_positions") == [1, 2],
			"Fork Jab reaches the front two enemy slots from the front two hero slots" + suffix)
		var fork_effects: Dictionary = fork.get("effects", {})
		_check(fork_effects.has("damage") and fork_effects.has("bleed"),
			"Fork Jab's pitchfork pierces cloth: damage plus Bleed" + suffix)
		_check(fork_effects.size() == 2, "Fork Jab prints only damage and Bleed" + suffix)
		_check(not fork_effects.has("weak") and not fork_effects.has("ignore_block"),
			"Fork Jab invents no fear or Block bypass" + suffix)

		var glare: Dictionary = catalog.get_definition("scarecrow_sack_glare" + suffix)
		var glare_effects: Dictionary = glare.get("effects", {})
		_check(glare.get("target_kind") == "enemy_single", "Sack Glare targets one enemy" + suffix)
		_check(glare.get("from_positions") == [1, 2, 3] and glare.get("to_positions") == [1, 2, 3],
			"Sack Glare is usable from and against every position" + suffix)
		_check(glare_effects.get("cannot_buff_next_turn") == true,
			"Sack Glare carries Fear's buff lock" + suffix)
		_check(typeof(glare_effects.get("cannot_buff_next_turn")) == TYPE_BOOL,
			"Sack Glare expresses the buff lock as one-turn metadata, not a duration counter" + suffix)
		_check(glare_effects.has("weak") and glare_effects.size() == 2,
			"Sack Glare prints Weak plus the buff lock only" + suffix)

		var dive: Dictionary = catalog.get_definition("scarecrow_crow_dive" + suffix)
		var dive_effects: Dictionary = dive.get("effects", {})
		_check(dive.get("target_kind") == "enemy_back",
			"Crow Dive targets the backmost living enemy, not a fixed position" + suffix)
		_check(dive.get("from_positions") == [1, 2, 3] and dive.get("to_positions") == [1, 2, 3],
			"Crow Dive is usable from every hero position" + suffix)
		_check(dive_effects.get("ignore_block") == true, "Crow Dive ignores enemy Block" + suffix)
		_check(typeof(dive_effects.get("ignore_block")) == TYPE_BOOL,
			"Crow Dive's Block bypass is metadata, not a damage magnitude" + suffix)
		_check(dive_effects.has("damage") and dive_effects.size() == 2,
			"Crow Dive prints only damage and the Block bypass" + suffix)

		var padding: Dictionary = catalog.get_definition("scarecrow_straw_padding" + suffix)
		var padding_effects: Dictionary = padding.get("effects", {})
		_check(padding.get("target_kind") == "ally_single"
			and padding.get("to_positions") == [],
			"Straw Padding pads one living teammate" + suffix)
		_check(padding.get("from_positions") == [1, 2, 3],
			"Straw Padding can be tucked from any hero position" + suffix)
		_check(padding_effects.get("draw") == 1,
			"Straw Padding draws exactly one shared-hand card" + suffix)
		_check(padding_effects.has("block") and padding_effects.size() == 2,
			"Straw Padding prints only Block and its draw" + suffix)

	_check(catalog.get_definition("scarecrow_fork_jab").get("effects")
		== {"damage": 4, "bleed": 1}
		and catalog.get_definition("scarecrow_fork_jab_plus").get("effects")
		== {"damage": 6, "bleed": 2}, "Fork Jab+ raises damage and Bleed")
	_check(catalog.get_definition("scarecrow_sack_glare").get("effects").get("weak") == 1
		and catalog.get_definition("scarecrow_sack_glare_plus").get("effects").get("weak") == 2,
		"Sack Glare+ raises only Weak")
	_check(catalog.get_definition("scarecrow_sack_glare_plus").get("effects")
		== {"weak": 2, "cannot_buff_next_turn": true},
		"Sack Glare+ still locks buffs for the enemy's next turn only")
	_check(catalog.get_definition("scarecrow_crow_dive").get("effects").get("damage") == 3
		and catalog.get_definition("scarecrow_crow_dive_plus").get("effects").get("damage") == 5,
		"Crow Dive+ raises only its Block-bypassing damage")
	_check(catalog.get_definition("scarecrow_crow_dive_plus").get("effects")
		== {"damage": 5, "ignore_block": true},
		"Crow Dive+ keeps its Block bypass")
	_check(catalog.get_definition("scarecrow_straw_padding").get("effects").get("block") == 4
		and catalog.get_definition("scarecrow_straw_padding_plus").get("effects").get("block") == 6,
		"Straw Padding+ raises only its Block")
	_check(catalog.get_definition("scarecrow_straw_padding_plus").get("effects")
		== {"block": 6, "draw": 1}, "Straw Padding+ does not upgrade its single draw")
	for base_id: String in _cases():
		_check(catalog.get_definition(base_id).get("cost") == 1
			and catalog.get_definition(base_id + "_plus").get("cost") == 1,
			base_id + " costs one energy base and upgraded")


## The dedicated hero projection: each named base exactly once, never an upgrade.
## No global catalog total or ordering premise; the three-hero deck is checked separately.
func _test_starter_projection() -> void:
	var catalog := ScarecrowStarterCards.new()
	var cases: Dictionary = _cases()
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	_check(not starter_ids.is_empty() and not deck.is_empty(),
		"starter projection is populated before counting")
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		_check(starter_ids.count(base_id) == 1, base_id + " appears once in get_starter_ids")
		_check(deck.count(base_id) == 1, base_id + " appears once in the dedicated starting deck")
		_check(not starter_ids.has(plus_id), plus_id + " is not a starter id")
		_check(not deck.has(plus_id), plus_id + " is not in the dedicated starting deck")
	for id: String in starter_ids:
		_check(cases.has(id), id + " in get_starter_ids is one of the four authored bases")
	for id: String in deck:
		_check(cases.has(id), id + " in the dedicated deck is one of the four authored bases")
	for base_id: String in cases:
		_check(starter_ids.count(base_id) == deck.count(base_id),
			base_id + " starter-list and deck multiplicity agree")
		_check(catalog.get_definition(base_id).get("starting_copies")
			== starter_ids.count(base_id), base_id + " starting_copies matches its starter membership")
		_check(catalog.get_definition(base_id + "_plus").get("starting_copies") == 0,
			base_id + "_plus contributes no starting copy")


func _test_detached_records() -> void:
	var catalog := ScarecrowStarterCards.new()
	var sample: Dictionary = catalog.get_definition("scarecrow_fork_jab")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["effects"]["forged_key"] = 1
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["starting_copies"] = 99
	sample["reward_eligible"] = true
	var pristine: Dictionary = catalog.get_definition("scarecrow_fork_jab")
	_check(pristine.get("effects") == {"damage": 4, "bleed": 1},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [1, 2], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2], "TO arrays are deeply detached")
	_check(pristine.get("id") == "scarecrow_fork_jab", "metadata is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")
	_check(pristine.get("reward_eligible") == false, "reward eligibility is detached")
	_check(not pristine.get("effects").has("forged_key"), "no forged effect key leaks back")

	var upgraded: Dictionary = catalog.get_definition("scarecrow_straw_padding_plus")
	upgraded["effects"]["block"] = 900
	upgraded["effects"]["draw"] = 900
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	var upgraded_pristine: Dictionary = catalog.get_definition("scarecrow_straw_padding_plus")
	_check(upgraded_pristine.get("effects") == {"block": 6, "draw": 1},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [1, 2, 3], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [], "empty upgrade TO array repopulates empty")
	_check(not upgraded_pristine.get("to_positions").has(900), "no forged TO position leaks back")

	var crow: Dictionary = catalog.get_definition("scarecrow_crow_dive_plus")
	crow["target_kind"] = "enemy_single"
	crow["effects"]["ignore_block"] = false
	var crow_pristine: Dictionary = catalog.get_definition("scarecrow_crow_dive_plus")
	_check(crow_pristine.get("target_kind") == "enemy_back"
		and crow_pristine.get("effects").get("ignore_block") == true,
		"target metadata and Block bypass are detached")

	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(starter_ids.has("scarecrow_sack_glare") and deck.has("scarecrow_crow_dive")
		and all_ids.has("scarecrow_fork_jab_plus"), "projections are populated before mutation")
	starter_ids.clear()
	starter_ids.append("forged_starter")
	deck.clear()
	deck.append("forged_deck_entry")
	all_ids.clear()
	all_ids.append("forged_all_entry")
	_check(catalog.get_starter_ids().has("scarecrow_sack_glare"),
		"get_starter_ids returns a fresh array")
	_check(catalog.get_starting_deck().has("scarecrow_crow_dive"),
		"get_starting_deck returns a fresh array")
	_check(catalog.get_all_card_ids().has("scarecrow_fork_jab_plus"),
		"get_all_card_ids returns a fresh array")
	_check(not catalog.get_starter_ids().has("forged_starter"), "mutated starter ids leak nothing")
	_check(not catalog.get_starting_deck().has("forged_deck_entry"),
		"mutated deck array leaks nothing")
	_check(not catalog.get_all_card_ids().has("forged_all_entry"), "mutated ID array leaks nothing")
	_check(catalog.get_starter_ids().count("scarecrow_straw_padding") == 1
		and catalog.get_starting_deck().count("scarecrow_straw_padding") == 1,
		"per-ID multiplicity survives external mutation")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(_starter_signature(first_deck) == _starter_signature(second_deck),
		"two starting-deck calls agree")
	if not first_deck.is_empty():
		first_deck[0] = "mutated_first"
	_check(second_deck.count("scarecrow_fork_jab") == 1
		and catalog.get_starting_deck().count("scarecrow_fork_jab") == 1,
		"each base starter contributes exactly one copy")
	_check(ScarecrowStarterCards.new().get_definition("scarecrow_fork_jab") == pristine,
		"a fresh instance retains the canonical definition")


## Per-ID multiplicity for this new set only, without a global catalog total or order premise.
func _starter_signature(deck: Array) -> String:
	var parts: PackedStringArray = []
	for base_id: String in _cases():
		parts.append(base_id + ":" + str(deck.count(base_id)))
		parts.append(base_id + "_plus:" + str(deck.count(base_id + "_plus")))
	return "|".join(parts)


func _test_invalid_and_upgraded_ids() -> void:
	var catalog := ScarecrowStarterCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("scarecrow_fork_jab"),
		"", "scarecrow_not_a_card", "scarecrow_fork_jab+", "forged_starter",
		"scarecrow_fork_jab_plus_plus", "scarecrow_sack_glare_plus_plus",
		"scarecrow_crow_dive_plus_plus", "scarecrow_straw_padding_plus_plus",
		"SCARECROW_FORK_JAB", " scarecrow_fork_jab", "fork_jab",
		"scarecrow_crow_peck", "scarecrow_sack_grin"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(),
			"invalid id returns no definition: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))
	# Upgraded records exist but are terminal: no second upgrade, no starter membership.
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		var plus_record: Dictionary = catalog.get_definition(plus_id)
		_check(not plus_record.is_empty(), plus_id + " is a real record")
		_check(plus_record.get("upgrade_of") == base_id, plus_id + " points back to its base")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(catalog.get_definition(catalog.get_upgrade_id(plus_id)).is_empty(),
			plus_id + " resolves no second definition")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + " has no plus-plus record")
		_check(not catalog.get_starter_ids().has(plus_id),
			plus_id + " is not proposed as a starter")
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(12) == ""
		and catalog.get_upgrade_id("") == "", "get_upgrade_id fails closed")


func _test_deterministic_and_rng_free() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var before: int = rng.state
	var catalog := ScarecrowStarterCards.new()
	var cases: Dictionary = _cases()
	var first_records: Dictionary = {}
	for base_id: String in cases:
		first_records[base_id] = catalog.get_definition(base_id)
		first_records[base_id + "_plus"] = catalog.get_definition(base_id + "_plus")
		catalog.has_card(base_id)
		catalog.has_card(base_id + "_plus")
		catalog.get_upgrade_id(base_id)
		catalog.get_upgrade_id(base_id + "_plus")
	var first_starters: String = _starter_signature(catalog.get_starter_ids())
	var first_deck: String = _starter_signature(catalog.get_starting_deck())
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(not first_records.is_empty(), "record snapshot is populated before comparing")
	var second := ScarecrowStarterCards.new()
	for card_id: String in first_records:
		_check(not (first_records[card_id] as Dictionary).is_empty(),
			card_id + " first record is populated")
		_check(first_records[card_id] == second.get_definition(card_id),
			card_id + " record is identical across two constructions")
	_check(first_starters == _starter_signature(second.get_starter_ids()),
		"starter projection is identical across two constructions")
	_check(first_deck == _starter_signature(second.get_starting_deck()),
		"starting-deck projection is identical across two constructions")
	_check(first_deck == _starter_signature(catalog.get_starting_deck()),
		"repeated starting-deck projection is stable")
	_check(first_records["scarecrow_sack_glare"]
		== catalog.get_definition("scarecrow_sack_glare"),
		"lookups leave the catalog pristine")
	_check(rng.state == before, "a second lookup window also consumes no seeded RNG draws")


## Existing shared catalogs stay exactly as authored; these starters stay outside the live deck and rewards.
func _test_existing_catalogs_unchanged() -> void:
	var starter := StarterCards.new()
	var pool := ScarecrowPoolCards.new()
	var dedicated := ScarecrowStarterCards.new()

	var warden_strike: Dictionary = starter.get_definition("warden_strike")
	_check(not warden_strike.is_empty(), "warden_strike remains authored")
	_check(warden_strike.get("effects") == {"damage": 6}, "warden_strike stays six damage")
	_check(warden_strike.get("starting_copies") == 2, "warden_strike keeps two copies")
	var seamstress_prick: Dictionary = starter.get_definition("seamstress_prick")
	_check(not seamstress_prick.is_empty(), "seamstress_prick remains authored")
	_check(seamstress_prick.get("effects") == {"damage": 3, "bleed": 2},
		"seamstress_prick keeps bleed two")
	_check(seamstress_prick.get("starting_copies") == 2, "seamstress_prick keeps two copies")
	var pop_shot: Dictionary = starter.get_definition("tinker_pop_shot")
	_check(not pop_shot.is_empty(), "tinker_pop_shot remains authored")
	_check(pop_shot.get("effects") == {"damage": 5}, "tinker_pop_shot stays five damage")
	_check(pop_shot.get("starting_copies") == 2, "tinker_pop_shot keeps two copies")

	var crow_peck: Dictionary = pool.get_definition("scarecrow_crow_peck")
	var crow_peck_plus: Dictionary = pool.get_definition("scarecrow_crow_peck_plus")
	_check(crow_peck.get("effects") == {"damage": 4, "ignore_block": true}
		and crow_peck_plus.get("effects") == {"damage": 6, "ignore_block": true},
		"scarecrow_crow_peck stays four Block-bypassing damage, plus six")
	_check(crow_peck.get("target_kind") == "enemy_back"
		and crow_peck_plus.get("target_kind") == "enemy_back",
		"scarecrow_crow_peck keeps its backmost target")
	var sack_grin: Dictionary = pool.get_definition("scarecrow_sack_grin")
	var sack_grin_plus: Dictionary = pool.get_definition("scarecrow_sack_grin_plus")
	_check(sack_grin.get("effects") == {"weak": 1, "cannot_buff_next_turn": true}
		and sack_grin_plus.get("effects") == {"weak": 2, "cannot_buff_next_turn": true},
		"scarecrow_sack_grin keeps Weak one then two with one-turn buff lock")
	var re_stuff: Dictionary = pool.get_definition("scarecrow_re_stuff")
	var re_stuff_plus: Dictionary = pool.get_definition("scarecrow_re_stuff_plus")
	_check(re_stuff.get("effects") == {"max_hp_loss": 2, "heal": 10}
		and re_stuff_plus.get("effects") == {"max_hp_loss": 2, "heal": 13},
		"scarecrow_re_stuff keeps 2 max HP for heal 10, plus heal 13")
	var prick: Dictionary = pool.get_definition("scarecrow_pitchfork_prick")
	var prick_plus: Dictionary = pool.get_definition("scarecrow_pitchfork_prick_plus")
	_check(prick.get("effects") == {"damage": 5, "bleed": 1}
		and prick_plus.get("effects") == {"damage": 7, "bleed": 2},
		"scarecrow_pitchfork_prick stays 5/Bleed 1, plus 7/Bleed 2")
	for pool_id: String in ["scarecrow_crow_peck", "scarecrow_crow_peck_plus",
			"scarecrow_sack_grin", "scarecrow_sack_grin_plus", "scarecrow_re_stuff",
			"scarecrow_re_stuff_plus", "scarecrow_pitchfork_prick",
			"scarecrow_pitchfork_prick_plus"]:
		_check(pool.has_card(pool_id), pool_id + " remains a Scarecrow reward card")
		_check(pool.get_definition(pool_id).get("reward_eligible") == not pool_id.ends_with("_plus"),
			pool_id + " keeps its base-only reward eligibility")
		_check(pool.get_definition(pool_id).get("starting_copies") == 0,
			pool_id + " still adds no starting copy")

	var active_deck: Array[String] = starter.get_starting_deck()
	_check(active_deck.has("warden_strike") and active_deck.has("seamstress_prick")
		and active_deck.has("tinker_pop_shot"),
		"active three-hero deck keeps its representatives")
	_check(not active_deck.is_empty(), "active three-hero deck is populated before comparison")
	var raw_json: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored_deck: Variant = JSON.parse_string(raw_json)
	_check(authored_deck is Array, "authored starter deck parses")
	if authored_deck is Array:
		_check(_starter_signature(active_deck) == _starter_signature(authored_deck),
			"active three-hero starting deck still matches its authored membership")
	for base_id: String in _cases():
		var plus_id: String = base_id + "_plus"
		_check(not starter.has_card(base_id) and not starter.has_card(plus_id),
			base_id + " has not entered StarterCards")
		_check(not active_deck.has(base_id) and not active_deck.has(plus_id),
			base_id + " is absent from the active starting deck")
		if authored_deck is Array:
			_check(not authored_deck.has(base_id) and not authored_deck.has(plus_id),
				base_id + " is absent from the authored starter deck")
		_check(not pool.has_card(base_id) and not pool.has_card(plus_id),
			base_id + " has not entered the reward-only Scarecrow pool")
		_check(not pool.get_base_ids().has(base_id),
			base_id + " is not listed among Scarecrow reward bases")
		_check(not dedicated.get_definition(base_id).is_empty()
			and not dedicated.get_definition(plus_id).is_empty(),
			base_id + " only exists in the dedicated starter catalog")
	# The dedicated catalog never recycles the existing reward cards as starters.
	for pool_id: String in ["scarecrow_crow_peck", "scarecrow_sack_grin", "scarecrow_re_stuff",
			"scarecrow_pitchfork_prick", "scarecrow_straw_wrap", "scarecrow_crow_flock",
			"scarecrow_pitchfork_hook", "scarecrow_harvest_fright"]:
		_check(not dedicated.has_card(pool_id), pool_id + " is not a dedicated starter")
		_check(not dedicated.get_starter_ids().has(pool_id),
			pool_id + " is not in the dedicated starter projection")
