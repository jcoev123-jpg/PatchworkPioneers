extends SceneTree
## V3-1 Lantern Monk starter-card catalog contract.
## Catalog contracts and scene-free Pole Shelter and blind-strike transactions; live hand wiring is separate.

const LanternMonkStarterCards = preload("res://data/cards/lantern_monk_starter_cards.gd")
const LanternMonkPoolCards = preload("res://data/cards/lantern_monk_pool_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")

class ForgedShelter extends CombatLanternMonkPoleShelterCards:
	var forged: Dictionary = {}
	func _catalog_definition(_id: String) -> Dictionary:
		return forged.duplicate(true)

## Catalog seam double for the single-target blind strikes: one rewritten printing must never be paid for, and the
## restored authentic pair still plays.
class ForgedBlindStrike extends CombatLanternMonkBlindStrikeCards:
	var forged_id: String = ""
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		if card_id == forged_id:
			return forged.duplicate(true)
		return super(card_id)

var failures: Array[String] = []
var checks: int = 0
var strike_service := CombatLanternMonkBlindStrikeCards.new()


func _initialize() -> void:
	_test_each_base_and_upgrade()
	_test_look_descriptors()
	_test_starter_projection()
	_test_detached_records()
	_test_invalid_and_upgraded_ids()
	_test_deterministic_and_rng_free()
	_test_existing_catalogs_unchanged()
	_test_paid_shelter()
	_test_shelter_refusals()
	_test_blind_strike_catalog()
	_test_blind_strike_paid_play()
	_test_blind_strike_refusals()
	_test_blind_strike_enemy_phase()
	if failures.is_empty():
		print("v3_lantern_monk_starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_lantern_monk_starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Literal, independent expectations for each of the four authored base/"+" pairs.
func _cases() -> Dictionary:
	return {
		"lantern_monk_wick_spark": {
			"name": "Wick Spark", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 4, "blind": 1},
			"plus_cost": 1, "plus_effects": {"damage": 6, "blind": 1}},
		"lantern_monk_moth_wink": {
			"name": "Moth Wink", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"blind": 1, "draw": 1},
			"plus_cost": 0, "plus_effects": {"blind": 1, "draw": 1}},
		"lantern_monk_lamplight_wash": {
			"name": "Lamplight Wash", "cost": 2,
			"from": [2, 3], "target": "party_all", "to": [],
			"effects": {"heal": 2, "cleanse_debuff": 1},
			"plus_cost": 2, "plus_effects": {"heal": 3, "cleanse_debuff": 1}},
		"lantern_monk_pole_shelter": {
			"name": "Pole Shelter", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 5, "cleanse_debuff": 1},
			"plus_cost": 1, "plus_effects": {"block": 7, "cleanse_debuff": 1}},
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
		"starting_copies": 0 if upgraded else 1,
		"reward_eligible": false,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


func _shelter_fixture(id: String, owner_position: int = 2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 316027
	var deck := CombatDeck.new([id, id, "warden_strike", "tinker_pop_shot"], rng)
	_check(deck.start_turn() and deck.hand.count(id) == 2, "active real hand holds two copies")
	var definitions: Array = []
	for position in range(1, 4):
		definitions.append({"id": "lantern_monk" if position == owner_position else "ally_%d" % position,
			"max_hp": 30, "statuses": {"tangled": 2, "riposte": 3}})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and not party.is_downed(owner_position), "real living three-hero party")
	return {"deck": deck, "party": party, "rng": rng}


func _shelter_snapshot(f: Dictionary) -> Array:
	return [f.deck.hand.duplicate(), f.deck.draw_pile.duplicate(), f.deck.discard_pile.duplicate(),
		f.deck.energy, f.deck.turn_active, f.party.get_heroes(), f.rng.state]


func _test_paid_shelter() -> void:
	var resolver := CombatLanternMonkPoleShelterCards.new()
	for suffix: String in ["", "_plus"]:
		var id := "lantern_monk_pole_shelter" + suffix
		for owner_position in range(1, 4):
			for target in [owner_position, owner_position % 3 + 1]:
				for selection: String in ["bleed", "weak", "exposed", ""]:
					var f := _shelter_fixture(id, owner_position)
					var party: CombatParty = f.party
					var deck: CombatDeck = f.deck
					if selection != "":
						party._heroes[target - 1].statuses.merge({"bleed": 4, "weak": 2, "exposed": 3})
					_check(party.gain_block(target, 2), "pre-existing Block applied")
					var expected := party.get_heroes()
					var amount := 5 if suffix == "" else 7
					expected[target - 1].block += amount
					var cleared: int = expected[target - 1].statuses.get(selection, 0)
					expected[target - 1].statuses.erase(selection)
					var hand := deck.hand.duplicate()
					hand.remove_at(hand.find(id))
					var energy := deck.energy
					var rng_before: int = f.rng.state
					var draw := deck.draw_pile.duplicate()
					var receipt := resolver.play_card(deck, party, id, target, selection)
					_check(receipt.get("ok", false), "authentic paid Shelter succeeds")
					_check(receipt.get("owner_position") == owner_position and receipt.get("target_position") == target
						and receipt.get("block") == amount and receipt.get("cleansed_count") == cleared,
						"receipt identifies exact owner, target, Block and cleared counter")
					_check(deck.energy == energy - 1 and deck.hand == hand and deck.hand.count(id) == 1
						and deck.discard_pile == [id] and deck.draw_pile == draw and deck.turn_active,
						"one energy and one held copy paid, other deck state preserved")
					_check(party.get_heroes() == expected, "only target Block and selected kind change; HP, allies and other statuses preserved")
					_check(f.rng.state == rng_before, "paid play consumes no run RNG")


