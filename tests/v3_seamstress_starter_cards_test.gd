extends SceneTree
## V3-1 Seamstress starter-card catalog contract.
## The catalog half keeps this hero's authored data authoritative (no live party, reward, hand, deck
## or run wiring is assumed there). The appended suite drives the scene-free paid Block-and-heal
## resolver for Shielding Hem and Patchwork Poultice against real seeded CombatDeck/CombatParty
## state; live hand and app integration remain a later task.

const V3SeamstressStarterCards = preload("res://data/cards/v3_seamstress_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const V3SeamstressPoolCards = preload("res://data/cards/v3_seamstress_pool_cards.gd")
const V3SeamstressHemCards = preload("res://scripts/combat_seamstress_v3_hem_cards.gd")
const SeamstressCleansingCards = preload("res://scripts/combat_seamstress_v3_cleansing_cards.gd")

## A catalog source that serves one caller-supplied record, so a rewritten field or a relinked
## upgrade can be proven inert before any energy, hand, Block, HP or RNG state moves.
class ForgedHem extends "res://scripts/combat_seamstress_v3_hem_cards.gd":
	var forged: Dictionary = {}

	func _catalog_definition(_id: String) -> Dictionary:
		return forged.duplicate(true)

const HEM := "seamstress_v3_shielding_hem"
const HEM_PLUS := "seamstress_v3_shielding_hem_plus"
const POULTICE := "seamstress_v3_patchwork_poultice"
const POULTICE_PLUS := "seamstress_v3_patchwork_poultice_plus"
const HEM_CARD_IDS := [HEM, HEM_PLUS, POULTICE, POULTICE_PLUS]

## Independent literal expectations copied from the v3 design and the authored catalogs, never read
## back from the resolver under test.
const HEM_BLOCK := {HEM: 4, HEM_PLUS: 6, POULTICE: 3, POULTICE_PLUS: 4}
const HEM_HEAL := {HEM: 2, HEM_PLUS: 3, POULTICE: 3, POULTICE_PLUS: 4}
const HEM_FROM := {HEM: [1, 2, 3], HEM_PLUS: [1, 2, 3], POULTICE: [2, 3], POULTICE_PLUS: [2, 3]}
const HEM_FILLERS := ["filler_hem", "filler_patch", "filler_thread", "filler_needle",
	"filler_bobbin", "filler_scrap"]

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
var _hem_records: Array = []


func _initialize() -> void:
	_test_each_base_and_upgrade()
	_test_look_descriptors()
	_test_starter_projection()
	_test_detached_records()
	_test_invalid_and_upgraded_ids()
	_test_deterministic_and_rng_free()
	_test_existing_catalogs_unchanged()
	_test_not_reward_offered()
	_test_hem_catalog_contracts()
	_test_hem_paid_play()
	_test_hem_cap_and_full_hp()
	_test_hem_repeat_and_no_draw()
	_test_hem_refusals()
	_test_hem_tampered_catalog()
	_test_hem_seeded_replay()
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

# ---------------------------------------------------------------------------------------------
# V3-1 Shielding Hem / Patchwork Poultice: authentic paid Block-and-heal resolution
# ---------------------------------------------------------------------------------------------

## The four exact authored contracts as independent literal expectations.
func _hem_cases() -> Dictionary:
	return {
		HEM: {"catalog": "starter", "name": "Shielding Hem", "cost": 1, "block": 4, "heal": 2,
			"from": [1, 2, 3], "copies": 1, "reward": false},
		HEM_PLUS: {"catalog": "starter", "name": "Shielding Hem+", "cost": 1, "block": 6,
			"heal": 3, "from": [1, 2, 3], "copies": 0, "reward": false},
		POULTICE: {"catalog": "pool", "name": "Patchwork Poultice", "cost": 1, "block": 3,
			"heal": 3, "from": [2, 3], "copies": 0, "reward": true},
		POULTICE_PLUS: {"catalog": "pool", "name": "Patchwork Poultice+", "cost": 1, "block": 4,
			"heal": 4, "from": [2, 3], "copies": 0, "reward": false},
	}


## AC1: every printing's authored ID/cost/FROM/effect/upgrade contract, read independently.
func _test_hem_catalog_contracts() -> void:
	var starter := V3SeamstressStarterCards.new()
	var pool := V3SeamstressPoolCards.new()
	var service := V3SeamstressHemCards.new()
	var cases: Dictionary = _hem_cases()
	_check(cases.size() == 4, "hem/poultice fixture enumerates exactly four printings")
	for card_id: String in HEM_CARD_IDS:
		var spec: Dictionary = cases[card_id]
		var source: Variant = starter if spec["catalog"] == "starter" else pool
		var other: Variant = pool if spec["catalog"] == "starter" else starter
		var record: Dictionary = source.get_definition(card_id)
		_check(not record.is_empty(), card_id + ": authored record exists in its own catalog")
		_check(record.get("id") == card_id, card_id + ": authored id")
		_check(record.get("display_name") == spec["name"], card_id + ": authored display name")
		_check(record.get("owner") == "seamstress", card_id + ": authored owner")
		_check(record.get("cost") == spec["cost"], card_id + ": authored cost")
		_check(record.get("target_kind") == "ally_single", card_id + ": one living ally target")
		_check(record.get("from_positions") == spec["from"], card_id + ": authored FROM seats")
		_check(record.get("to_positions") == [], card_id + ": no enemy TO slot")
		_check(record.get("effects") == {"block": spec["block"], "heal": spec["heal"]},
			card_id + ": authored Block and heal only")
		_check(record.get("starting_copies") == spec["copies"],
			card_id + ": authored starting copies")
		_check(record.get("reward_eligible") == spec["reward"], card_id + ": authored reward flag")
		_check(not other.has_card(card_id), card_id + ": owned by exactly one catalog")
		if card_id.ends_with("_plus"):
			_check(record.get("upgrade_of") == card_id.trim_suffix("_plus"),
				card_id + ": points back at its base")
			_check(not record.has("upgrade_id"), card_id + ": terminal upgrade link")
		else:
			_check(record.get("upgrade_id") == card_id + "_plus",
				card_id + ": points at its + printing")
			_check(not record.has("upgrade_of"), card_id + ": the base is not an upgrade")
		_check(service.is_supported_card(card_id), card_id + ": resolver authenticates the ID")
	# Only these four printings: no other Seamstress card, no forged link, no coercion.
	for unsupported: Variant in [
		"seamstress_v3_thread_prick", "seamstress_v3_tether_loop", "seamstress_v3_mending_knot",
		"seamstress_v3_mending_knot_plus", "seamstress_v3_needle_rain", "seamstress_v3_scarlet_knot",
		"seamstress_v3_bobbin_snag", "seamstress_v3_tether_stitch", "seamstress_v3_darn_the_tear",
		"seamstress_v3_blanket_of_barbs", "seamstress_v3_midnight_loom", "seamstress_mend",
		"seamstress_mend_plus", "seamstress_stitch_up", "seamstress_running_stitch",
		"warden_v3_pot_helm_bonk", "tinker_pop_shot",
		HEM + "_plus_plus", POULTICE + "_plus_plus", HEM.to_upper(), HEM + " ", "", null, 7,
		StringName(HEM)]:
		_check(not service.is_supported_card(unsupported),
			"resolver rejects unsupported id: " + str(unsupported))
	# The existing cleansing helper still owns only Mending Knot / Darn the Tear and rejects these.
	var cleansing := SeamstressCleansingCards.new()
	for card_id: String in HEM_CARD_IDS:
		_check(not cleansing.is_supported_card(card_id),
			card_id + ": the cleansing helper still rejects it")
	_check(cleansing.is_supported_card("seamstress_v3_mending_knot")
		and cleansing.is_supported_card("seamstress_v3_darn_the_tear"),
		"the cleansing helper still owns its own two card families (precondition)")


## AC1: each printing pays exactly one energy and discards one copy to Block+heal the selected ally.
func _test_hem_paid_play() -> void:
	var service := V3SeamstressHemCards.new()
	for card_id: String in HEM_CARD_IDS:
		for seat in HEM_FROM[card_id]:
			for recipient in [seat, seat % 3 + 1]:
				var label := "%s owner=%d target=%d" % [card_id, seat, recipient]
				var party := _hem_party(seat)
				for position in range(1, 4):
					_check(party.apply_damage(position, 7),
						label + ": every hero really lost seven HP")
				party._heroes[recipient - 1]["statuses"] = {"bleed": 2, "weak": 1}
				party._heroes[recipient % 3]["statuses"] = {"tangled": 3}
				_check(party.get_hero(recipient)["statuses"] == {"bleed": 2, "weak": 1}
					and party.get_hero(recipient % 3 + 1)["statuses"] == {"tangled": 3},
					label + ": real status maps stored on the recipient and a neighbor")
				var deck := _hem_deck(card_id)
				var before := _hem_snapshot(deck, party)
				var held_before: int = deck.hand.count(card_id)
				var hp_before: int = party.get_hero(recipient)["hp"]
				var result: Dictionary = service.play_card(deck, party, card_id, recipient)
				_check(result.get("ok") == true and result.get("reason") == "applied",
					label + ": authorized paid play")
				_check(result.get("card_id") == card_id and result.get("cost") == 1,
					label + ": receipt names the card and its one energy")
				_check(result.get("owner_position") == seat
					and result.get("target_position") == recipient,
					label + ": receipt reports the real owner and recipient seats")
				_check(result.get("block") == HEM_BLOCK[card_id]
					and result.get("block_before") == 0
					and result.get("block_after") == HEM_BLOCK[card_id],
					label + ": exactly the printed Block landed on that ally")
				_check(result.get("heal") == HEM_HEAL[card_id]
					and result.get("healed") == HEM_HEAL[card_id]
					and result.get("hp_before") == hp_before
					and result.get("hp_after") == hp_before + HEM_HEAL[card_id],
					label + ": exactly the printed heal was reported and applied")
				_check(_hem_snapshot(deck, party) == _hem_expected(before, card_id, recipient),
					label + ": exact hand/piles/energy/turn/heroes and untouched injected RNG")
				_check(deck.hand.count(card_id) == held_before - 1
					and deck.discard_pile == [card_id] and deck.hand.size() == 4,
					label + ": precisely one held copy moved to the discard pile")
				_check(deck.energy == CombatState.TURN_ENERGY - 1,
					label + ": exactly one energy was charged")
				_check(party.get_hero(recipient)["statuses"] == {"bleed": 2, "weak": 1},
					label + ": the recipient's status map is untouched")
				_check(_hem_snapshot(deck, party)["rng_state"] == before["rng_state"],
					label + ": no run-RNG draw during resolution")
				result["block_after"] = 999
				result["hp_after"] = 999
				_check(party.get_hero(recipient)["block"] == HEM_BLOCK[card_id]
					and party.get_hero(recipient)["hp"] == hp_before + HEM_HEAL[card_id],
					label + ": a mutated receipt cannot change the ally")


## AC2: full-HP and near-max recipients, pre-existing Block, and a genuine second copy.
func _test_hem_cap_and_full_hp() -> void:
	var service := V3SeamstressHemCards.new()
	for card_id: String in HEM_CARD_IDS:
		var full := _hem_party(2)
		_check(full.gain_block(2, 5) and full.get_hero(2)["block"] == 5
			and full.get_hero(2)["hp"] == full.get_hero(2)["max_hp"],
			card_id + ": fixture really is a full-HP ally with pre-existing Block")
		var full_deck := _hem_deck(card_id)
		var full_before := _hem_snapshot(full_deck, full)
		var full_result: Dictionary = service.play_card(full_deck, full, card_id, 2)
		_check(full_result.get("ok") == true and full_result.get("healed") == 0
			and full_result.get("hp_before") == 30 and full_result.get("hp_after") == 30,
			card_id + ": a full-HP ally is healed for nothing")
		_check(full_result.get("block_before") == 5
			and full_result.get("block_after") == 5 + HEM_BLOCK[card_id],
			card_id + ": the printed Block still stacks onto existing Block")
		_check(_hem_snapshot(full_deck, full) == _hem_expected(full_before, card_id, 2),
			card_id + ": the full-HP play pays once and changes only that ally")

		var near := _hem_party(2)
		_check(near.apply_damage(2, 1) and near.get_hero(2)["hp"] == 29,
			card_id + ": fixture really sits one HP below max")
		var near_deck := _hem_deck(card_id)
		var near_before := _hem_snapshot(near_deck, near)
		var near_result: Dictionary = service.play_card(near_deck, near, card_id, 2)
		_check(near_result.get("ok") == true and near_result.get("healed") == 1
			and near_result.get("hp_before") == 29 and near_result.get("hp_after") == 30,
			card_id + ": the heal caps at max HP and reports the real gain")
		_check(_hem_snapshot(near_deck, near) == _hem_expected(near_before, card_id, 2),
			card_id + ": a capped heal still pays and discards exactly once")

	# A legitimate second copy held: each play moves exactly one copy and applies once.
	var twin := _hem_party(2)
	_check(twin.apply_damage(3, 10) and twin.get_hero(3)["hp"] == 16,
		"second-copy fixture really has a wounded Tinker")
	var twin_deck := _hem_deck(HEM_PLUS)
	var twin_held: int = twin_deck.hand.count(HEM_PLUS)
	_check(twin_held >= 2, "second-copy fixture really holds at least two copies")
	for play_index in range(2):
		var before := _hem_snapshot(twin_deck, twin)
		var result: Dictionary = service.play_card(twin_deck, twin, HEM_PLUS, 3)
		_check(result.get("ok") == true and result.get("healed") == HEM_HEAL[HEM_PLUS]
			and result.get("block_after") == HEM_BLOCK[HEM_PLUS] * (play_index + 1),
			"second-copy play %d applies the printed Block and heal once" % (play_index + 1))
		_check(twin_deck.hand.count(HEM_PLUS) == twin_held - play_index - 1,
			"second-copy play %d leaves the other copies in hand" % (play_index + 1))
		_check(_hem_snapshot(twin_deck, twin) == _hem_expected(before, HEM_PLUS, 3),
			"second-copy play %d matches the single-transaction oracle" % (play_index + 1))
		_check(twin_deck.discard_pile.count(HEM_PLUS) == play_index + 1,
			"second-copy play %d adds exactly one discarded copy" % (play_index + 1))


## AC1/AC2: no draw pile or injected RNG movement, and one accepted copy cannot be replayed.
func _test_hem_repeat_and_no_draw() -> void:
	var party := _hem_party(3)
	_check(party.apply_damage(1, 10) and party.get_hero(1)["hp"] == 30,
		"no-draw fixture really has a wounded front ally")
	var deck := CombatDeck.new(
		[HEM, HEM_FILLERS[0], HEM_FILLERS[1], HEM_FILLERS[2], HEM_FILLERS[3]], _hem_rng(5150))
	_check(deck.start_turn() and deck.hand.count(HEM) == 1 and deck.energy == 3,
		"single-copy fixture draws its one genuine copy")
	var rng_before: int = deck._rng.state
	var draw_before: Array = deck.draw_pile.duplicate(true)
	var first: Dictionary = _hem_service_play(deck, party, HEM, 1)
	_check(first.get("ok") == true and first.get("healed") == HEM_HEAL[HEM],
		"the single copy plays once and heals the front ally")
	_check(deck.draw_pile == draw_before and deck._rng.state == rng_before,
		"the paid play draws no card and advances no seeded RNG")
	_check(not deck.hand.has(HEM) and deck.discard_pile == [HEM],
		"the played copy alone moved to the discard pile")
	var replayed_at := _hem_snapshot(deck, party)
	var replay: Dictionary = _hem_service_play(deck, party, HEM, 1)
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		"a second play of the same ID fails once the copy is discarded")
	_check(_hem_snapshot(deck, party) == replayed_at and deck._rng.state == rng_before,
		"the double-play refusal leaves the deck, roster and RNG untouched")


