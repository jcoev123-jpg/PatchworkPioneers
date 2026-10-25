extends SceneTree
## V3-1 Seamstress starter-card catalog contract.
## Catalog data only: no live party, reward, hand, deck or combat behavior is assumed or claimed
## here. Tether, cleanse, heal and stitched Block are printed descriptors until a later wiring task.

const V3SeamstressStarterCards = preload("res://data/cards/v3_seamstress_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const V3SeamstressPoolCards = preload("res://data/cards/v3_seamstress_pool_cards.gd")

## Effect keys these four look-driven starters may print. Anything else would be an invented
## status, resource or combat-state descriptor.
const ALLOWED_EFFECT_KEYS: Array[String] = [
	"damage", "bleed", "heal", "block", "tether_share_percent", "cleanse_debuff",
]

## Named existing Seamstress starter records that must keep their authored numbers.
const EXPECTED_LEGACY_STARTERS: Dictionary = {
	"warden_strike": {"copies": 2, "effects": {"damage": 6}},
	"warden_brace": {"copies": 1, "effects": {"block": 7}},
	"warden_shield_bash": {"copies": 1, "effects": {"damage": 8, "weak": 1}},
	"seamstress_prick": {"copies": 2, "effects": {"damage": 3, "bleed": 2}},
	"seamstress_mend": {"copies": 1, "effects": {"heal": 5}},
	"seamstress_stitch_up": {"copies": 1, "effects": {"block": 5}},
	"tinker_pop_shot": {"copies": 2, "effects": {"damage": 5}},
	"tinker_scrap_bomb": {"copies": 1, "effects": {"damage": 4}},
	"tinker_tune_up": {"copies": 1, "effects": {"draw": 1}},
}

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
	_test_not_reward_offered()
	if failures.is_empty():
		print("v3_seamstress_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_seamstress_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Literal, independent expectations for each of the four authored base/"+" pairs.
func _cases() -> Dictionary:
	return {
		"seamstress_v3_thread_prick": {
			"name": "Thread Prick", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 3, "bleed": 2},
			"plus_cost": 1, "plus_effects": {"damage": 4, "bleed": 3}},
		"seamstress_v3_tether_loop": {
			"name": "Tether Loop", "cost": 2,
			"from": [2, 3], "target": "enemy_pair", "to": [1, 2, 3],
			"effects": {"tether_share_percent": 50},
			"plus_cost": 1, "plus_effects": {"tether_share_percent": 50}},
		"seamstress_v3_mending_knot": {
			"name": "Mending Knot", "cost": 1,
			"from": [2, 3], "target": "ally_single", "to": [],
			"effects": {"heal": 4, "cleanse_debuff": 1},
			"plus_cost": 1, "plus_effects": {"heal": 6, "cleanse_debuff": 1}},
		"seamstress_v3_shielding_hem": {
			"name": "Shielding Hem", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 4, "heal": 2},
			"plus_cost": 1, "plus_effects": {"block": 6, "heal": 3}},
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
		"starting_copies": 0 if upgraded else 1,
		"reward_eligible": false,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


## AC1: every named base/plus record compared field by field against independent literals.
func _test_each_base_and_upgrade() -> void:
	var catalog := V3SeamstressStarterCards.new()
	var cases: Dictionary = _cases()
	_check(cases.size() == 4, "this catalog's own fixture enumerates exactly four authored bases")
	var art_paths: Array[String] = []
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(catalog.has_card(base_id), base_id + " is authored")
		_check(catalog.has_card(plus_id), plus_id + " is authored")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + "_plus is not authored")
		_check(base_id.begins_with("seamstress_v3_"), base_id + " carries the v3 Seamstress prefix")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("owner") == "seamstress", card_id + " is owned by the Seamstress")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has an effect dictionary")
			_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
				and record.get("reward_eligible") == false, card_id + " is never reward eligible")
			_check(not record.has("rarity"), card_id + " carries no reward rarity")
			_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
				card_id + " shares its base illustration path")
			_check(record.get("cost") is int and record.get("cost") >= 0
				and record.get("cost") <= 3, card_id + " cost sits inside the 0..3 band")
			var effects: Dictionary = record.get("effects")
			_check(effects.size() == expected["effects"].size(),
				card_id + " prints exactly the documented effects")
			for key: String in effects:
				_check(ALLOWED_EFFECT_KEYS.has(key),
					card_id + " invents no new status or resource key: " + key)
			# Authored legality: every named slot is one of the three party positions.
			for position: Variant in record.get("from_positions"):
				_check(position is int and int(position) >= 1 and int(position) <= 3,
					card_id + " FROM position is one of 1..3: " + str(position))
			for position: Variant in record.get("to_positions"):
				_check(position is int and int(position) >= 1 and int(position) <= 3,
					card_id + " TO position is one of 1..3: " + str(position))
			_check(not record.get("from_positions").is_empty(),
				card_id + " declares at least one legal FROM slot")
			if record.get("target_kind") == "enemy_single" \
					or record.get("target_kind") == "enemy_pair":
				_check(not record.get("to_positions").is_empty(),
					card_id + " names at least one enemy slot")
			else:
				_check(record.get("to_positions").is_empty(),
					card_id + " names no enemy slot for an ally target")
		_check(catalog.get_definition(base_id).get("starting_copies") == 1,
			base_id + " starts with one copy")
		_check(catalog.get_definition(plus_id).get("starting_copies") == 0,
			plus_id + " adds no starting copy")
		_check(not catalog.get_definition(base_id).has("upgrade_of"),
			base_id + " is not itself an upgrade")
		_check(catalog.get_definition(base_id).get("upgrade_id") == plus_id,
			base_id + " carries its own upgrade link")
		_check(not catalog.get_definition(plus_id).has("upgrade_id"),
			plus_id + " has no onward upgrade link")
		_check(catalog.get_definition(plus_id).get("upgrade_of") == base_id,
			plus_id + " names its base")
		_check(catalog.get_definition(base_id).get("illustration_path")
			== catalog.get_definition(plus_id).get("illustration_path"),
			base_id + " base and upgrade share one illustration path")
		art_paths.append(str(catalog.get_definition(base_id).get("illustration_path")))
	for path: String in art_paths:
		_check(art_paths.count(path) == 1, path + " is unique to its own starter")