func _test_shelter_refusals() -> void:
	var id := "lantern_monk_pole_shelter"
	var resolver := CombatLanternMonkPoleShelterCards.new()
	for scenario: String in ["energy", "hand", "inactive", "target_zero", "target_four", "target_downed",
		"owner_downed", "owner_missing", "duplicate_owner", "cleanse_empty", "cleanse_missing",
		"cleanse_tangled", "cleanse_benefit", "cleanse_type", "unsupported", "id_type", "overflow", "statuses"]:
		var f := _shelter_fixture(id)
		var target := 1
		var selection: Variant = "bleed"
		var request: Variant = id
		f.party._heroes[0].statuses.merge({"bleed": 4, "weak": 2})
		match scenario:
			"energy": f.deck.try_spend_energy(f.deck.energy)
			"hand": f.deck.hand.clear()
			"inactive": f.deck.end_turn()
			"target_zero": target = 0
			"target_four": target = 4
			"target_downed": f.party.apply_damage(1, 30)
			"owner_downed": f.party.apply_damage(2, 30)
			"owner_missing": f.party._heroes[1].id = "other"
			"duplicate_owner": f.party._heroes[2].id = "lantern_monk"
			"cleanse_empty": selection = ""
			"cleanse_missing": selection = "exposed"
			"cleanse_tangled": selection = "tangled"
			"cleanse_benefit": selection = "riposte"
			"cleanse_type": selection = StringName("bleed")
			"unsupported": request = "lantern_monk_lamplight_wash"
			"id_type": request = StringName(id)
			"overflow": f.party._heroes[0].block = CombatParty.MAX_INT - 4
			"statuses": f.party._heroes[0].statuses = {"bleed": -1}
		var before := _shelter_snapshot(f)
		_check(not resolver.play_card(f.deck, f.party, request, target, selection).get("ok", false), scenario + " refuses")
		_check(_shelter_snapshot(f) == before, scenario + " leaves full deck, party and RNG unchanged")
		if scenario.begins_with("cleanse") or scenario in ["target_zero", "target_four", "unsupported", "id_type"]:
			_check(resolver.play_card(f.deck, f.party, id, 1, "bleed").get("ok", false), "valid retry after " + scenario)
	var empty := _shelter_fixture(id)
	var empty_before := _shelter_snapshot(empty)
	_check(not resolver.play_card(empty.deck, empty.party, id, 1, "bleed").ok, "cannot name absent debuff")
	_check(_shelter_snapshot(empty) == empty_before, "absent cleanse rejection inert")
	_check(resolver.play_card(empty.deck, empty.party, id, 1, "").ok, "empty selection valid retry without eligible statuses")
	for suffix: String in ["", "_plus"]:
		var card_id := id + suffix
		var authentic := LanternMonkStarterCards.new().get_definition(card_id)
		var mutations: Array = []
		for field in ["id", "owner", "cost", "from_positions", "to_positions", "target_kind", "effects", "upgrade_of" if suffix != "" else "upgrade_id", "reward_eligible", "starting_copies"]:
			var omitted := authentic.duplicate(true)
			omitted.erase(field)
			mutations.append(omitted)
			var altered := authentic.duplicate(true)
			altered[field] = {"id": "fake", "owner": "warden", "cost": 1.0, "from_positions": [1, 2],
				"to_positions": [1], "target_kind": "party_all", "effects": {"block": 99, "cleanse_debuff": 1},
				"upgrade_id": "fake", "upgrade_of": "fake", "reward_eligible": true, "starting_copies": 9}[field]
			mutations.append(altered)
		var extra := authentic.duplicate(true)
		extra.effects["heal"] = 1
		mutations.append(extra)
		var typed := authentic.duplicate(true)
		typed.effects.block = float(typed.effects.block)
		mutations.append(typed)
		var relinked := authentic.duplicate(true)
		relinked["upgrade_id" if suffix != "" else "upgrade_of"] = "fake"
		mutations.append(relinked)
		var forged_resolver := ForgedShelter.new()
		var f := _shelter_fixture(card_id)
		for forged: Dictionary in mutations:
			forged_resolver.forged = forged
			var before := _shelter_snapshot(f)
			_check(not forged_resolver.play_card(f.deck, f.party, card_id, 1).ok, "forged catalog rejected")
			_check(_shelter_snapshot(f) == before and forged_resolver.forged == forged, "forgery rejection leaves inputs and all state unchanged")
		forged_resolver.forged = authentic
		_check(forged_resolver.play_card(f.deck, f.party, card_id, 1).ok, "restored authentic catalog retries successfully")


func _test_each_base_and_upgrade() -> void:
	var catalog := LanternMonkStarterCards.new()
	var cases: Dictionary = _cases()
	_check(cases.size() == 4, "exactly four authored base cases are enumerated")
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(catalog.has_card(base_id), base_id + " is authored")
		_check(catalog.has_card(plus_id), plus_id + " is authored")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		_check(not catalog.has_card(plus_id + "_plus"), plus_id + "_plus is not authored")
		_check(base_id.begins_with("lantern_monk_"), base_id + " carries the hero prefix")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("owner") == "lantern_monk", card_id + " is owned by lantern_monk")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has an effect dictionary")
			_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
				and record.get("reward_eligible") == false, card_id + " is never reward eligible")
			_check(not record.has("rarity"), card_id + " carries no reward rarity")
			_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
				card_id + " shares its base illustration path")
			var effects: Dictionary = record.get("effects")
			_check(effects.size() == expected["effects"].size(),
				card_id + " prints exactly the documented effects")
			for key: String in expected["effects"]:
				_check(typeof(effects.get(key)) == TYPE_INT,
					card_id + " effect " + key + " is an integer magnitude")
			_check(not effects.has("bleed") and not effects.has("weak")
				and not effects.has("exposed"),
				card_id + " applies no damaging or weakening debuff of its own")
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


## The printed look descriptors: Blind, a shared-hand draw, party healing with a cleanse,
## and an ally shield with a cleanse. Presence and exact magnitudes only; no live resolution claim.
func _test_look_descriptors() -> void:
	var catalog := LanternMonkStarterCards.new()
	for suffix: String in ["", "_plus"]:
		var spark: Dictionary = catalog.get_definition("lantern_monk_wick_spark" + suffix)
		_check(spark.get("effects").has("blind"), "Wick Spark prints blind" + suffix)
		_check(spark.get("target_kind") == "enemy_single", "Wick Spark targets one enemy" + suffix)
		var wink: Dictionary = catalog.get_definition("lantern_monk_moth_wink" + suffix)
		_check(wink.get("effects") == {"blind": 1, "draw": 1},
			"Moth Wink prints blind one plus a shared-hand draw" + suffix)
		_check(wink.get("from_positions") == [1, 2, 3] and wink.get("to_positions") == [1, 2, 3],
			"Moth Wink reaches one enemy from any slot" + suffix)
		_check(not wink.get("effects").has("damage"),
			"Moth Wink is not plain damage" + suffix)
		var wash: Dictionary = catalog.get_definition("lantern_monk_lamplight_wash" + suffix)
		_check(wash.get("target_kind") == "party_all" and wash.get("to_positions") == [],
			"Lamplight Wash reaches the whole party without a slot target" + suffix)
		_check(wash.get("effects").has("heal") and wash.get("effects").has("cleanse_debuff"),
			"Lamplight Wash prints healing plus one debuff cleanse" + suffix)
		var shelter: Dictionary = catalog.get_definition("lantern_monk_pole_shelter" + suffix)
		_check(shelter.get("target_kind") == "ally_single" and shelter.get("to_positions") == [],
			"Pole Shelter shields one living ally" + suffix)
		_check(shelter.get("effects").has("block") and shelter.get("effects").has("cleanse_debuff"),
			"Pole Shelter prints block plus one debuff cleanse" + suffix)
		_check(shelter.get("effects").size() == 2,
			"Pole Shelter prints no extra effect" + suffix)
	_check(catalog.get_definition("lantern_monk_moth_wink_plus").get("cost") == 0,
		"Moth Wink+ is free")
	_check(catalog.get_definition("lantern_monk_wick_spark").get("effects").get("blind") == 1
		and catalog.get_definition("lantern_monk_wick_spark_plus").get("effects").get("blind") == 1,
		"Wick Spark Blinds one on base and upgrade")
	_check(catalog.get_definition("lantern_monk_wick_spark").get("effects").get("damage") == 4
		and catalog.get_definition("lantern_monk_wick_spark_plus").get("effects").get("damage") == 6,
		"Wick Spark damage is four then six")
	_check(catalog.get_definition("lantern_monk_lamplight_wash").get("effects").get("heal") == 2
		and catalog.get_definition("lantern_monk_lamplight_wash_plus").get("effects").get("heal") == 3,
		"Lamplight Wash heals two then three")
	_check(catalog.get_definition("lantern_monk_pole_shelter").get("effects").get("block") == 5
		and catalog.get_definition("lantern_monk_pole_shelter_plus").get("effects").get("block") == 7,
		"Pole Shelter Block is five then seven")
	_check(catalog.get_definition("lantern_monk_lamplight_wash").get("cost") == 2
		and catalog.get_definition("lantern_monk_lamplight_wash_plus").get("cost") == 2,
		"Lamplight Wash stays at two energy when upgraded")
	# The cleanse belongs only to the two lantern-light support cards, one present debuff each.
	for base_id: String in ["lantern_monk_wick_spark", "lantern_monk_moth_wink"]:
		_check(not catalog.get_definition(base_id).get("effects").has("cleanse_debuff"),
			base_id + " does not cleanse anything")
	for base_id: String in ["lantern_monk_lamplight_wash", "lantern_monk_pole_shelter"]:
		_check(catalog.get_definition(base_id).get("effects").get("cleanse_debuff") == 1
			and catalog.get_definition(base_id + "_plus").get("effects").get("cleanse_debuff") == 1,
			base_id + " cleanses exactly one present debuff on base and upgrade")