## AC3: every invalid request fails closed before any payment, Block, heal or discard.
func _test_hem_refusals() -> void:
	var party := _hem_party(2)

	var inactive := CombatDeck.new(
		[HEM, HEM, HEM, HEM_FILLERS[0], HEM_FILLERS[1], HEM_FILLERS[2]], _hem_rng(414))
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_hem_rejected(inactive, party, HEM, 2, "inactive turn")

	var other_deck := _hem_deck(POULTICE)
	_check(other_deck.hand.has(POULTICE) and not other_deck.hand.has(HEM),
		"absent-card fixture holds the other genuine ID only")
	_hem_rejected(other_deck, party, HEM, 2, "card absent from hand")
	_hem_rejected(other_deck, party, "seamstress_v3_missing_hem", 2, "unknown card ID")
	_hem_rejected(other_deck, party, "", 2, "empty card ID")
	_hem_rejected(other_deck, party, 7, 2, "non-string card ID")
	_hem_rejected(other_deck, party, StringName(HEM), 2, "StringName card ID")
	_hem_rejected(other_deck, party, HEM + "_plus_plus", 2, "forged plus-of-plus ID")

	var broke := _hem_deck(HEM)
	_check(broke.try_spend_energy(CombatState.TURN_ENERGY) and broke.energy == 0
		and broke.hand.has(HEM), "energy-short fixture is genuinely broke and holds the card")
	_hem_rejected(broke, party, HEM, 2, "zero energy")

	var no_owner := _hem_party_without_owner()
	_check(no_owner.is_valid() and no_owner.get_hero(1)["id"] == "warden"
		and no_owner.get_hero(2)["id"] == "tinker" and no_owner.get_hero(3)["id"] == "mender",
		"missing-owner fixture is a valid three-distinct-hero party with no Seamstress")
	_hem_rejected(_hem_deck(HEM), no_owner, HEM, 2, "party without the Seamstress")

	var downed_owner := _hem_party(2)
	_check(downed_owner.apply_damage(2, 30) and downed_owner.is_downed(2),
		"torn-caster fixture has a genuinely downed Seamstress")
	_hem_rejected(_hem_deck(HEM), downed_owner, HEM, 2, "downed Seamstress")

	var front := _hem_party(1)
	_check(front.get_hero(1)["id"] == "seamstress" and front.get_hero(1)["position"] == 1,
		"illegal-FROM fixture really seats the living Seamstress in slot 1")
	_hem_rejected(_hem_deck(POULTICE), front, POULTICE, 2,
		"Patchwork Poultice from its illegal FROM seat 1")
	_hem_rejected(_hem_deck(POULTICE_PLUS), front, POULTICE_PLUS, 2,
		"Patchwork Poultice+ from its illegal FROM seat 1")

	var downed_target := _hem_party(2)
	_check(downed_target.apply_damage(3, 26) and downed_target.is_downed(3),
		"torn-recipient fixture has a genuinely downed Tinker")
	_hem_rejected(_hem_deck(HEM), downed_target, HEM, 3, "downed recipient")

	for bad_target in [0, -1, 4, 99]:
		_hem_rejected(_hem_deck(HEM), _hem_party(2), HEM, bad_target,
			"target outside 1-3: " + str(bad_target))

	var broken_roster := _hem_party(2)
	broken_roster._heroes[1]["hp"] = 31
	_check(broken_roster.get_hero(2)["hp"] == 31 and broken_roster.get_hero(2)["max_hp"] == 30,
		"malformed-roster fixture really has HP above max")
	_hem_rejected(_hem_deck(HEM), broken_roster, HEM, 2, "malformed party HP")

	var duplicate := _hem_party(2)
	duplicate._heroes[0]["id"] = "seamstress"
	_check(duplicate.get_hero(1)["id"] == "seamstress"
		and duplicate.get_hero(2)["id"] == "seamstress",
		"duplicate-identity fixture really repeats the owner ID")
	_hem_rejected(_hem_deck(HEM), duplicate, HEM, 2, "duplicate hero identity")

	var malformed := _hem_party(2)
	malformed._heroes[2]["statuses"] = {"bleed": -1}
	_check(malformed.get_hero(3)["statuses"] == {"bleed": -1},
		"malformed-status fixture really stores a negative counter")
	_hem_rejected(_hem_deck(HEM), malformed, HEM, 2, "malformed neighbor statuses")

	var overflow := _hem_party(2)
	overflow._heroes[2]["block"] = CombatParty.MAX_INT - HEM_BLOCK[HEM] + 1
	_check(overflow.get_hero(3)["block"] == CombatParty.MAX_INT - HEM_BLOCK[HEM] + 1,
		"Block-overflow fixture really sits one Block short of the ceiling")
	_hem_rejected(_hem_deck(HEM), overflow, HEM, 3, "Block overflow")

	_hem_rejected(null, _hem_party(2), HEM, 2, "null deck")
	_hem_rejected(_hem_deck(HEM), null, HEM, 2, "null party")
	_hem_rejected(_hem_deck(HEM), CombatParty.new([]), HEM, 2, "invalid party roster")

	# The cleansing helper must refuse these IDs at play time without touching anything either.
	var cleansing := SeamstressCleansingCards.new()
	for card_id: String in HEM_CARD_IDS:
		var deck := _hem_deck(card_id)
		var before := _hem_snapshot(deck, party)
		var result: Dictionary = cleansing.play_card(deck, party, card_id, 2, "")
		_check(result.get("ok") == false and result.get("reason") == "unsupported_card",
			card_id + ": the cleansing helper still refuses this paid Block-and-heal play")
		_check(_hem_snapshot(deck, party) == before,
			card_id + ": the cleansing refusal changes no hand, pile, energy, hero or RNG")

	# A rejected attempt never poisons the next authentic one on the same objects.
	var retry_party := _hem_party(2)
	_check(retry_party.apply_damage(3, 8) and retry_party.get_hero(3)["hp"] == 18,
		"retry fixture really has a wounded Tinker")
	var retry_deck := _hem_deck(POULTICE)
	_hem_rejected(retry_deck, retry_party, POULTICE, 0, "retry: invalid target first")
	_hem_rejected(retry_deck, retry_party, HEM, 3, "retry: wrong-card ID second")
	var retry_before := _hem_snapshot(retry_deck, retry_party)
	var retry_result: Dictionary = _hem_service_play(retry_deck, retry_party, POULTICE, 3)
	_check(retry_result.get("ok") == true and retry_result.get("healed") == HEM_HEAL[POULTICE]
		and retry_result.get("block_after") == HEM_BLOCK[POULTICE],
		"retry: the authentic play then succeeds")
	_check(_hem_snapshot(retry_deck, retry_party)
		== _hem_expected(retry_before, POULTICE, 3),
		"retry: exactly one charge, one discard, one Block/heal and an untouched RNG")