## AC2: the needle-and-thread look descriptors, printed magnitudes only, no live resolution claimed.
func _test_look_descriptors() -> void:
	var catalog := V3SeamstressStarterCards.new()

	# Thread Prick: a needle puncture that leaves red thread (damage + printed Bleed only).
	for suffix: String in ["", "_plus"]:
		var prick: Dictionary = catalog.get_definition("seamstress_v3_thread_prick" + suffix)
		var prick_effects: Dictionary = prick.get("effects")
		_check(prick.get("target_kind") == "enemy_single" and prick.get("to_positions") == [1, 2, 3],
			"Thread Prick pricks one enemy in any enemy slot" + suffix)
		_check(prick.get("from_positions") == [1, 2, 3],
			"Thread Prick is played from any hero slot" + suffix)
		_check(prick_effects.get("damage") is int and prick_effects.get("bleed") is int,
			"Thread Prick prints integer damage and Bleed" + suffix)
		_check(prick_effects.size() == 2 and not prick_effects.has("block")
			and not prick_effects.has("heal"),
			"Thread Prick only pricks; it neither Blocks nor heals" + suffix)
		_check(not prick_effects.has("cleanse_debuff") and not prick_effects.has("weak"),
			"Thread Prick adds no cleanse or second status" + suffix)
		_check(not prick_effects.has("bleed_bonus") and not prick_effects.has("passive_bleed"),
			"Thread Prick never pre-adds the old +1 Bleed passive" + suffix)
	_check(catalog.get_definition("seamstress_v3_thread_prick").get("effects")
		== {"damage": 3, "bleed": 2}, "Thread Prick prints 3 damage with 2 Bleed")
	_check(catalog.get_definition("seamstress_v3_thread_prick_plus").get("effects")
		== {"damage": 4, "bleed": 3}, "Thread Prick+ prints 4 damage with 3 Bleed")

	# Tether Loop: exactly a 50% pair link between two distinct living enemies.
	for suffix: String in ["", "_plus"]:
		var tether: Dictionary = catalog.get_definition("seamstress_v3_tether_loop" + suffix)
		var tether_effects: Dictionary = tether.get("effects")
		_check(tether.get("target_kind") == "enemy_pair",
			"Tether Loop targets an enemy_pair" + suffix)
		_check(tether.get("target_kind") != "enemy_all",
			"Tether Loop does not hit the whole enemy party" + suffix)
		_check(tether.get("target_kind") != "enemy_single",
			"Tether Loop is not a single-enemy strike" + suffix)
		_check(tether.get("from_positions") == [2, 3],
			"Tether Loop is thrown from the middle or back slot" + suffix)
		_check(tether.get("to_positions") == [1, 2, 3],
			"Tether Loop names the authored enemy candidate slots" + suffix)
		_check(tether.get("to_positions").size() >= 2,
			"Tether Loop offers at least two distinct enemy slots to choose from" + suffix)
		var target_slots: Dictionary = {}
		for slot: Variant in tether.get("to_positions"):
			target_slots[slot] = true
		_check(target_slots.size() == tether.get("to_positions").size(),
			"Tether Loop candidate slots are distinct, so two different foes can be chosen" + suffix)
		_check(tether_effects == {"tether_share_percent": 50},
			"Tether Loop is exactly a 50% shared-damage descriptor" + suffix)
		_check(tether_effects.get("tether_share_percent") is int,
			"Tether Loop prints an integer share percentage" + suffix)
		_check(not tether_effects.has("damage"), "Tether Loop deals no independent damage" + suffix)
		_check(not tether_effects.has("hits"), "Tether Loop invents no extra hit count" + suffix)
		_check(not tether_effects.has("duration") and not tether_effects.has("turns"),
			"Tether Loop invents no link duration" + suffix)
		_check(not tether_effects.has("tether"), "Tether Loop invents no new status name" + suffix)
		_check(not tether_effects.has("block") and not tether_effects.has("heal"),
			"Tether Loop is not an ally support card" + suffix)
	_check(catalog.get_definition("seamstress_v3_tether_loop").get("cost") == 2,
		"Tether Loop costs 2")
	_check(catalog.get_definition("seamstress_v3_tether_loop_plus").get("cost") == 1,
		"Tether Loop+ instead costs 1 energy")
	_check(catalog.get_definition("seamstress_v3_tether_loop_plus").get("effects")
		== catalog.get_definition("seamstress_v3_tether_loop").get("effects"),
		"Tether Loop+ keeps the same 50% pair-link descriptor")

	# Mending Knot: heal one living ally and remove at most one present debuff.
	for suffix: String in ["", "_plus"]:
		var mend: Dictionary = catalog.get_definition("seamstress_v3_mending_knot" + suffix)
		var mend_effects: Dictionary = mend.get("effects")
		_check(mend.get("target_kind") == "ally_single" and mend.get("to_positions") == [],
			"Mending Knot chooses exactly one living ally, not an enemy" + suffix)
		_check(mend.get("from_positions") == [2, 3],
			"Mending Knot is knotted from the middle or back slot" + suffix)
		_check(mend_effects.get("heal") is int and mend_effects.get("cleanse_debuff") is int,
			"Mending Knot prints integer heal and cleanse counts" + suffix)
		_check(mend_effects.get("cleanse_debuff") == 1,
			"Mending Knot removes at most one present debuff" + suffix)
		_check(not mend_effects.has("damage") and not mend_effects.has("bleed"),
			"Mending Knot neither strikes nor applies Bleed" + suffix)
		_check(not mend_effects.has("block"), "Mending Knot is a heal, not a Block card" + suffix)
		_check(not mend_effects.has("weak") and not mend_effects.has("exposed")
			and not mend_effects.has("revive"),
			"Mending Knot invents no status or revive" + suffix)
	_check(catalog.get_definition("seamstress_v3_mending_knot").get("effects")
		== {"heal": 4, "cleanse_debuff": 1}, "Mending Knot heals 4 and cleanses one debuff")
	_check(catalog.get_definition("seamstress_v3_mending_knot_plus").get("effects")
		== {"heal": 6, "cleanse_debuff": 1},
		"Mending Knot+ heals 6 and still cleanses one debuff")

	# Shielding Hem: stitched Block plus a patch, on ONE living ally, never the whole party.
	for suffix: String in ["", "_plus"]:
		var hem: Dictionary = catalog.get_definition("seamstress_v3_shielding_hem" + suffix)
		var hem_effects: Dictionary = hem.get("effects")
		_check(hem.get("target_kind") == "ally_single" and hem.get("to_positions") == [],
			"Shielding Hem protects exactly one living ally" + suffix)
		_check(hem.get("target_kind") != "party_all",
			"Shielding Hem is not a whole-party shield" + suffix)
		_check(hem.get("from_positions") == [1, 2, 3],
			"Shielding Hem works from any hero slot" + suffix)
		_check(hem_effects.get("block") is int and hem_effects.get("heal") is int,
			"Shielding Hem prints integer Block and heal" + suffix)
		_check(not hem_effects.has("damage") and not hem_effects.has("bleed"),
			"Shielding Hem neither strikes nor applies Bleed" + suffix)
		_check(not hem_effects.has("cleanse_debuff"),
			"Shielding Hem is not a Mending Knot clone" + suffix)
	_check(catalog.get_definition("seamstress_v3_shielding_hem").get("effects")
		== {"block": 4, "heal": 2}, "Shielding Hem Blocks 4 and patches 2")
	_check(catalog.get_definition("seamstress_v3_shielding_hem_plus").get("effects")
		== {"block": 6, "heal": 3}, "Shielding Hem+ Blocks 6 and patches 3")

	# The four kits stay distinct: one prick, one pair link, one cleanse, one hem.
	_check(catalog.get_definition("seamstress_v3_thread_prick").get("target_kind")
		== "enemy_single"
		and catalog.get_definition("seamstress_v3_tether_loop").get("target_kind")
			== "enemy_pair"
		and catalog.get_definition("seamstress_v3_mending_knot").get("target_kind")
			== "ally_single"
		and catalog.get_definition("seamstress_v3_shielding_hem").get("target_kind")
			== "ally_single",
		"each starter keeps its own target shape")