## The dedicated hero projection: each named base exactly once, never an upgrade.
## No global catalog size or ordering premise; the active three-hero deck is checked separately.
func _test_starter_projection() -> void:
	var catalog := LanternMonkStarterCards.new()
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
	_check(starter_ids == deck, "starter ids and dedicated starting deck agree")
	var all_ids: Array[String] = catalog.get_all_card_ids()
	for id: String in all_ids:
		_check(cases.has(id) or cases.has(id.trim_suffix("_plus")),
			id + " belongs to one of the four authored pairs")
		_check(catalog.has_card(id), id + " is discoverable through has_card")
	for base_id: String in cases:
		_check(all_ids.has(base_id) and all_ids.has(base_id + "_plus"),
			base_id + " base and upgrade are both discoverable")


func _test_detached_records() -> void:
	var catalog := LanternMonkStarterCards.new()
	var sample: Dictionary = catalog.get_definition("lantern_monk_wick_spark")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["blind"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	sample["starting_copies"] = 99
	var pristine: Dictionary = catalog.get_definition("lantern_monk_wick_spark")
	_check(pristine.get("effects") == {"damage": 4, "blind": 1},
		"effects are deeply detached from the catalog")
	_check(pristine.get("from_positions") == [2, 3], "FROM arrays are deeply detached")
	_check(pristine.get("to_positions") == [1, 2, 3], "TO arrays are deeply detached")
	_check(pristine.get("id") == "lantern_monk_wick_spark", "metadata is detached")
	_check(pristine.get("starting_copies") == 1, "copy count is detached")
	var upgraded: Dictionary = catalog.get_definition("lantern_monk_lamplight_wash_plus")
	upgraded["effects"]["heal"] = 900
	upgraded["from_positions"].append(900)
	upgraded["to_positions"].append(900)
	var upgraded_pristine: Dictionary = catalog.get_definition("lantern_monk_lamplight_wash_plus")
	_check(upgraded_pristine.get("effects") == {"heal": 3, "cleanse_debuff": 1},
		"upgrade effects are detached")
	_check(upgraded_pristine.get("from_positions") == [2, 3], "upgrade FROM is detached")
	_check(upgraded_pristine.get("to_positions") == [], "empty upgrade TO array is detached")
	_check(not upgraded_pristine.get("to_positions").has(900), "empty upgrade TO repopulates empty")
	var starter_ids: Array[String] = catalog.get_starter_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(starter_ids.has("lantern_monk_moth_wink") and deck.has("lantern_monk_pole_shelter"),
		"projections are populated before mutation")
	starter_ids.clear()
	starter_ids.append("forged_starter")
	deck.clear()
	all_ids.clear()
	_check(catalog.get_starter_ids().has("lantern_monk_moth_wink"),
		"get_starter_ids returns a fresh array")
	_check(catalog.get_starting_deck().has("lantern_monk_pole_shelter"),
		"get_starting_deck returns a fresh array")
	_check(catalog.get_all_card_ids().has("lantern_monk_wick_spark_plus"),
		"get_all_card_ids returns a fresh array")
	_check(not catalog.get_starter_ids().has("forged_starter"),
		"mutated starter id array leaks nothing")
	var first_deck: Array[String] = catalog.get_starting_deck()
	var second_deck: Array[String] = catalog.get_starting_deck()
	_check(first_deck == second_deck and first_deck.size() == second_deck.size(),
		"two starting-deck calls agree")
	if not first_deck.is_empty():
		first_deck[0] = "mutated_first"
	_check(second_deck.count("lantern_monk_wick_spark") == 1
		and catalog.get_starting_deck().count("lantern_monk_wick_spark") == 1,
		"each base starter contributes exactly one copy")
	_check(LanternMonkStarterCards.new().get_definition("lantern_monk_wick_spark") == pristine,
		"a fresh instance retains the canonical definition")


func _test_invalid_and_upgraded_ids() -> void:
	var catalog := LanternMonkStarterCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("lantern_monk_wick_spark"),
		"", "lantern_monk_not_a_card", "lantern_monk_wick_spark+", "forged_starter",
		"lantern_monk_wick_spark_plus_plus", "lantern_monk_pole_shelter_plus_plus",
		"wick_spark", "yarn_ranger_needle_nock", "warden_strike"]
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
		_check(not catalog.get_starter_ids().has(plus_id),
			plus_id + " is not proposed as a starter")
		_check(not catalog.get_starting_deck().has(plus_id),
			plus_id + " is not proposed in the dedicated deck")
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(12) == ""
		and catalog.get_upgrade_id("") == "", "get_upgrade_id fails closed")


func _test_deterministic_and_rng_free() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var before: int = rng.state
	var catalog := LanternMonkStarterCards.new()
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
	var second := LanternMonkStarterCards.new()
	_check(first_ids == second.get_all_card_ids(), "catalog enumeration is deterministic")
	_check(first_starters == second.get_starter_ids(), "starter enumeration is deterministic")
	_check(first_deck == second.get_starting_deck(), "starting-deck projection is deterministic")
	_check(first_ids == catalog.get_all_card_ids(), "repeated enumeration is stable")
	_check(rng.state == before, "catalog construction and lookups consume no seeded RNG draws")
	_check(catalog.get_definition("lantern_monk_wick_spark").get("effects")
		== {"damage": 4, "blind": 1}, "lookups leave the catalog pristine")
	_check(rng.state == before, "a second lookup window also consumes no seeded RNG draws")


## Existing shared catalogs stay exactly as authored; the new starters stay out of the live deck.
func _test_existing_catalogs_unchanged() -> void:
	var starter := StarterCards.new()
	var monk := LanternMonkStarterCards.new()
	var warden_strike: Dictionary = starter.get_definition("warden_strike")
	_check(not warden_strike.is_empty(), "warden_strike remains authored")
	_check(warden_strike.get("effects") == {"damage": 6}, "warden_strike stays six damage")
	_check(warden_strike.get("starting_copies") == 2, "warden_strike keeps two copies")
	var prick: Dictionary = starter.get_definition("seamstress_prick")
	_check(not prick.is_empty(), "seamstress_prick remains authored")
	_check(prick.get("effects") == {"damage": 3, "bleed": 2}, "seamstress_prick keeps bleed two")
	_check(prick.get("starting_copies") == 2, "seamstress_prick keeps two copies")
	var pop_shot: Dictionary = starter.get_definition("tinker_pop_shot")
	_check(not pop_shot.is_empty(), "tinker_pop_shot remains authored")
	_check(pop_shot.get("effects") == {"damage": 5}, "tinker_pop_shot stays five damage")
	_check(pop_shot.get("starting_copies") == 2, "tinker_pop_shot keeps two copies")
	var active_deck: Array[String] = starter.get_starting_deck()
	_check(active_deck.has("warden_strike") and active_deck.has("seamstress_prick")
		and active_deck.has("tinker_pop_shot"), "active three-hero deck keeps its representatives")
	var raw_json: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored_deck: Variant = JSON.parse_string(raw_json)
	_check(authored_deck is Array, "authored starter deck parses")
	if authored_deck is Array:
		_check(active_deck == authored_deck,
			"active three-hero starting deck still matches its authored membership and order")
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		var plus_id: String = base_id + "_plus"
		_check(not starter.has_card(base_id) and not starter.has_card(plus_id),
			base_id + " has not entered StarterCards")
		_check(not active_deck.has(base_id) and not active_deck.has(plus_id),
			base_id + " is absent from the active starting deck")
		if authored_deck is Array:
			_check(not authored_deck.has(base_id) and not authored_deck.has(plus_id),
				base_id + " is absent from the authored starter deck")
		_check(monk.get_definition(base_id).get("reward_eligible") == false
			and monk.get_definition(plus_id).get("reward_eligible") == false,
			base_id + " pair is never reward eligible")
		_check(not monk.get_definition(base_id).has("rarity")
			and not monk.get_definition(plus_id).has("rarity"),
			base_id + " pair carries no pool rarity")
	# Nothing but the four authored bases and their upgrades is exposed by this catalog.
	for id: String in monk.get_all_card_ids():
		_check(cases.has(id) or cases.has(id.trim_suffix("_plus")),
			id + " is one of the four authored starter pairs, never a reward card")