## AC3: a rewritten or relinked catalog record is inert before any state changes.
func _test_hem_tampered_catalog() -> void:
	var forged := ForgedHem.new()
	var starter := V3SeamstressStarterCards.new()
	var pool := V3SeamstressPoolCards.new()
	for card_id: String in HEM_CARD_IDS:
		var authentic: Dictionary = starter.get_definition(card_id)
		if authentic.is_empty():
			authentic = pool.get_definition(card_id)
		_check(not authentic.is_empty(), card_id + ": authentic catalog record loaded")
		var link := "upgrade_of" if card_id.ends_with("_plus") else "upgrade_id"
		var fields: Array = ["id", "owner", "cost", "from_positions", "to_positions",
			"target_kind", "effects", "starting_copies", "reward_eligible", link]
		var replacements: Dictionary = {
			"id": "seamstress_forged_hem", "owner": "warden", "cost": 2,
			"from_positions": [1], "to_positions": [1], "target_kind": "enemy_single",
			"effects": {"block": 99, "heal": 99},
			"upgrade_id": "seamstress_forged_hem", "upgrade_of": "seamstress_forged_hem",
		}
		replacements["starting_copies"] = int(authentic.get("starting_copies", 0)) + 1
		replacements["reward_eligible"] = not bool(authentic.get("reward_eligible", false))
		var mutations: Array = []
		for field: String in fields:
			var omitted: Dictionary = authentic.duplicate(true)
			omitted.erase(field)
			mutations.append(omitted)
			var altered: Dictionary = authentic.duplicate(true)
			altered[field] = replacements[field]
			mutations.append(altered)
		var extra_effect: Dictionary = authentic.duplicate(true)
		extra_effect["effects"]["cleanse_debuff"] = 1
		mutations.append(extra_effect)
		var typed_cost: Dictionary = authentic.duplicate(true)
		typed_cost["cost"] = float(typed_cost["cost"])
		mutations.append(typed_cost)
		var typed_block: Dictionary = authentic.duplicate(true)
		typed_block["effects"]["block"] = float(typed_block["effects"]["block"])
		mutations.append(typed_block)
		var relinked: Dictionary = authentic.duplicate(true)
		relinked["upgrade_of" if link == "upgrade_id" else "upgrade_id"] = "seamstress_forged_hem"
		mutations.append(relinked)

		var party := _hem_party(2)
		var deck := _hem_deck(card_id)
		for mutation: Dictionary in mutations:
			forged.forged = mutation
			var before := _hem_snapshot(deck, party)
			var result: Dictionary = forged.play_card(deck, party, card_id, 2)
			_check(result.get("ok") == false and result.get("reason") == "catalog_mismatch",
				card_id + ": a tampered catalog record is refused")
			_check(_hem_snapshot(deck, party) == before and forged.forged == mutation,
				card_id + ": the forgery refusal spends, discards and heals nothing")
		forged.forged = authentic
		var before_ok := _hem_snapshot(deck, party)
		var accepted: Dictionary = forged.play_card(deck, party, card_id, 2)
		_check(accepted.get("ok") == true and accepted.get("block") == HEM_BLOCK[card_id]
			and accepted.get("heal") == HEM_HEAL[card_id],
			card_id + ": the restored authentic record still plays")
		_check(_hem_snapshot(deck, party) == _hem_expected(before_ok, card_id, 2),
			card_id + ": the restored record resolves exactly one paid transaction")