## AC3: the dedicated hero projection: each named base exactly once, never an upgrade and never a
## reward card. No shared catalog total or ordering premise; the active deck is checked separately.
func _test_starter_projection() -> void:
	var catalog := V3SeamstressStarterCards.new()
	var starter_cards := StarterCards.new()
	var pool := V3SeamstressPoolCards.new()
	var cases: Dictionary = _cases()
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	_check(not starter_ids.is_empty() and not deck.is_empty(),
		"starter projection is populated before counting")
	_check(starter_ids.size() == 4,
		"this hero's own starter projection names its four authored bases")
	_check(deck.size() == 4,
		"this hero's own starting deck holds one copy of each authored base")
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		_check(starter_ids.count(base_id) == 1, base_id + " appears once in get_starter_ids")
		_check(deck.count(base_id) == 1, base_id + " appears once in the dedicated starting deck")
		_check(not starter_ids.has(plus_id), plus_id + " is not a starter id")
		_check(not deck.has(plus_id), plus_id + " is not in the dedicated starting deck")
		_check(not starter_ids.has(base_id + "_plus_plus"),
			base_id + " proposes no forged plus-of-plus starter")
	for id: String in starter_ids:
		_check(cases.has(id), id + " in get_starter_ids is one of the four authored bases")
	for id: String in deck:
		_check(cases.has(id), id + " in the dedicated deck is one of the four authored bases")
	_check(starter_ids == deck, "starter ids and dedicated starting deck agree")
	var all_ids: Array[String] = catalog.get_all_card_ids()
	for id: String in all_ids:
		_check(cases.has(id) or cases.has(id.trim_suffix("_plus")),
			id + " belongs to one of the four authored pairs")
		_check(catalog.has_card(id), id + " is discoverable through has_card")
	for base_id: String in cases:
		_check(all_ids.has(base_id) and all_ids.has(base_id + "_plus"),
			base_id + " base and upgrade are both discoverable")
	# No ID may collide with the separate v3 Seamstress reward pool or the active starter catalog.
	for pool_id: String in pool.get_all_card_ids():
		_check(not catalog.has_card(pool_id), pool_id + " is a reward card, not a starter")
		_check(not starter_ids.has(pool_id), pool_id + " is not in the starter projection")
		_check(not deck.has(pool_id), pool_id + " is not in the dedicated starting deck")
	for active_id: String in starter_cards.get_all_card_ids():
		_check(not catalog.has_card(active_id),
			active_id + " belongs to the active starter catalog, not this one")
		_check(not starter_ids.has(active_id),
			active_id + " is not proposed as a v3 Seamstress starter")


