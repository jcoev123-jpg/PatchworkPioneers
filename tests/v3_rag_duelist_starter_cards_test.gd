extends SceneTree
## V3-1 Rag Duelist starter-card catalog contract.
## Catalog data only: no live party, hand, reward or combat resolution is assumed or claimed here.

const RagDuelistStarterCards = preload("res://data/cards/rag_duelist_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const RagDuelistPoolCards = preload("res://data/cards/rag_duelist_pool_cards.gd")

const BASE_IDS: Array[String] = [
	"rag_duelist_rapier_lunge",
	"rag_duelist_cape_parry",
	"rag_duelist_feather_feint",
	"rag_duelist_cape_slip",
]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_each_base_and_upgrade()
	_test_look_descriptors()
	_test_starter_projection()
	_test_detached_records()
	_test_invalid_and_malformed_ids()
	_test_deterministic_and_rng_free()
	_test_existing_catalogs_unchanged()
	if failures.is_empty():
		print("v3_rag_duelist_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_rag_duelist_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Literal, independent expectations for each of the four authored base/"+" pairs.
func _cases() -> Dictionary:
	return {
		"rag_duelist_rapier_lunge": {
			"name": "Rapier Lunge", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 5, "move_self_forward": 1},
			"plus_cost": 1, "plus_effects": {"damage": 7, "move_self_forward": 1}},
		"rag_duelist_cape_parry": {
			"name": "Cape Parry", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block": 4, "riposte": 2, "duration": 1},
			"plus_cost": 1, "plus_effects": {"block": 6, "riposte": 3, "duration": 1}},
		"rag_duelist_feather_feint": {
			"name": "Feather Feint", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"exposed": 1, "draw": 1},
			"plus_cost": 0, "plus_effects": {"exposed": 1, "draw": 1}},
		"rag_duelist_cape_slip": {
			"name": "Cape Slip", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"dodge_next_attack": 1, "duration": 1},
			"plus_cost": 0, "plus_effects": {"dodge_next_attack": 1, "duration": 1}},
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
		"starting_copies": 0 if upgraded else 1,
		"rarity": "starter",
		"reward_eligible": false,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


## Every named base and its "+" record, field by field, against the independent case dictionary.
func _test_each_base_and_upgrade() -> void:
	var catalog := RagDuelistStarterCards.new()
	var cases: Dictionary = _cases()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(BASE_IDS.size() == 4 and cases.size() == 4, "four named starter pairs are exercised")
	for base_id: String in BASE_IDS:
		_check(cases.has(base_id), base_id + " has an independent expectation")
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(base_ids.count(base_id) == 1, base_id + " is listed once as a base")
		_check(not base_ids.has(plus_id), plus_id + " is not listed as a base")
		_check(catalog.has_card(base_id), base_id + " is authored")
		_check(catalog.has_card(plus_id), plus_id + " is authored")
		_check(all_ids.has(base_id) and all_ids.has(plus_id),
			base_id + " base and upgrade are both discoverable")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + "_plus is not authored")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
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
			_check(record.get("effects") is Dictionary, card_id + " has an effect dictionary")
			_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
				and record.get("reward_eligible") == false, card_id + " is never reward eligible")
			_check(record.get("rarity") == "starter", card_id + " is a starter rarity")
			_check(record.get("owner") == "rag_duelist", card_id + " belongs to Rag Duelist")
			_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
				card_id + " references its own base art path")
			for position: Variant in record.get("from_positions"):
				_check(position >= 1 and position <= 3, card_id + " FROM stays in the 1-3 line")
			for position: Variant in record.get("to_positions"):
				_check(position >= 1 and position <= 3, card_id + " TO stays in the 1-3 line")
		_check(catalog.get_definition(base_id).get("starting_copies") == 1,
			base_id + " starts with one copy")
		_check(catalog.get_definition(plus_id).get("starting_copies") == 0,
			plus_id + " adds no starting copy")
		_check(not catalog.get_definition(base_id).has("upgrade_of"),
			base_id + " is not itself an upgrade")
		_check(not catalog.get_definition(plus_id).has("upgrade_id"),
			plus_id + " has no onward upgrade link")
		_check(catalog.get_definition(base_id).get("illustration_path")
			== catalog.get_definition(plus_id).get("illustration_path"),
			base_id + " base and upgrade share one illustration path")
	for id: String in base_ids:
		_check(BASE_IDS.has(id), id + " in get_base_ids is one of the four named bases")
	for id: String in all_ids:
		_check(BASE_IDS.has(id) or BASE_IDS.has(id.trim_suffix("_plus")),
			id + " belongs to one of the four named pairs")