## AC2: identical seeds and request sequences replay identically, with no RNG movement.
func _test_hem_seeded_replay() -> void:
	var first := _hem_replay(51842)
	var second := _hem_replay(51842)
	_check(first["results"].size() == 4, "seeded replay covers all four printings")
	_check(first == second, "same-seed replay produces an identical snapshot and receipts")
	_check(first["rng_state"] == second["rng_state"],
		"seeded replay consumes no run RNG at any step")
	_check(first["results"][0].get("ok") == true and first["results"][1].get("ok") == true
		and first["results"][2].get("ok") == true and first["results"][3].get("ok") == false,
		"seeded replay keeps three legal plays and the zero-energy refusal")
	_check(first["results"][3].get("reason") == "insufficient_energy",
		"seeded replay's last refusal is the spent-energy rejection")
	_check(first["hp"] == {"warden": 32, "tinker": 26, "seamstress": 26},
		"seeded replay lands the exact capped heals on the right heroes")
	_check(first["block"] == {"warden": 4, "tinker": 0, "seamstress": 10},
		"seeded replay grants the printed Block only to the chosen allies")
	_check(first["statuses"] == {"bleed": 2},
		"seeded replay invents no status and preserves the untouched map")
	_check(first["discard"] == [HEM, POULTICE_PLUS, HEM_PLUS],
		"seeded replay discards exactly the three paid copies in order")