## AC4: every returned record and projection array is detached from the catalog.
func _test_detached_records() -> void:
	var catalog := V3SeamstressStarterCards.new()
	var sample: Dictionary = catalog.get_definition("seamstress_v3_thread_prick")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["display_name"] = "Mutated"
	sample["cost"] = 99
	sample["starting_copies"] = 99
	var pristine: Dictionary = catalog.get_definition("seamstress_v3_thread_prick")
	_check(pristine.get("effects") == {"damage": 3, "bleed": 2},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [1, 2, 3], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2, 3], "TO arrays are deeply detached")
	_check(pristine.get("id") == "seamstress_v3_thread_prick", "metadata is detached")
	_check(pristine.get("display_name") == "Thread Prick", "display name is detached")
	_check(pristine.get("cost") == 1, "cost is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")
	var upgraded: Dictionary = catalog.get_definition("seamstress_v3_mending_knot_plus")
	_check(not upgraded.is_empty(), "upgrade mutation fixture loaded")
	if upgraded.is_empty():
		return
	upgraded["effects"]["heal"] = 900
	upgraded["effects"]["cleanse_debuff"] = 5
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	var upgraded_pristine: Dictionary = catalog.get_definition("seamstress_v3_mending_knot_plus")
	_check(upgraded_pristine.get("effects") == {"heal": 6, "cleanse_debuff": 1},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [2, 3], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [], "empty upgrade TO array is detached")
	_check(not upgraded_pristine.get("to_positions").has(900),
		"empty upgrade TO repopulates empty")
	var tether_plus: Dictionary = catalog.get_definition("seamstress_v3_tether_loop_plus")
	_check(not tether_plus.is_empty(), "pair-link upgrade fixture loaded")
	if not tether_plus.is_empty():
		_check(tether_plus.get("effects") == {"tether_share_percent": 50},
			"pair-link fixture is intact before mutation")
		tether_plus["effects"]["tether_share_percent"] = 100
		tether_plus["effects"]["damage"] = 900
		var tether_pristine: Dictionary = catalog.get_definition("seamstress_v3_tether_loop_plus")
		_check(tether_pristine.get("effects") == {"tether_share_percent": 50},
			"pair-link effects resist caller mutation and injection")
		_check(catalog.get_definition("seamstress_v3_tether_loop").get("effects")
			== {"tether_share_percent": 50},
			"mutating one record leaves its base untouched")
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(starter_ids.has("seamstress_v3_shielding_hem")
		and deck.has("seamstress_v3_mending_knot"), "projections are populated before mutation")
	starter_ids.clear()
	starter_ids.append("forged_starter")
	deck.clear()
	all_ids.clear()
	_check(catalog.get_starter_ids().has("seamstress_v3_shielding_hem"),
		"get_starter_ids returns a fresh array")
	_check(catalog.get_starting_deck().has("seamstress_v3_mending_knot"),
		"get_starting_deck returns a fresh array")
	_check(catalog.get_all_card_ids().has("seamstress_v3_tether_loop_plus"),
		"get_all_card_ids returns a fresh array")
	_check(not catalog.get_starter_ids().has("forged_starter"),
		"mutated starter id array leaks nothing")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(first_deck == second_deck and first_deck.size() == second_deck.size(),
		"two starting-deck calls agree")
	if not first_deck.is_empty():
		first_deck[0] = "mutated_first"
	_check(second_deck.count("seamstress_v3_thread_prick") == 1
		and catalog.get_starting_deck().count("seamstress_v3_thread_prick") == 1,
		"each base starter contributes exactly one copy")
	_check(V3SeamstressStarterCards.new().get_definition("seamstress_v3_thread_prick") == pristine,
		"a fresh instance retains the canonical definition")