## --- Paid single-target lantern Blind strikes (Wick Spark / Wick Flicker / Snuff Flame) ----------------
##
## Six printings across two authoritative catalogs resolve through one scene-free service. These cases drive
## CombatLanternMonkBlindStrikeCards over real seeded CombatDeck hands and real CombatParty/CombatEnemies models.
## They claim callable rules-layer behaviour only: no live hand, reward, app or run-deck wiring is asserted here.

const BLIND_STRIKE_IDS := [
	"lantern_monk_wick_spark", "lantern_monk_wick_spark_plus",
	"lantern_monk_wick_flicker", "lantern_monk_wick_flicker_plus",
	"lantern_monk_snuff_flame", "lantern_monk_snuff_flame_plus",
]
const BLIND_STRIKE_FILLERS := ["warden_strike", "tinker_pop_shot", "seamstress_prick", "warden_brace"]
const STRIKE_MONK_HP := 30
const STRIKE_ALLY_HP := 24
const STRIKE_BLIND_KEY := "blind_next_attack"
## Independent literal damage expectations: the printed raw hit -> the shared rules' adjusted hit.
## Weak is attacker -25%, Exposed is defender +50%, and Tangled adds a flat +2 after that floor-once quotient.
const STRIKE_ADJUSTED := {
	"plain": {3: 3, 4: 4, 6: 6},
	"exposed": {3: 4, 4: 6, 6: 9},
	"weak": {3: 2, 4: 3, 6: 4},
	"combo": {3: 5, 4: 6, 6: 8},
}


## Independent, named expectations for the six exact catalog printings. No global catalog total or ordering claim.
func _blind_strike_cases() -> Dictionary:
	return {
		"lantern_monk_wick_spark": {
			"catalog": "starter", "name": "Wick Spark", "damage": 4, "exposed": 0,
			"effects": {"damage": 4, "blind": 1}, "starting_copies": 1,
			"reward_eligible": false, "rarity": null},
		"lantern_monk_wick_spark_plus": {
			"catalog": "starter", "name": "Wick Spark+", "damage": 6, "exposed": 0,
			"effects": {"damage": 6, "blind": 1}, "starting_copies": 0,
			"reward_eligible": false, "rarity": null},
		"lantern_monk_wick_flicker": {
			"catalog": "pool", "name": "Wick Flicker", "damage": 4, "exposed": 0,
			"effects": {"damage": 4, "blind_next_attack": true}, "starting_copies": 0,
			"reward_eligible": true, "rarity": "common"},
		"lantern_monk_wick_flicker_plus": {
			"catalog": "pool", "name": "Wick Flicker+", "damage": 6, "exposed": 0,
			"effects": {"damage": 6, "blind_next_attack": true}, "starting_copies": 0,
			"reward_eligible": false, "rarity": "common"},
		"lantern_monk_snuff_flame": {
			"catalog": "pool", "name": "Snuff Flame", "damage": 3, "exposed": 1,
			"effects": {"damage": 3, "blind_next_attack": true, "exposed": 1}, "starting_copies": 0,
			"reward_eligible": true, "rarity": "uncommon"},
		"lantern_monk_snuff_flame_plus": {
			"catalog": "pool", "name": "Snuff Flame+", "damage": 4, "exposed": 2,
			"effects": {"damage": 4, "blind_next_attack": true, "exposed": 2}, "starting_copies": 0,
			"reward_eligible": false, "rarity": "uncommon"},
	}