func _hem_replay(seed_value: int) -> Dictionary:
	var service := V3SeamstressHemCards.new()
	# Real adjacent move: the Seamstress ends in the back seat 3, where both cards are legal.
	var party := _hem_party(3)
	_check(party.apply_damage(1, 12) and party.get_hero(1)["hp"] == 28,
		"replay fixture damages the front Warden to twenty-eight HP")
	_check(party.apply_damage(3, 9) and party.get_hero(3)["hp"] == 21,
		"replay fixture damages the back Seamstress to twenty-one HP")
	party._heroes[0]["statuses"] = {"bleed": 2}
	var deck := CombatDeck.new(
		[HEM, HEM_PLUS, POULTICE, POULTICE_PLUS, HEM_FILLERS[0]], _hem_rng(seed_value))
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.energy == 3,
		"replay deck starts the real five-draw three-energy turn")
	for card_id: String in HEM_CARD_IDS:
		_check(deck.hand.has(card_id), "replay fixture holds " + card_id)
	var results: Array = []
	results.append(service.play_card(deck, party, HEM, 3))
	results.append(service.play_card(deck, party, POULTICE_PLUS, 1))
	results.append(service.play_card(deck, party, HEM_PLUS, 3))
	results.append(service.play_card(deck, party, POULTICE, 1))
	var snapshot := _hem_snapshot(deck, party)
	snapshot["results"] = results
	snapshot["hp"] = {}
	snapshot["block"] = {}
	for index in range(1, CombatParty.PARTY_SIZE + 1):
		var hero: Dictionary = party.get_hero(index)
		snapshot["hp"][hero["id"]] = hero["hp"]
		snapshot["block"][hero["id"]] = hero["block"]
	snapshot["statuses"] = party.get_hero(1)["statuses"]
	return snapshot