## AC4: unknown, malformed and foreign IDs fail closed; '+' cards are terminal.
func _test_invalid_and_upgraded_ids() -> void:
	var catalog := V3SeamstressStarterCards.new()
	var invalid: Array = [null, 0, 1, -1, 3.5, true, false, [], ["seamstress_v3_thread_prick"], {},
		StringName("seamstress_v3_thread_prick"), "", "nonexistent_id", "seamstress_v3_",
		"seamstress_v3_thread_prick+", "SEAMSTRESS_V3_THREAD_PRICK",
		" seamstress_v3_thread_prick", "seamstress_v3_thread_prick ", "forged_starter",
		"seamstress_v3_thread_prick_plus_plus", "seamstress_v3_tether_loop_plus_plus",
		"seamstress_v3_mending_knot_plus_plus", "seamstress_v3_shielding_hem_plus_plus",
		"thread_prick", "seamstress_prick", "seamstress_running_stitch",
		"seamstress_v3_tether_stitch", "seamstress_v3_darn_the_tear",
		"warden_strike", "warden_v3_pot_helm_bonk", "yarn_ranger_needle_nock"]
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
		_check(catalog.get_upgrade_id(plus_id + "_plus") == "",
			plus_id + " has no forged plus-of-plus upgrade")
		_check(catalog.get_definition(catalog.get_upgrade_id(plus_id)).is_empty(),
			plus_id + " resolves no second definition")
		_check(not catalog.get_starter_ids().has(plus_id),
			plus_id + " is not proposed as a starter")
		_check(not catalog.get_starting_deck().has(plus_id),
			plus_id + " is not proposed in the dedicated deck")
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(12) == ""
		and catalog.get_upgrade_id("") == "" and catalog.get_upgrade_id([]) == "",
		"get_upgrade_id fails closed on non-string and empty IDs")
	_check(catalog.get_definition(12).is_empty() and catalog.has_card(12) == false,
		"numeric IDs fail closed on definition and membership")
	_check(not catalog.has_card(StringName("seamstress_v3_shielding_hem"))
		and catalog.get_definition(StringName("seamstress_v3_shielding_hem")).is_empty(),
		"StringName IDs are rejected rather than coerced")