## The printed look descriptors: one-slot Lunge, one-turn Riposte, Feint draw and next-attack dodge.
## Presence and exact author-specified magnitudes only; nothing here claims live combat resolution.
func _test_look_descriptors() -> void:
	var catalog := RagDuelistStarterCards.new()
	for suffix: String in ["", "_plus"]:
		var lunge: Dictionary = catalog.get_definition("rag_duelist_rapier_lunge" + suffix)
		var lunge_effects: Dictionary = lunge.get("effects", {})
		_check(lunge_effects.get("move_self_forward") == 1
			and typeof(lunge_effects.get("move_self_forward")) == TYPE_INT,
			"Rapier Lunge moves its owner exactly one slot" + suffix)
		_check(lunge_effects.get("damage") == (7 if suffix == "_plus" else 5),
			"Rapier Lunge keeps its needle thrust damage" + suffix)
		for start: Variant in lunge.get("from_positions", []):
			_check(lunge.get("to_positions", []).has(int(start) - 1),
				"Rapier Lunge's only forward slot from " + str(start) + " is legal" + suffix)
		_check(lunge.get("target_kind") == "enemy_single",
			"Rapier Lunge strikes one enemy" + suffix)

		var parry: Dictionary = catalog.get_definition("rag_duelist_cape_parry" + suffix)
		var parry_effects: Dictionary = parry.get("effects", {})
		_check(parry_effects.get("block") == (6 if suffix == "_plus" else 4),
			"Cape Parry blocks with its tattered cape" + suffix)
		_check(parry_effects.get("riposte") == (3 if suffix == "_plus" else 2),
			"Cape Parry grants its counterstrike value" + suffix)
		_check(parry_effects.get("duration") == 1,
			"Cape Parry's Riposte lasts exactly one turn" + suffix)
		_check(parry.get("target_kind") == "self" and parry.get("to_positions") == [],
			"Cape Parry targets its wearer only" + suffix)

		var feint: Dictionary = catalog.get_definition("rag_duelist_feather_feint" + suffix)
		var feint_effects: Dictionary = feint.get("effects", {})
		_check(feint_effects.get("exposed") == 1, "Feather Feint exposes its foe" + suffix)
		_check(feint_effects.get("draw") == 1, "Feather Feint draws one shared-hand card" + suffix)
		_check(feint.get("cost") == (0 if suffix == "_plus" else 1),
			"Feather Feint keeps its authored cost" + suffix)
		_check(feint.get("target_kind") == "enemy_single",
			"Feather Feint opens one enemy" + suffix)
		_check(feint.get("from_positions") == [1, 2] and feint.get("to_positions") == [1, 2, 3],
			"Feather Feint keeps its author-specified positions" + suffix)

		var slip: Dictionary = catalog.get_definition("rag_duelist_cape_slip" + suffix)
		var slip_effects: Dictionary = slip.get("effects", {})
		_check(slip_effects.get("dodge_next_attack") == 1,
			"Cape Slip dodges the next incoming attack" + suffix)
		_check(slip_effects.get("duration") == 1,
			"Cape Slip's dodge lasts exactly one turn" + suffix)
		_check(slip_effects.size() == 2 and not slip_effects.has("block"),
			"Cape Slip is not permanent immunity or Block" + suffix)
		_check(slip.get("target_kind") == "self" and slip.get("to_positions") == [],
			"Cape Slip targets its wearer only" + suffix)

	_check(catalog.get_definition("rag_duelist_rapier_lunge_plus").get("cost") == 1,
		"Rapier Lunge+ still costs one")
	_check(catalog.get_definition("rag_duelist_cape_parry_plus").get("cost") == 1,
		"Cape Parry+ still costs one")
	_check(catalog.get_definition("rag_duelist_feather_feint_plus").get("cost") == 0,
		"Feather Feint+ is free")
	_check(catalog.get_definition("rag_duelist_cape_slip_plus").get("cost") == 0,
		"Cape Slip+ is free")