func _hem_service_play(deck: CombatDeck, party: CombatParty, card_id: String,
		target_position: int) -> Dictionary:
	return V3SeamstressHemCards.new().play_card(deck, party, card_id, target_position)


func _hem_rejected(deck: CombatDeck, party: CombatParty, card_id: Variant, target_position: int,
		label: String) -> void:
	var before := _hem_snapshot(deck, party)
	var result: Dictionary = V3SeamstressHemCards.new().play_card(
		deck, party, card_id, target_position)
	_check(result.get("ok") == false, label + ": refused")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_hem_snapshot(deck, party) == before,
		label + ": unchanged party, hand, draw, discard, energy, turn and RNG")


## The single-transaction expected state: one energy, one discarded held copy, one Block and heal.
func _hem_expected(before: Dictionary, card_id: String, target_position: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 1
	expected["state_energy"] -= 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var hero: Dictionary = expected["heroes"][target_position - 1]
	hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + int(HEM_HEAL[card_id]))
	hero["block"] = int(hero["block"]) + int(HEM_BLOCK[card_id])
	return expected


func _hem_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
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


func _hem_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real five-card hand from six cards, so at least two copies of the named ID are held.
func _hem_deck(card_id: String, seed_value: int = 7312) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, HEM_FILLERS[0], HEM_FILLERS[1],
		HEM_FILLERS[2]]
	var deck := CombatDeck.new(ids, _hem_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == CombatState.TURN_ENERGY
		and deck.hand.size() == 5 and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holding duplicate copies")
	return deck


func _hem_hero_records() -> Array:
	if not _hem_records.is_empty():
		return _hem_records
	var raw: String = FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array and parsed.size() == CombatParty.PARTY_SIZE,
		"real authored starter party file supplies all three heroes")
	if not parsed is Array or parsed.size() != CombatParty.PARTY_SIZE:
		return []
	for record in parsed:
		var hero: Dictionary = record.duplicate(true)
		if hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
		_hem_records.append(hero)
	return _hem_records