func _test_deterministic_and_rng_free() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var before: int = rng.state
	var catalog := V3SeamstressStarterCards.new()
	var first_ids: Array[String] = catalog.get_all_card_ids()
	var first_starters: Array[String] = catalog.get_starter_ids()
	var first_deck: Array[String] = catalog.get_starting_deck()
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		catalog.get_definition(base_id)
		catalog.get_definition(base_id + "_plus")
		catalog.has_card(base_id)
		catalog.has_card(base_id + "_plus")
		catalog.get_upgrade_id(base_id)
		catalog.get_upgrade_id(base_id + "_plus")
		catalog.get_definition(base_id + "_plus_plus")
	var second := V3SeamstressStarterCards.new()
	_check(not first_ids.is_empty(), "determinism fixture loaded (precondition)")
	_check(first_ids == second.get_all_card_ids(), "catalog enumeration is deterministic")
	_check(first_starters == second.get_starter_ids(), "starter enumeration is deterministic")
	_check(first_deck == second.get_starting_deck(), "starting-deck projection is deterministic")
	_check(first_ids == catalog.get_all_card_ids(), "repeated enumeration is stable")
	_check(first_starters == catalog.get_starter_ids(), "repeated starter enumeration is stable")
	_check(first_deck == catalog.get_starting_deck(), "repeated projection is stable")
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(catalog.get_definition("seamstress_v3_thread_prick").get("effects")
		== {"damage": 3, "bleed": 2}, "lookups leave the catalog pristine")
	_check(rng.state == before, "a second lookup window also consumes no seeded RNG draws")
	# Twin parity: an untouched generator must still produce the same next value.
	var twin := RandomNumberGenerator.new()
	twin.seed = 90210
	var twin_next: int = twin.randi()
	var probe := RandomNumberGenerator.new()
	probe.seed = 90210
	for _round: int in range(3):
		for card_id: String in catalog.get_all_card_ids():
			catalog.get_definition(card_id)
			catalog.has_card(card_id)
			catalog.get_upgrade_id(card_id)
		catalog.get_definition("seamstress_v3_missing")
		catalog.has_card(null)
		catalog.get_upgrade_id(17)
	var probe_next: int = probe.randi()
	_check(probe_next == twin_next and probe.state == twin.state,
		"a separate RNG instance's state is unchanged by catalog calls")