## Deep comparison that also rejects coercible metadata (an int standing in for a bool descriptor, etc.).
func _typed_equal(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not (actual as Dictionary).has(key):
				return false
			if not _typed_equal(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _typed_equal(actual[index], expected[index]):
				return false
		return true
	return actual == expected


## AC1: all six printings must still carry their exact authored line in the one catalog that owns them, and the
## service must authenticate exactly that ID set and nothing else.
func _test_blind_strike_catalog() -> void:
	var starter := LanternMonkStarterCards.new()
	var pool := LanternMonkPoolCards.new()
	var cases: Dictionary = _blind_strike_cases()
	_check(cases.size() == 6, "exactly six lantern blind-strike printings are enumerated")
	_check(BLIND_STRIKE_IDS.size() == 6, "the six printed IDs are listed")
	for card_id: String in BLIND_STRIKE_IDS:
		_check(cases.has(card_id), card_id + " has an independent expectation")
		if not cases.has(card_id):
			continue
		var spec: Dictionary = cases[card_id]
		var base_id: String = card_id.trim_suffix("_plus")
		var upgraded: bool = card_id.ends_with("_plus")
		var catalog: RefCounted = starter if spec["catalog"] == "starter" else pool
		var other: RefCounted = pool if spec["catalog"] == "starter" else starter
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + ": authored record exists")
		if record.is_empty():
			continue
		_check(record.get("display_name") == spec["name"],
			card_id + ": printed name is " + str(spec["name"]))
		_check(record.get("owner") == "lantern_monk", card_id + ": owned by the Lantern Monk")
		_check(typeof(record.get("cost")) == TYPE_INT and record.get("cost") == 1,
			card_id + ": printed cost is exactly one energy")
		_check(_typed_equal(record.get("from_positions"), [2, 3]),
			card_id + ": printed FROM is the Monk's middle/rear seats")
		_check(record.get("target_kind") == "enemy_single", card_id + ": targets one enemy")
		_check(_typed_equal(record.get("to_positions"), [1, 2, 3]),
			card_id + ": printed TO is every original enemy slot")
		_check(_typed_equal(record.get("effects"), spec["effects"]),
			card_id + ": exact authored effects " + str(spec["effects"]))
		_check(record.get("effects", {}).get("damage") == spec["damage"],
			card_id + ": printed damage is " + str(spec["damage"]))
		# Blind has two authored printings but one canonical meaning: one next-attack miss.
		if spec["catalog"] == "starter":
			_check(record.get("effects", {}).has("blind")
				and record["effects"]["blind"] == 1
				and typeof(record["effects"]["blind"]) == TYPE_INT,
				card_id + ": starter prints the integer blind:1 descriptor")
			_check(not record.get("effects", {}).has("blind_next_attack"),
				card_id + ": starter does not print the pool Blind key")
		else:
			_check(record.get("effects", {}).has("blind_next_attack")
				and typeof(record["effects"]["blind_next_attack"]) == TYPE_BOOL
				and record["effects"]["blind_next_attack"] == true,
				card_id + ": pool prints the boolean blind_next_attack:true descriptor")
			_check(not record.get("effects", {}).has("blind"),
				card_id + ": pool invents no numeric blind stack")
		_check(typeof(record.get("starting_copies")) == TYPE_INT
			and record.get("starting_copies") == spec["starting_copies"],
			card_id + ": starting_copies is " + str(spec["starting_copies"]))
		_check(typeof(record.get("reward_eligible")) == TYPE_BOOL
			and record.get("reward_eligible") == spec["reward_eligible"],
			card_id + ": reward_eligible is " + str(spec["reward_eligible"]))
		_check(record.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
			card_id + ": keeps its base illustration path")
		if spec["rarity"] == null:
			_check(not record.has("rarity"), card_id + ": starter carries no pool rarity")
		else:
			_check(record.get("rarity") == spec["rarity"],
				card_id + ": pool rarity is " + str(spec["rarity"]))
		if upgraded:
			_check(record.get("upgrade_of") == base_id and not record.has("upgrade_id"),
				card_id + ": points back to " + base_id)
			_check(catalog.get_upgrade_id(base_id) == card_id,
				card_id + ": its base still links up to it")
		else:
			_check(record.get("upgrade_id") == card_id + "_plus" and not record.has("upgrade_of"),
				card_id + ": links up to " + card_id + "_plus")
			_check(catalog.get_upgrade_id(card_id) == card_id + "_plus",
				card_id + ": upgrade_id resolves through the catalog")
		_check(not other.has_card(card_id), card_id + ": the other catalog does not own it")
		# The service exposes a pure support/definition query over exactly these authenticated records.
		_check(strike_service.is_supported_card(card_id), card_id + ": service authenticates the printing")
		_check(_typed_equal(strike_service.get_definition(card_id), record),
			card_id + ": definition query returns the exact authored record")
	var sample: Dictionary = strike_service.get_definition("lantern_monk_snuff_flame")
	_check(not sample.is_empty(), "definition query fixture loaded")
	if not sample.is_empty():
		sample["effects"]["damage"] = -99
		_check(strike_service.get_definition("lantern_monk_snuff_flame").get("effects", {}).get("damage") == 3,
			"definition query returns a detached record")
	for unsupported in ["lantern_monk_moth_wink", "lantern_monk_moth_lure", "lantern_monk_moth_cloud",
			"lantern_monk_wax_ward", "warden_strike", "seamstress_prick", "",
			"lantern_monk_wick_spark_plus_plus", "wick_spark", "lantern_monk_wick_flicker_ultra"]:
		_check(not strike_service.is_supported_card(unsupported),
			str(unsupported) + ": not a blind-strike printing")
		_check(strike_service.get_definition(unsupported).is_empty(),
			str(unsupported) + ": definition query returns nothing")
	for non_string in [null, 7, true, 3.5, StringName("lantern_monk_wick_spark")]:
		_check(not strike_service.is_supported_card(non_string),
			str(non_string) + ": non-string ID is never supported")
		_check(strike_service.get_definition(non_string).is_empty(),
			str(non_string) + ": non-string definition query returns nothing")
	# A rewritten record is never supported, and every core field is guarded.
	for card_id: String in BLIND_STRIKE_IDS:
		var spec: Dictionary = cases[card_id]
		var catalog: RefCounted = starter if spec["catalog"] == "starter" else pool
		var authentic: Dictionary = catalog.get_definition(card_id)
		_check(not authentic.is_empty(), card_id + ": forgery fixture loaded")
		if authentic.is_empty():
			continue
		var forged := ForgedBlindStrike.new()
		forged.forged_id = card_id
		var mutations: Array = []
		var altered_values := {
			"id": "fake", "display_name": "Fake", "owner": "warden", "cost": 1.0,
			"from_positions": [1, 2], "to_positions": [1], "target_kind": "enemy_all",
			"effects": {"damage": 99, "blind": 1}, "starting_copies": 9,
			"reward_eligible": not bool(spec["reward_eligible"]), "upgrade_id": "fake",
			"upgrade_of": "fake", "rarity": "rare", "illustration_path": "res://fake.png",
		}
		for field: String in ["id", "display_name", "owner", "cost", "from_positions", "to_positions",
				"target_kind", "effects", "starting_copies", "reward_eligible", "upgrade_id",
				"upgrade_of", "rarity", "illustration_path"]:
			# Erasing an absent field would be a no-op, so only omit fields the record really carries.
			if authentic.has(field):
				var omitted: Dictionary = authentic.duplicate(true)
				omitted.erase(field)
				mutations.append(omitted)
			var altered: Dictionary = authentic.duplicate(true)
			altered[field] = altered_values[field]
			mutations.append(altered)
		var extra: Dictionary = authentic.duplicate(true)
		extra["effects"]["draw"] = 1
		mutations.append(extra)
		var typed: Dictionary = authentic.duplicate(true)
		typed["effects"]["blind_next_attack"] = 1
		mutations.append(typed)
		var foreign: Dictionary = authentic.duplicate(true)
		foreign["effects"] = {"damage": 9, "blind_next_attack": true, "exposed": 3}
		mutations.append(foreign)
		mutations.append(pool.get_definition("lantern_monk_moth_lure"))
		for mutation: Dictionary in mutations:
			forged.forged = mutation
			_check(not forged.is_supported_card(card_id),
				card_id + ": forged catalog record is not supported")
			_check(forged.get_definition(card_id).is_empty(),
				card_id + ": forged definition query returns nothing")
		forged.forged = authentic
		_check(forged.is_supported_card(card_id),
			card_id + ": restored authentic catalog is supported again")


func _strike_deck(card_id: String, seed_value: int = 60601) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, BLIND_STRIKE_FILLERS[0],
		BLIND_STRIKE_FILLERS[1], BLIND_STRIKE_FILLERS[2]]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(ids, rng)
	var started: bool = deck.start_turn()
	_check(started and deck.turn_active and deck.energy == 3 and deck.hand.size() == 5
		and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holds at least two genuine copies")
	return deck


func _strike_party(monk_seat: int) -> CombatParty:
	var definitions: Array = []
	for position in range(1, 4):
		definitions.append({
			"id": "lantern_monk" if position == monk_seat else "ally_%d" % position,
			"max_hp": STRIKE_MONK_HP if position == monk_seat else STRIKE_ALLY_HP,
		})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(monk_seat)["id"] == "lantern_monk",
		"real three-hero party with the living Monk in seat " + str(monk_seat))
	return party


func _strike_enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "straw_brute", "name": "Straw Brute", "max_hp": 30,
			"intent": {"target": "front", "actions": [{"type": "attack", "amount": 6, "weight": 1}]}},
		{"id": "needle_wasp", "name": "Needle Wasp", "max_hp": 24,
			"intent": {"target": "front", "actions": [{"type": "attack", "amount": 5, "weight": 1}]}},
		{"id": "quilt_moth", "name": "Quilt Moth", "max_hp": 18,
			"intent": {"target": "front", "actions": [{"type": "attack", "amount": 4, "weight": 1}]}},
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"real three-slot enemy roster")
	return enemies


func _strike_fixture(card_id: String, monk_seat: int = 2, seed_value: int = 60601) -> Dictionary:
	return {"deck": _strike_deck(card_id, seed_value), "party": _strike_party(monk_seat),
		"enemies": _strike_enemies()}