func _hem_base_party() -> CombatParty:
	var definitions: Array = []
	for record: Dictionary in _hem_hero_records():
		definitions.append(record.duplicate(true))
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("max_hp") == 40 and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("max_hp") == 30 and party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("max_hp") == 26,
		"valid real CombatParty with the 40/30/26-HP Warden, Seamstress and Tinker")
	return party


## A valid three-distinct-hero party without the Seamstress, for the missing-owner refusal.
func _hem_party_without_owner() -> CombatParty:
	var definitions: Array = []
	for record: Dictionary in _hem_hero_records():
		if record.get("id") != "seamstress":
			definitions.append(record.duplicate(true))
	definitions.append({"id": "mender", "name": "Mender", "max_hp": 20})
	return CombatParty.new(definitions)


## A genuine adjacent swap through the real position rules puts the Seamstress in `seat`.
func _hem_party(seat: int) -> CombatParty:
	var party := _hem_base_party()
	if seat == 2:
		return party
	var move_id := "fixture_hem_shift"
	var moving := CombatDeck.new([move_id, move_id], _hem_rng(345))
	_check(moving.start_turn(), "hem seat fixture begins a legitimate shared turn")
	var direction := -1 if seat < 2 else 1
	var definition := {"id": move_id, "owner": "seamstress", "cost": 0,
		"from_positions": [1, 2, 3], "action_kind": "adjacent_swap", "direction": direction}
	_check(CombatPositionSwaps.play_move_card(moving, party, move_id, definition),
		"actual adjacent move shifts the Seamstress toward slot " + str(seat))
	_check(party.get_hero(seat).get("id") == "seamstress"
		and party.get_hero(seat).get("position") == seat,
		"Seamstress identity is really at actual slot " + str(seat))
	return party