## The dedicated hero projection: each named base exactly once, never an upgrade.
## No global catalog size or ordering premise; the active three-hero deck is checked separately.
func _test_starter_projection() -> void:
	var catalog := RagDuelistStarterCards.new()
	var cases: Dictionary = _cases()
	var deck: Array[String] = catalog.get_starting_deck()
	_check(not deck.is_empty(), "starter projection is populated before counting")
	for base_id: String in BASE_IDS:
		var plus_id: String = base_id + "_plus"
		_check(deck.count(base_id) == 1, base_id + " appears once in the dedicated starting deck")
		_check(not deck.has(plus_id), plus_id + " is not in the dedicated starting deck")
	for id: String in deck:
		_check(cases.has(id), id + " in the dedicated deck is one of the four authored bases")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(first_deck == second_deck, "two starting-deck calls agree")
	_check(first_deck.count("rag_duelist_rapier_lunge") == 1
		and catalog.get_starting_deck().count("rag_duelist_rapier_lunge") == 1,
		"repeated calls keep one copy of each base")


func _test_detached_records() -> void:
	var catalog := RagDuelistStarterCards.new()
	var sample: Dictionary = catalog.get_definition("rag_duelist_rapier_lunge")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["move_self_forward"] = 9
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["starting_copies"] = 99
	var pristine: Dictionary = catalog.get_definition("rag_duelist_rapier_lunge")
	_check(pristine.get("effects") == {"damage": 5, "move_self_forward": 1},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [2, 3], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2], "TO arrays are deeply detached")
	_check(pristine.get("id") == "rag_duelist_rapier_lunge", "metadata is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")

	var upgraded: Dictionary = catalog.get_definition("rag_duelist_cape_parry_plus")
	upgraded["effects"]["block"] = 900
	upgraded["effects"]["riposte"] = 900
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	upgraded["upgrade_of"] = "rag_duelist_cape_slip"
	var upgraded_pristine: Dictionary = catalog.get_definition("rag_duelist_cape_parry_plus")
	_check(upgraded_pristine.get("effects") == {"block": 6, "riposte": 3, "duration": 1},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [1, 2, 3], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [], "empty upgrade TO array is detached")
	_check(upgraded_pristine.get("upgrade_of") == "rag_duelist_cape_parry",
		"upgrade link is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	_check(base_ids.has("rag_duelist_cape_slip") and all_ids.has("rag_duelist_cape_slip_plus")
		and deck.has("rag_duelist_feather_feint"), "projections are populated before mutation")
	base_ids.clear()
	base_ids.append("forged_starter")
	all_ids.clear()
	deck.clear()
	_check(catalog.get_base_ids().has("rag_duelist_cape_slip"),
		"get_base_ids returns a fresh array")
	_check(catalog.get_all_card_ids().has("rag_duelist_cape_parry_plus"),
		"get_all_card_ids returns a fresh array")
	_check(catalog.get_starting_deck().has("rag_duelist_feather_feint"),
		"get_starting_deck returns a fresh array")
	_check(not catalog.get_base_ids().has("forged_starter"),
		"mutated base id array leaks nothing")
	_check(RagDuelistStarterCards.new().get_definition("rag_duelist_rapier_lunge") == pristine,
		"a fresh instance retains the canonical definition")


func _test_invalid_and_malformed_ids() -> void:
	var catalog := RagDuelistStarterCards.new()
	var pool := RagDuelistPoolCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("rag_duelist_cape_slip"),
		"", "rag_duelist_not_a_card", "rag_duelist_", "rag_duelist_cape_slip+",
		"rag_duelist_cape_slip_plus_plus", "rag_duelist_rapier_lunge_plus_plus",
		"RAG_DUELIST_CAPE_SLIP", " rag_duelist_cape_slip", "rag_duelist_cape_slip "]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(),
			"invalid id returns no definition: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))
	# Upgraded records exist but are terminal: no second upgrade, no starter membership.
	for base_id: String in BASE_IDS:
		var plus_id: String = base_id + "_plus"
		var plus_record: Dictionary = catalog.get_definition(plus_id)
		_check(not plus_record.is_empty(), plus_id + " is a real record")
		_check(plus_record.get("upgrade_of") == base_id, plus_id + " points back to its base")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(catalog.get_definition(catalog.get_upgrade_id(plus_id)).is_empty(),
			plus_id + " resolves no second definition")
		_check(not catalog.get_starting_deck().has(plus_id),
			plus_id + " is not proposed as a starter")
	# The reward catalog's IDs are not Rag Duelist starters, and vice versa.
	for pool_id: String in pool.get_all_card_ids():
		_check(not catalog.has_card(pool_id), pool_id + " is not a Rag Duelist starter")
	_check(pool.has_card("rag_duelist_needle_lunge")
		and not catalog.has_card("rag_duelist_needle_lunge"),
		"Needle Lunge stays a reward card, not a starter")
	_check(pool.has_card("rag_duelist_cape_flourish")
		and not catalog.has_card("rag_duelist_cape_flourish"),
		"Cape Flourish stays a reward card, not a starter")