## Full observable state plus the injected run RNG, for exact no-mutation comparisons.
func _strike_snapshot(f: Dictionary) -> Dictionary:
	return {
		"hand": f.deck.hand.duplicate(true),
		"draw": f.deck.draw_pile.duplicate(true),
		"discard": f.deck.discard_pile.duplicate(true),
		"exhausted": f.deck.exhausted.duplicate(true),
		"energy": f.deck.energy,
		"turn": f.deck.turn_active,
		"heroes": f.party.get_heroes(),
		"enemies": f.enemies.get_enemies(),
		"rng_state": f.deck._rng.state,
		"rng_seed": f.deck._rng.seed,
	}


## AC2: one genuine held copy, one energy and exactly one status-adjusted hit per cast, with the printed Blind
## (and Snuff Flame's Exposed) only after the hit. Covers raw, Weak/Exposed/Tangled, Block absorption, an
## already-armed Blind, legal Dodge on the attacker, a Torn ally and post-hit Exposed stacking.
func _test_blind_strike_paid_play() -> void:
	var cases: Dictionary = _blind_strike_cases()
	for card_id: String in BLIND_STRIKE_IDS:
		var spec: Dictionary = cases[card_id]
		for scenario: String in ["plain", "exposed", "weak", "combo", "blocked", "already_blind",
				"dodge", "torn_ally", "stacked_exposed"]:
			_strike_case(card_id, spec, scenario, 2)
		_strike_case(card_id, spec, "plain", 3)
		_strike_second_copy(card_id, spec)


func _strike_case(card_id: String, spec: Dictionary, scenario: String, monk_seat: int) -> void:
	var label := "%s/%s/seat%d" % [card_id, scenario, monk_seat]
	var f := _strike_fixture(card_id, monk_seat, 60601 + monk_seat)
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	var target := 2
	var damage: int = int(spec["damage"])
	var exposed: int = int(spec["exposed"])
	if scenario == "plain":
		party._heroes[monk_seat - 1]["statuses"] = {"riposte": 4}
		enemies._enemies[0]["statuses"] = {"bleed": 2}
		_check(enemies.gain_block(target, 2), label + ": real pre-hit Block seeded")
	elif scenario == "exposed":
		enemies._enemies[target - 1]["statuses"] = {"exposed": 2}
	elif scenario == "weak":
		party._heroes[monk_seat - 1]["statuses"] = {"weak": 1}
	elif scenario == "combo":
		party._heroes[monk_seat - 1]["statuses"] = {"weak": 1}
		enemies._enemies[target - 1]["statuses"] = {"exposed": 1, "tangled": 2}
	elif scenario == "blocked":
		_check(enemies.gain_block(target, damage + 2), label + ": full-absorption Block seeded")
	elif scenario == "already_blind":
		enemies._enemies[target - 1]["statuses"] = {"blind_next_attack": 1, "weak": 2}
	elif scenario == "dodge":
		party._heroes[monk_seat - 1]["statuses"] = {"dodge_next_attack": 1}
	elif scenario == "torn_ally":
		var torn := 1 if monk_seat != 1 else 3
		_check(party.apply_damage(torn, STRIKE_ALLY_HP) and party.is_downed(torn),
			label + ": a non-Monk ally is genuinely Torn")
	elif scenario == "stacked_exposed":
		enemies._enemies[target - 1]["statuses"] = {"exposed": 2}
	# Expectations come from the real pre-hit records, never from a mutated test-side effect dictionary.
	var target_before: Dictionary = enemies.get_enemy(target)
	var expected_damage: int = damage
	if scenario in ["exposed", "stacked_exposed"]:
		expected_damage = int(STRIKE_ADJUSTED["exposed"][damage])
	elif scenario == "weak":
		expected_damage = int(STRIKE_ADJUSTED["weak"][damage])
	elif scenario == "combo":
		expected_damage = int(STRIKE_ADJUSTED["combo"][damage])
	var absorbed: int = mini(int(target_before["block"]), expected_damage)
	var hp_loss: int = mini(int(target_before["hp"]), expected_damage - absorbed)
	var target_statuses: Dictionary = target_before.get("statuses", {})
	var blind_before: int = int(target_statuses.get(STRIKE_BLIND_KEY, 0))
	var exposed_before: int = int(target_statuses.get("exposed", 0))
	var hand_before: Array = deck.hand.duplicate()
	var draw_before: Array = deck.draw_pile.duplicate()
	var discard_before: Array = deck.discard_pile.duplicate()
	var energy_before: int = deck.energy
	var rng_before: int = deck._rng.state
	var heroes_before: Array = party.get_heroes()
	var roster_before: Array = enemies.get_enemies()

	var receipt: Dictionary = strike_service.play_card(deck, party, enemies, card_id, target)
	_check(receipt.get("ok", false) and receipt.get("reason") == "applied",
		label + ": authentic paid strike")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == 1,
		label + ": receipt names the printing and its one energy")
	_check(receipt.get("owner_position") == monk_seat and receipt.get("target_position") == target
		and receipt.get("target_kind") == "enemy_single"
		and receipt.get("target_id") == target_before["id"],
		label + ": receipt names the Monk seat and the selected original slot")
	_check(receipt.get("base_damage") == damage and receipt.get("damage") == expected_damage,
		label + ": one printed raw hit adjusted by the shared status rules")
	_check(receipt.get("block_absorbed") == absorbed and receipt.get("hp_loss") == hp_loss,
		label + ": Block absorbs before HP")
	_check(receipt.get("hp_after") == int(target_before["hp"]) - hp_loss
		and receipt.get("block_after") == int(target_before["block"]) - absorbed,
		label + ": receipt reflects the real remaining HP and Block")
	_check(receipt.get("blind_before") == blind_before and receipt.get("blind_after") == 1
		and receipt.get("blind_already_active") == (blind_before == 1),
		label + ": the cast arms the one-shot Blind at exactly 1 (never a second stack)")
	_check(receipt.get("exposed_applied") == exposed
		and receipt.get("exposed_after") == exposed_before + exposed,
		label + ": only Snuff Flame adds its printed Exposed, after the hit")

	var expected_hand: Array = hand_before.duplicate()
	expected_hand.remove_at(expected_hand.find(card_id))
	var expected_discard: Array = discard_before.duplicate()
	expected_discard.append(card_id)
	_check(deck.hand == expected_hand and deck.draw_pile == draw_before
		and deck.discard_pile == expected_discard and deck.energy == energy_before - 1
		and deck.turn_active,
		label + ": exactly one energy and one held copy, no extra draw")
	_check(deck._rng.state == rng_before, label + ": the paid strike consumes no run RNG draw")
	_check(party.get_heroes() == heroes_before,
		label + ": no hero HP, Block, status or seat is changed by the strike")

	var expected_roster: Array = roster_before.duplicate(true)
	var expected_target: Dictionary = expected_roster[target - 1]
	expected_target["block"] = int(expected_target["block"]) - absorbed
	expected_target["hp"] = int(expected_target["hp"]) - hp_loss
	if not expected_target.has("statuses"):
		expected_target["statuses"] = {}
	expected_target["statuses"][STRIKE_BLIND_KEY] = 1
	if exposed > 0:
		expected_target["statuses"]["exposed"] = exposed_before + exposed
	_check(enemies.get_enemies() == expected_roster,
		label + ": exact target HP/Block/statuses; the other slots are untouched")
	_check(typeof(enemies.get_enemy(target)["statuses"][STRIKE_BLIND_KEY]) == TYPE_INT
		and enemies.get_enemy(target)["statuses"][STRIKE_BLIND_KEY] == 1,
		label + ": Blind is the canonical integer 1 on the authoritative enemy record")