## AC3: the original StarterCards catalog, its authored JSON deck and the separate v3 reward pool
## are untouched; the four new pairs never leak into the live deck or the reward pool.
func _test_existing_catalogs_unchanged() -> void:
	var catalog := V3SeamstressStarterCards.new()
	var starter := StarterCards.new()
	var pool := V3SeamstressPoolCards.new()
	var cases: Dictionary = _cases()
	var active_deck: Array[String] = starter.get_starting_deck()
	_check(not active_deck.is_empty(), "active starting deck is populated (precondition)")

	for starter_id: String in EXPECTED_LEGACY_STARTERS:
		var expected: Dictionary = EXPECTED_LEGACY_STARTERS[starter_id]
		var record: Dictionary = starter.get_definition(starter_id)
		_check(not record.is_empty(), starter_id + " remains a StarterCards definition")
		_check(record.get("effects") == expected["effects"],
			starter_id + " printed effects unchanged")
		_check(record.get("starting_copies") == expected["copies"],
			starter_id + " catalog multiplicity unchanged")
		_check(active_deck.count(starter_id) == expected["copies"],
			starter_id + " runtime deck copies unchanged")
		_check(not catalog.has_card(starter_id),
			starter_id + " has not entered the v3 starter catalog")
	_check(starter.get_definition("seamstress_prick").get("owner") == "seamstress",
		"seamstress_prick remains Seamstress-owned")
	_check(starter.get_definition("warden_strike").get("owner") == "warden",
		"warden_strike remains Warden-owned")
	_check(starter.get_definition("tinker_pop_shot").get("owner") == "tinker",
		"tinker_pop_shot remains Tinker-owned")

	var raw_json: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored_deck: Variant = JSON.parse_string(raw_json)
	_check(authored_deck is Array, "authored starter deck parses (precondition)")
	if authored_deck is Array:
		_check(active_deck == authored_deck,
			"active three-hero starting deck still matches its authored membership and order")

	# The separate v3 Seamstress reward catalog keeps its authored Tether / cleanse records.
	var reward_ids: Array[String] = pool.get_all_card_ids()
	_check(not reward_ids.is_empty(), "v3 Seamstress reward pool is populated (precondition)")
	var snapshot: Dictionary = {}
	for reward_id: String in reward_ids:
		snapshot[reward_id] = pool.get_definition(reward_id)
	var tether_stitch: Dictionary = pool.get_definition("seamstress_v3_tether_stitch")
	_check(not tether_stitch.is_empty(), "Tether Stitch stays a v3 Seamstress reward")
	_check(tether_stitch.get("target_kind") == "enemy_pair"
		and tether_stitch.get("effects") == {"tether_share_percent": 50},
		"Tether Stitch keeps its own 50% pair descriptor")
	_check(tether_stitch.get("cost") == 2 and tether_stitch.get("reward_eligible") == true,
		"Tether Stitch keeps its authored cost and reward eligibility")
	_check(pool.get_upgrade_id("seamstress_v3_tether_stitch")
		== "seamstress_v3_tether_stitch_plus",
		"Tether Stitch still upgrades inside its reward pool")
	var darn: Dictionary = pool.get_definition("seamstress_v3_darn_the_tear")
	_check(not darn.is_empty(), "Darn the Tear stays a v3 Seamstress reward")
	_check(darn.get("target_kind") == "ally_single"
		and darn.get("effects") == {"heal": 4, "cleanse_debuff": 1},
		"Darn the Tear keeps its own heal-and-cleanse descriptor")
	_check(pool.get_upgrade_id("seamstress_v3_darn_the_tear")
		== "seamstress_v3_darn_the_tear_plus",
		"Darn the Tear still upgrades inside its reward pool")
	# Exercise the new catalog, then prove the reward pool is unchanged field by field.
	for base_id: String in cases:
		catalog.get_definition(base_id)
		catalog.get_definition(base_id + "_plus")
		catalog.get_upgrade_id(base_id)
	_check(catalog.get_definition("seamstress_v3_tether_stitch").is_empty(),
		"the starter catalog does not serve a reward card")
	_check(catalog.get_definition("seamstress_v3_darn_the_tear").is_empty(),
		"the starter catalog does not serve the reward cleanse card")
	for reward_id: String in snapshot:
		_check(pool.get_definition(reward_id) == snapshot[reward_id],
			"v3 Seamstress reward record unchanged: " + reward_id)
	for reward_id: String in reward_ids:
		_check(not catalog.has_card(reward_id),
			"starter catalog never overlaps reward id " + reward_id)

	# New authoring is unique: no starter ID exists in an older catalog or the authored deck.
	for base_id: String in cases:
		for card_id: String in [base_id, base_id + "_plus"]:
			_check(not starter.has_card(card_id), card_id + " has not entered StarterCards")
			_check(not active_deck.has(card_id), card_id + " is absent from the active deck")
			if authored_deck is Array:
				_check(not (authored_deck as Array).has(card_id),
					card_id + " is absent from the authored starter deck")
			_check(not pool.has_card(card_id), card_id + " is absent from the reward pool")
			_check(catalog.get_definition(card_id).get("reward_eligible") == false,
				card_id + " is never reward eligible")
			_check(not catalog.get_definition(card_id).has("rarity"),
				card_id + " carries no pool rarity")


## AC3: until the later wiring task, the live reward routing cannot offer or resolve these starters.
func _test_not_reward_offered() -> void:
	var catalog := V3SeamstressStarterCards.new()
	var cases: Dictionary = _cases()
	var candidates: Array = RunPoolCardRewardOffers.get_authored_base_candidates()
	_check(not candidates.is_empty(), "authored reward candidates are non-empty (precondition)")
	var candidate_ids: Dictionary = {}
	for record: Variant in candidates:
		if record is Dictionary:
			candidate_ids[String(record.get("id", ""))] = true
	_check(candidate_ids.has("seamstress_running_stitch"),
		"reward candidates still include an existing Seamstress card (precondition)")
	for base_id: String in cases:
		for card_id: String in [base_id, base_id + "_plus"]:
			_check(not candidate_ids.has(card_id), "reward candidates exclude " + card_id)
			_check(RunPoolCardRewardOffers.resolve_reward_definition(card_id).is_empty(),
				"starter is not reward-resolvable yet: " + card_id)
	_check(not RunPoolCardRewardOffers.resolve_reward_definition("seamstress_running_stitch").is_empty(),
		"an existing Seamstress reward card is still reward-resolvable (precondition)")