func _test_deterministic_and_rng_free() -> void:
	var control := RandomNumberGenerator.new()
	control.seed = 20261026
	var expected_next: int = control.randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var before: int = rng.state
	var catalog := RagDuelistStarterCards.new()
	var first_ids: Array[String] = catalog.get_all_card_ids()
	var first_bases: Array[String] = catalog.get_base_ids()
	var first_deck: Array[String] = catalog.get_starting_deck()
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		catalog.get_definition(base_id)
		catalog.get_definition(base_id + "_plus")
		catalog.has_card(base_id)
		catalog.has_card(base_id + "_plus")
		catalog.get_upgrade_id(base_id)
		catalog.get_upgrade_id(base_id + "_plus")
	var second := RagDuelistStarterCards.new()
	_check(first_ids == second.get_all_card_ids(), "catalog enumeration is deterministic")
	_check(first_bases == second.get_base_ids(), "base enumeration is deterministic")
	_check(first_deck == second.get_starting_deck(), "starting-deck projection is deterministic")
	_check(first_ids == catalog.get_all_card_ids(), "repeated enumeration is stable")
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(rng.randi() == expected_next,
		"the next seeded random value is identical with and without catalog calls")
	_check(catalog.get_definition("rag_duelist_cape_slip").get("effects")
		== {"dodge_next_attack": 1, "duration": 1}, "lookups leave the catalog pristine")


## Existing shared catalogs stay exactly as authored; the new starters stay out of the shared deck.
func _test_existing_catalogs_unchanged() -> void:
	var starter := StarterCards.new()
	var pool := RagDuelistPoolCards.new()
	var yard := RagDuelistStarterCards.new()
	var needle_lunge: Dictionary = pool.get_definition("rag_duelist_needle_lunge")
	_check(not needle_lunge.is_empty(), "Rag Duelist reward needle_lunge remains authored")
	_check(needle_lunge.get("effects") == {"damage": 6, "move_self_forward": 1},
		"needle_lunge keeps six damage and one forward slot")
	var cape_guard: Dictionary = pool.get_definition("rag_duelist_cape_guard")
	_check(not cape_guard.is_empty(), "Rag Duelist reward cape_guard remains authored")
	_check(cape_guard.get("effects") == {"block": 5, "riposte": 3, "duration": 1},
		"cape_guard keeps five Block, Riposte three and one-turn duration")
	var warden_strike: Dictionary = starter.get_definition("warden_strike")
	_check(not warden_strike.is_empty(), "warden_strike remains authored")
	_check(warden_strike.get("effects") == {"damage": 6}, "warden_strike stays six damage")
	_check(warden_strike.get("starting_copies") == 2, "warden_strike keeps two copies")
	var prick: Dictionary = starter.get_definition("seamstress_prick")
	_check(not prick.is_empty(), "seamstress_prick remains authored")
	_check(prick.get("effects") == {"damage": 3, "bleed": 2}, "seamstress_prick keeps bleed two")
	_check(prick.get("starting_copies") == 2, "seamstress_prick keeps two copies")
	var active_deck: Array[String] = starter.get_starting_deck()
	_check(active_deck.has("warden_strike") and active_deck.has("seamstress_prick")
		and active_deck.has("tinker_pop_shot"), "active three-hero deck keeps its representatives")
	var raw_json: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored_deck: Variant = JSON.parse_string(raw_json)
	_check(authored_deck is Array, "authored starter deck parses")
	if authored_deck is Array:
		_check(active_deck == authored_deck,
			"active three-hero starting deck still matches its authored membership and order")
	for base_id: String in BASE_IDS:
		var plus_id: String = base_id + "_plus"
		_check(not starter.has_card(base_id) and not starter.has_card(plus_id),
			base_id + " has not entered StarterCards")
		_check(not active_deck.has(base_id) and not active_deck.has(plus_id),
			base_id + " is absent from the active starting deck")
		if authored_deck is Array:
			_check(not authored_deck.has(base_id) and not authored_deck.has(plus_id),
				base_id + " is absent from the authored starter deck")
		_check(not pool.has_card(base_id) and not pool.has_card(plus_id),
			base_id + " has not entered the Rag Duelist reward pool")
		_check(yard.get_definition(base_id).get("reward_eligible") == false
			and yard.get_definition(plus_id).get("reward_eligible") == false,
			base_id + " pair is never reward eligible")