## AC2: a second cast needs a second genuine held copy, and the first enemy's Blind is never spent by it.
func _strike_second_copy(card_id: String, _spec: Dictionary) -> void:
	var f := _strike_fixture(card_id, 2, 61611)
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	_check(deck.hand.count(card_id) >= 2, card_id + ": two genuine copies are really held")
	var first: Dictionary = strike_service.play_card(deck, party, enemies, card_id, 1)
	var second: Dictionary = strike_service.play_card(deck, party, enemies, card_id, 3)
	_check(first.get("ok", false) and second.get("ok", false),
		card_id + ": a second cast from a second genuine held copy succeeds")
	_check(deck.energy == 1 and deck.discard_pile.count(card_id) == 2,
		card_id + ": each cast spends one energy and discards one copy")
	_check(enemies.get_enemy(1)["statuses"][STRIKE_BLIND_KEY] == 1
		and enemies.get_enemy(3)["statuses"][STRIKE_BLIND_KEY] == 1,
		card_id + ": both selected enemies really carry Blind 1")
	_check(not enemies.get_enemy(2).get("statuses", {}).has(STRIKE_BLIND_KEY),
		card_id + ": the unselected enemy is never Blinded")
	_check(enemies.get_enemy(1)["hp"] < 30 and enemies.get_enemy(3)["hp"] < 18,
		card_id + ": both casts really dealt damage")


func _strike_refused(f: Dictionary, card_id: Variant, target: int, label: String) -> void:
	var before := _strike_snapshot(f)
	var result: Dictionary = strike_service.play_card(f.deck, f.party, f.enemies, card_id, target)
	_check(result.get("ok", false) == false, label + ": refused")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_strike_snapshot(f) == before,
		label + ": unchanged hand, draw, discard, energy, party, roster and RNG")


## AC3: every invalid precondition fails closed before payment, and a valid retry still works afterwards.
func _test_blind_strike_refusals() -> void:
	var card_id := "lantern_monk_snuff_flame"

	var front := _strike_fixture(card_id, 1)
	_check(front.party.get_hero(1)["id"] == "lantern_monk",
		"front-Monk fixture really seats the Monk up front")
	_strike_refused(front, card_id, 2, "front Monk (illegal FROM seat)")

	var missing := _strike_fixture(card_id)
	missing.party._heroes[1]["id"] = "mender"
	_check(missing.party.get_hero(2)["id"] == "mender"
		and missing.party.get_hero(1)["id"] != "lantern_monk"
		and missing.party.get_hero(3)["id"] != "lantern_monk",
		"missing-Monk fixture really has no Lantern Monk")
	_strike_refused(missing, card_id, 2, "party with no Lantern Monk")

	var duplicate := _strike_fixture(card_id)
	duplicate.party._heroes[0]["id"] = "lantern_monk"
	_check(duplicate.party.get_hero(1)["id"] == "lantern_monk"
		and duplicate.party.get_hero(2)["id"] == "lantern_monk",
		"duplicate-Monk fixture really repeats the owner ID")
	_strike_refused(duplicate, card_id, 2, "duplicate Monk identity")

	var downed := _strike_fixture(card_id)
	_check(downed.party.apply_damage(2, STRIKE_MONK_HP) and downed.party.is_downed(2),
		"torn-caster fixture has a genuinely downed Monk")
	_strike_refused(downed, card_id, 2, "torn (downed) Monk")

	var unheld := _strike_fixture(card_id)
	for index in range(unheld.deck.hand.size()):
		if unheld.deck.hand[index] == card_id:
			unheld.deck.hand[index] = "warden_strike"
	_check(not unheld.deck.hand.has(card_id), "unheld fixture really holds no copy")
	_strike_refused(unheld, card_id, 2, "card not held")

	var inactive := _strike_fixture(card_id)
	_check(inactive.deck.end_turn() and not inactive.deck.turn_active,
		"inactive-turn fixture really has no active turn")
	_strike_refused(inactive, card_id, 2, "inactive turn")

	var broke := _strike_fixture(card_id)
	_check(broke.deck.try_spend_energy(3) and broke.deck.energy == 0,
		"energy-short fixture is genuinely broke and still holds the card")
	_strike_refused(broke, card_id, 2, "zero energy")

	var dead := _strike_fixture(card_id)
	_check(dead.enemies.apply_damage(2, 24) and dead.enemies.is_slain(2),
		"dead-target fixture really has a slain selected slot")
	_strike_refused(dead, card_id, 2, "slain enemy slot")

	for target in [0, 4, -1, 99]:
		_strike_refused(_strike_fixture(card_id), card_id, target,
			"target slot " + str(target))

	var short := _strike_fixture(card_id)
	short["enemies"] = CombatEnemies.new([
		{"id": "only_one", "max_hp": 10}, {"id": "only_two", "max_hp": 10}])
	_check(short.enemies.is_valid() and short.enemies.get_enemies().size() == 2,
		"short-roster fixture really has two slots")
	_strike_refused(short, card_id, 3, "target 3 with a two-slot roster")

	for bad in [{"weak": -1}, {"weak": "1"}, {"exposed": 1.5}, {"blind_next_attack": true},
			{"dodge_next_attack": 2}, {"unknown_status": 1}, {1: 2}]:
		var hero_bad := _strike_fixture(card_id)
		hero_bad.party._heroes[1]["statuses"] = bad
		_strike_refused(hero_bad, card_id, 2, "malformed hero statuses " + str(bad))
		var enemy_bad := _strike_fixture(card_id)
		enemy_bad.enemies._enemies[1]["statuses"] = bad
		_strike_refused(enemy_bad, card_id, 2, "malformed enemy statuses " + str(bad))
	var not_a_map := _strike_fixture(card_id)
	not_a_map.enemies._enemies[1]["statuses"] = "exposed"
	_strike_refused(not_a_map, card_id, 2, "non-dictionary enemy statuses")

	var overflow := _strike_fixture(card_id)
	overflow.enemies._enemies[1]["statuses"] = {"exposed": CombatEnemies.MAX_INT}
	_strike_refused(overflow, card_id, 2, "unrepresentable post-hit Exposed addition")

	# A non-Exposed printing is not refused by an unrelated huge existing Exposed counter.
	var control := _strike_fixture("lantern_monk_wick_spark")
	control.enemies._enemies[1]["statuses"] = {"exposed": CombatEnemies.MAX_INT}
	var control_receipt: Dictionary = strike_service.play_card(
		control.deck, control.party, control.enemies, "lantern_monk_wick_spark", 2)
	_check(control_receipt.get("ok", false),
		"a printing that adds no Exposed is not refused by a huge existing Exposed counter")
	_check(control_receipt.get("exposed_applied") == 0
		and control.enemies.get_enemy(2)["statuses"]["exposed"] == CombatEnemies.MAX_INT,
		"the huge existing counter is preserved and never extended")

	for scenario: String in ["hp_above_max", "negative_block", "wrong_hero_position",
			"wrong_enemy_position", "duplicate_enemy_id"]:
		var broken := _strike_fixture(card_id)
		if scenario == "hp_above_max":
			broken.party._heroes[0]["hp"] = STRIKE_ALLY_HP + 1
		elif scenario == "negative_block":
			broken.enemies._enemies[2]["block"] = -1
		elif scenario == "wrong_hero_position":
			broken.party._heroes[0]["position"] = 3
		elif scenario == "wrong_enemy_position":
			broken.enemies._enemies[1]["position"] = 3
		elif scenario == "duplicate_enemy_id":
			broken.enemies._enemies[2]["id"] = broken.enemies._enemies[1]["id"]
		_strike_refused(broken, card_id, 2, "malformed roster " + scenario)

	var empty_party := _strike_fixture(card_id)
	empty_party["party"] = CombatParty.new([])
	_strike_refused(empty_party, card_id, 2, "invalid party roster")

	for missing_part in ["deck", "party", "enemies"]:
		var f := _strike_fixture(card_id)
		var before := _strike_snapshot(f)
		var deck: CombatDeck = f.deck
		var party: CombatParty = f.party
		var enemies: CombatEnemies = f.enemies
		if missing_part == "deck":
			deck = null
		elif missing_part == "party":
			party = null
		else:
			enemies = null
		var result: Dictionary = strike_service.play_card(deck, party, enemies, card_id, 2)
		_check(not result.get("ok", false), "null " + missing_part + " refuses")
		_check(_strike_snapshot(f) == before, "null " + missing_part + " leaves all state unchanged")

	for unsupported in ["lantern_monk_moth_wink", "lantern_monk_moth_lure", "lantern_monk_moth_cloud",
			"lantern_monk_wax_ward", "warden_strike", "", "lantern_monk_wick_flicker_ultra",
			null, 7, true, StringName("lantern_monk_wick_flicker")]:
		_strike_refused(_strike_fixture(card_id), unsupported, 2,
			"unsupported card id " + str(unsupported))

	# A consumed copy cannot replay: only one genuine copy is drawn.
	var single_rng := RandomNumberGenerator.new()
	single_rng.seed = 61777
	var single := CombatDeck.new([card_id, BLIND_STRIKE_FILLERS[0], BLIND_STRIKE_FILLERS[1],
		BLIND_STRIKE_FILLERS[2], BLIND_STRIKE_FILLERS[3]], single_rng)
	_check(single.start_turn() and single.hand.count(card_id) == 1,
		"replay fixture draws exactly one genuine copy")
	var single_f := {"deck": single, "party": _strike_party(2), "enemies": _strike_enemies()}
	var first: Dictionary = strike_service.play_card(
		single_f.deck, single_f.party, single_f.enemies, card_id, 1)
	_check(first.get("ok", false) and not single.hand.has(card_id),
		"the single copy plays once and leaves the hand")
	var replay_before := _strike_snapshot(single_f)
	var replay: Dictionary = strike_service.play_card(
		single_f.deck, single_f.party, single_f.enemies, card_id, 2)
	_check(not replay.get("ok", false), "a replay of the consumed copy is refused")
	_check(_strike_snapshot(single_f) == replay_before,
		"the replay refusal changes no pile, roster or RNG")

	# Forged catalog record, then a valid retry once the authentic catalog is restored.
	var pool := LanternMonkPoolCards.new()
	var authentic: Dictionary = pool.get_definition(card_id)
	_check(not authentic.is_empty(), "forged-catalog fixture loaded")
	if authentic.is_empty():
		return
	var forged := ForgedBlindStrike.new()
	forged.forged_id = card_id
	var forged_mutations: Array = []
	for field: String in ["id", "display_name", "owner", "cost", "from_positions", "to_positions",
			"target_kind", "effects", "starting_copies", "reward_eligible", "upgrade_of",
			"rarity", "illustration_path"]:
		# Erasing an absent field would be a no-op, so only omit fields the record really carries.
		if authentic.has(field):
			var omitted: Dictionary = authentic.duplicate(true)
			omitted.erase(field)
			forged_mutations.append(omitted)
	var altered: Dictionary = authentic.duplicate(true)
	altered["effects"]["damage"] = 99
	forged_mutations.append(altered)
	var relinked: Dictionary = authentic.duplicate(true)
	relinked["upgrade_of"] = "lantern_monk_wick_flicker"
	forged_mutations.append(relinked)
	forged_mutations.append(LanternMonkStarterCards.new().get_definition("lantern_monk_wick_spark"))
	for mutation: Dictionary in forged_mutations:
		forged.forged = mutation
		var f := _strike_fixture(card_id)
		var before := _strike_snapshot(f)
		_check(not forged.is_supported_card(card_id), "forged catalog record is not supported")
		_check(forged.get_definition(card_id).is_empty(),
			"forged definition query returns nothing")
		_check(not forged.play_card(f.deck, f.party, f.enemies, card_id, 2).get("ok", false),
			"forged catalog record refuses payment")
		_check(_strike_snapshot(f) == before,
			"forgery rejection leaves the whole transaction unchanged")
	forged.forged = authentic
	_check(forged.is_supported_card(card_id), "the restored authentic catalog is supported")

	var retry := _strike_fixture(card_id)
	var retry_before := _strike_snapshot(retry)
	var refused: Dictionary = strike_service.play_card(retry.deck, retry.party, retry.enemies, card_id, 0)
	_check(not refused.get("ok", false), "a retry fixture first refuses an illegal target")
	_check(_strike_snapshot(retry) == retry_before, "that refusal changes nothing")
	var retried: Dictionary = strike_service.play_card(retry.deck, retry.party, retry.enemies, card_id, 1)
	_check(retried.get("ok", false), "the same fixture then accepts a valid retry")


## AC2: the cast and owner-turn aging never spend Blind; only the existing enemy phase's attempted attack does.
func _test_blind_strike_enemy_phase() -> void:
	var f := _strike_fixture("lantern_monk_wick_spark", 2, 70707)
	var receipt: Dictionary = strike_service.play_card(
		f.deck, f.party, f.enemies, "lantern_monk_wick_spark", 2)
	_check(receipt.get("ok", false)
		and f.enemies.get_enemy(2)["statuses"][STRIKE_BLIND_KEY] == 1,
		"precondition: the cast arms Blind 1 on the selected enemy")
	var tick: Dictionary = CombatStatusTurnBatch.new().tick_side("enemies", f.enemies.get_enemies())
	_check(tick.get("ok", false)
		and tick["actors"][1]["statuses"].get(STRIKE_BLIND_KEY) == 1,
		"owner-turn status aging keeps the armed Blind")
	_check(f.enemies.get_enemy(2)["statuses"].get(STRIKE_BLIND_KEY) == 1,
		"neither the cast nor status aging consumed the token")
	var party_before: Array = f.party.get_heroes()
	var attempted: Dictionary = CombatEnemyPhase.new().execute_phase(f.party, f.enemies,
		[{"enemy_position": 2, "type": "attack", "amount": 7, "target_position": 1}])
	_check(attempted.get("ok", false) and attempted["events"].size() == 1
		and attempted["events"][0].get("applied") == false,
		"the existing enemy phase makes the next attempted attack miss")
	_check(f.party.get_heroes() == party_before
		and not f.enemies.get_enemy(2)["statuses"].has(STRIKE_BLIND_KEY),
		"Blind is consumed by that real attack attempt, dealing no damage")
	var later: Dictionary = CombatEnemyPhase.new().execute_phase(f.party, f.enemies,
		[{"enemy_position": 2, "type": "attack", "amount": 7, "target_position": 1}])
	_check(later.get("ok", false) and later["events"][0].get("applied") == true
		and f.party.get_hero(1)["hp"] < STRIKE_MONK_HP,
		"the following attack lands normally once Blind is spent")
