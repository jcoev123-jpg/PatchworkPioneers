extends SceneTree
## D2-1 authored party-support Help: only the six real base/'+' pool records
## (Hold the Line, Bastion Quilt, Field Mend) gain the short "Party support" row,
## and every amount it prints is the authenticated catalog amount. The real
## Block/heal resolvers are the oracle for the living group, downed exclusion,
## the HP cap and the no-revive rule. Glossary calls stay read-only and RNG-free.

const HEROES_PATH := "res://data/heroes/starter_party.json"
const PARTY_ROW := "Party support"
const RESCUE_ROW := "Mixed rescue"

var checks := 0
var failures: Array[String] = []
var warden := WardenPoolCards.new()
var seamstress := SeamstressPoolCards.new()


func _initialize() -> void:
	_test_authentic_definitions()
	_test_authentic_seamstress()
	_test_authentic_darning()
	_test_warden_combat_outcomes()
	_test_bastion_quilt_outcomes()
	_test_field_mend_outcomes()
	_test_darning_combat_outcomes()
	_test_rejections()
	_test_ordering_detachment_and_rng()
	for failure: String in failures:
		printerr(failure)
	print("card_party_support_help_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


# --- Read-only helpers -----------------------------------------------------

func _names(rows: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in rows:
		result.append(String(row.get("keyword", "")))
	return result


func _shape(effects: Dictionary) -> Dictionary:
	return {"effects": effects.duplicate(true)}


func _support_definition(card_id: Variant, owner: Variant, cost: Variant,
		from_positions: Variant, target_kind: Variant, to_positions: Variant,
		effects: Variant) -> Dictionary:
	var definition := {"id": card_id, "owner": owner, "cost": cost,
		"target_kind": target_kind}
	definition["from_positions"] = from_positions.duplicate(true) \
		if from_positions is Array else from_positions
	definition["to_positions"] = to_positions.duplicate(true) \
		if to_positions is Array else to_positions
	definition["effects"] = effects.duplicate(true) if effects is Dictionary else effects
	return definition


# --- Authentic catalog records and their Help rows -------------------------

## The six authored records, the shape each must keep and the exact phrases the
## row has to state. The "forbidden" strings are the other upgrade's numbers, so
## a row can never be produced from a mismatched amount.
func _authentic_cases() -> Array:
	return [
		{"catalog": warden, "id": "warden_hold_the_line", "owner": "warden",
			"cost": 1, "from": [1, 2], "target": "self",
			"effects": {"block": 5, "other_ally_block": 2},
			"phrases": ["Warden gains 5 Block", "every OTHER living hero gains 2 Block",
				"Costs 1 energy", "playable by the Warden from positions 1-2",
				"A downed hero gains nothing", "current position", "fixed slot"],
			"forbidden": ["7 Block", "3 Block"]},
		{"catalog": warden, "id": "warden_hold_the_line_plus", "owner": "warden",
			"cost": 1, "from": [1, 2], "target": "self",
			"effects": {"block": 7, "other_ally_block": 3},
			"phrases": ["Warden gains 7 Block", "every OTHER living hero gains 3 Block",
				"Costs 1 energy", "playable by the Warden from positions 1-2",
				"A downed hero gains nothing", "current position"],
			"forbidden": ["5 Block", "2 Block"]},
		{"catalog": warden, "id": "warden_bastion_quilt", "owner": "warden",
			"cost": 3, "from": [1, 2, 3], "target": "party_all",
			"effects": {"block_all": 10},
			"phrases": ["Every living hero gains 10 Block",
				"even after the party changes positions", "Costs 3 energy",
				"playable by the Warden from any of the three positions",
				"A downed hero gains nothing"],
			"forbidden": ["13 Block"]},
		{"catalog": warden, "id": "warden_bastion_quilt_plus", "owner": "warden",
			"cost": 3, "from": [1, 2, 3], "target": "party_all",
			"effects": {"block_all": 13},
			"phrases": ["Every living hero gains 13 Block",
				"even after the party changes positions", "Costs 3 energy",
				"playable by the Warden from any of the three positions",
				"A downed hero gains nothing"],
			"forbidden": ["10 Block"]},
		{"catalog": seamstress, "id": "seamstress_field_mend", "owner": "seamstress",
			"cost": 2, "from": [2, 3], "target": "party_all",
			"effects": {"heal": 4},
			"phrases": ["Each living hero recovers 4 HP",
				"capped at that hero's current maximum HP", "Costs 2 energy",
				"playable by the Seamstress from positions 2-3",
				"A downed hero is skipped", "not revived"],
			"forbidden": ["6 HP"]},
		{"catalog": seamstress, "id": "seamstress_field_mend_plus", "owner": "seamstress",
			"cost": 2, "from": [2, 3], "target": "party_all",
			"effects": {"heal": 6},
			"phrases": ["Each living hero recovers 6 HP",
				"capped at that hero's current maximum HP", "Costs 2 energy",
				"playable by the Seamstress from positions 2-3",
				"A downed hero is skipped", "not revived"],
			"forbidden": ["4 HP"]},
	]


func _test_authentic_definitions() -> void:
	for case: Dictionary in _authentic_cases():
		var catalog: Variant = case["catalog"]
		var card_id: String = String(case["id"])
		var original: Dictionary = catalog.get_definition(card_id)
		_check(catalog.has_card(card_id) and not original.is_empty(),
			"authentic catalog record exists for " + card_id)
		if original.is_empty():
			continue
		_check(original.get("id") == card_id
			and original.get("owner") == case["owner"]
			and original.get("cost") == case["cost"]
			and original.get("from_positions") == case["from"]
			and original.get("target_kind") == case["target"]
			and original.get("to_positions") == []
			and original.get("effects") == case["effects"],
			"authored owner, cost, slots, target and exact effect amounts for " + card_id)
		var rows := CardKeywordGlossary.describe(original)
		_check(rows.size() == 1 and _names(rows) == [PARTY_ROW],
			"exactly one Party support row for " + card_id)
		if rows.size() != 1:
			continue
		var text := String(rows[0]["explanation"])
		for phrase: String in case["phrases"]:
			_check(text.contains(phrase), "Help states '%s' for %s" % [phrase, card_id])
		for amount: String in case["forbidden"]:
			_check(not text.contains(amount),
				"Help for %s never prints the other upgrade's '%s'" % [card_id, amount])
		# Legal owner/source contract: the row exists only for this exact record,
		# and the catalog keeps it untouched.
		_check(catalog.get_definition(card_id) == original,
			"Help never mutates the catalog record " + card_id)


func _test_authentic_seamstress() -> void:
	# Field Mend's legal source slots are 2-3 only; both real records prove it.
	for card_id: String in ["seamstress_field_mend", "seamstress_field_mend_plus"]:
		var definition := seamstress.get_definition(card_id)
		_check(definition.get("from_positions") == [2, 3],
			"Field Mend owner is authored to positions 2-3 for " + card_id)
		_check(CardKeywordGlossary.describe(definition).size() == 1,
			"real Field Mend definition gains its one support row " + card_id)


func _authentic_darning_cases() -> Array:
	return [
		{"catalog": seamstress, "id": "seamstress_darning", "owner": "seamstress",
			"cost": 1, "from": [1, 2, 3], "target": "ally_single",
			"effects": {"heal": 4, "block": 3},
			"phrases": ["Heals a chosen living ally 4 HP and grants that ally 3 Block",
				"Costs 1 energy", "playable by the Seamstress from positions 1-3",
				"Healing is capped by the chosen living ally's missing HP",
				"Block portion still applies even if the ally is already at full HP",
				"A downed hero cannot be chosen and is not revived"],
			"forbidden": ["6 HP", "4 Block"]},
		{"catalog": seamstress, "id": "seamstress_darning_plus", "owner": "seamstress",
			"cost": 1, "from": [1, 2, 3], "target": "ally_single",
			"effects": {"heal": 6, "block": 4},
			"phrases": ["Heals a chosen living ally 6 HP and grants that ally 4 Block",
				"Costs 1 energy", "playable by the Seamstress from positions 1-3",
				"Healing is capped by the chosen living ally's missing HP",
				"Block portion still applies even if the ally is already at full HP",
				"A downed hero cannot be chosen and is not revived"],
			"forbidden": ["4 HP", "3 Block"]},
	]


func _test_authentic_darning() -> void:
	for case: Dictionary in _authentic_darning_cases():
		var catalog: Variant = case["catalog"]
		var card_id: String = String(case["id"])
		var original: Dictionary = catalog.get_definition(card_id)
		_check(catalog.has_card(card_id) and not original.is_empty(),
			"authentic catalog record exists for " + card_id)
		if original.is_empty():
			continue
		_check(original.get("id") == card_id
			and original.get("owner") == case["owner"]
			and original.get("cost") == case["cost"]
			and original.get("from_positions") == case["from"]
			and original.get("target_kind") == case["target"]
			and original.get("to_positions") == []
			and original.get("effects") == case["effects"],
			"authored owner, cost, slots, target and exact effect amounts for " + card_id)
		var rows := CardKeywordGlossary.describe(original)
		_check(rows.size() == 1 and _names(rows) == [RESCUE_ROW],
			"exactly one Mixed rescue row for " + card_id)
		if rows.size() != 1:
			continue
		var text := String(rows[0]["explanation"])
		for phrase: String in case["phrases"]:
			_check(text.contains(phrase), "Help states '%s' for %s" % [phrase, card_id])
		for amount: String in case["forbidden"]:
			_check(not text.contains(amount),
				"Help for %s never prints the other upgrade's '%s'" % [card_id, amount])
		_check(catalog.get_definition(card_id) == original,
			"Help never mutates the catalog record " + card_id)


# --- Real combat outcomes the row describes ---------------------------------

func _party(order: Array = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(HEROES_PATH))
	_check(raw is Array and (raw as Array).size() == 3,
		"real authored three-hero party file opens")
	if not raw is Array or (raw as Array).size() != 3:
		return CombatParty.new([])
	var by_id: Dictionary = {}
	for record: Variant in (raw as Array):
		if record is Dictionary:
			by_id[String(record.get("id", ""))] = record
	var definitions: Array = []
	for hero_id: String in order:
		_check(by_id.has(hero_id), "authored party really contains " + hero_id)
		if not by_id.has(hero_id):
			return CombatParty.new([])
		var hero: Dictionary = (by_id[hero_id] as Dictionary).duplicate(true)
		hero["max_hp"] = int(hero.get("max_hp", 0))
		definitions.append(hero)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"real CombatParty is valid for order " + str(order))
	return party


func _deck(cards: Array[String], seed_value: int = 9601) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == CombatState.TURN_ENERGY,
		"real five-card, three-energy turn starts")
	return deck


func _test_warden_combat_outcomes() -> void:
	for case: Dictionary in [
		{"id": "warden_hold_the_line", "block": 5, "ally": 2},
		{"id": "warden_hold_the_line_plus", "block": 7, "ally": 3},
	]:
		var card_id: String = String(case["id"])
		# Warden front: a downed third hero joins every OTHER living hero.
		var party := _party()
		_check(party.apply_damage(3, 26) and party.is_downed(3),
			"tinker truly downed before Hold the Line " + card_id)
		var deck := _deck([card_id, card_id, "filler-a", "filler-b"])
		_check(deck.hand.has(card_id), "authentic hand really holds " + card_id)
		var result: Dictionary = CombatWardenPoolBlockCards.new().play_card(
			deck, party, card_id, 0)
		_check(result.get("ok", false), "real resolver plays " + card_id)
		if not result.get("ok", false):
			continue
		_check(party.get_hero(1)["block"] == int(case["block"])
			and party.get_hero(2)["block"] == int(case["ally"]),
			"%s gives Warden %d and the other living hero %d Block"
				% [card_id, int(case["block"]), int(case["ally"])])
		_check(party.get_hero(3)["block"] == 0 and party.is_downed(3),
			"downed hero gains no Block from " + card_id)
		_check(result.get("block_deltas", {}) == {
				1: int(case["block"]), 2: int(case["ally"])},
			"resolver receipt matches the Help amounts for " + card_id)
		# Warden in the middle slot: identity, never a fixed seat, decides.
		party = _party(["seamstress", "warden", "tinker"])
		_check(party.get_hero(2)["id"] == "warden" and party.apply_damage(3, 26),
			"Warden legally occupies the middle slot " + card_id)
		deck = _deck([card_id, card_id, "filler-c", "filler-d"], 9602)
		result = CombatWardenPoolBlockCards.new().play_card(deck, party, card_id, 0)
		_check(result.get("ok", false),
			"real resolver plays %s from the middle slot" % card_id)
		if result.get("ok", false):
			_check(party.get_hero(2)["block"] == int(case["block"])
				and party.get_hero(1)["block"] == int(case["ally"])
				and party.get_hero(3)["block"] == 0,
				"%s follows Warden's current position, not a fixed slot" % card_id)


func _test_bastion_quilt_outcomes() -> void:
	for case: Dictionary in [
		{"id": "warden_bastion_quilt", "block": 10},
		{"id": "warden_bastion_quilt_plus", "block": 13},
	]:
		var card_id: String = String(case["id"])
		var party := _party(["seamstress", "tinker", "warden"])
		_check(party.apply_damage(1, 30) and party.is_downed(1),
			"seamstress truly downed before Bastion Quilt " + card_id)
		var deck := _deck([card_id, card_id, "filler-a", "filler-b"], 9603)
		_check(deck.energy == CombatState.TURN_ENERGY and deck.hand.has(card_id),
			"three energy and a real held copy for " + card_id)
		var result: Dictionary = CombatWardenPoolBlockCards.new().play_card(
			deck, party, card_id, 0)
		_check(result.get("ok", false), "real resolver plays " + card_id)
		if not result.get("ok", false):
			continue
		_check(party.get_hero(2)["block"] == int(case["block"])
			and party.get_hero(3)["block"] == int(case["block"]),
			"%s gives every living hero %d Block" % [card_id, int(case["block"])])
		_check(party.get_hero(1)["block"] == 0 and party.is_downed(1),
			"downed hero gains no Block from " + card_id)
		_check(result.get("block_deltas", {}) == {
				2: int(case["block"]), 3: int(case["block"])},
			"resolver receipt names only living heroes for " + card_id)


func _test_field_mend_outcomes() -> void:
	for case: Dictionary in [
		{"id": "seamstress_field_mend", "heal": 4,
			"order": ["warden", "seamstress", "tinker"], "down": 3, "living": [1, 2]},
		{"id": "seamstress_field_mend_plus", "heal": 6,
			"order": ["warden", "tinker", "seamstress"], "down": 1, "living": [2, 3]},
	]:
		var card_id: String = String(case["id"])
		var heal: int = int(case["heal"])
		var down_position: int = int(case["down"])
		var living: Array = case["living"]
		# Downed hero: skipped, never revived; every living hero heals exactly.
		var party := _party(case["order"])
		_check(party.apply_damage(down_position, 99) and party.is_downed(down_position),
			"one hero truly downed before " + card_id)
		var wounded_before: Dictionary = {}
		for position: int in living:
			_check(party.apply_damage(position, 9),
				"living hero %d truly wounded before %s" % [position, card_id])
			wounded_before[position] = int(party.get_hero(position)["hp"])
		var deck := _deck([card_id, card_id, "filler-a", "filler-b"], 9604)
		var energy_before: int = deck.energy
		_check(deck.energy >= 2 and deck.hand.has(card_id),
			"Field Mend is affordable and held " + card_id)
		_check(party.get_hero(2)["id"] == "seamstress"
			or party.get_hero(3)["id"] == "seamstress",
			"Seamstress really occupies a legal 2-3 slot for " + card_id)
		_check(CombatSeamstressPoolHeals.new().play_card(deck, party, card_id, 0),
			"real resolver plays " + card_id)
		for position: int in living:
			var maximum: int = int(party.get_hero(position)["max_hp"])
			_check(party.get_hero(position)["hp"] == mini(maximum,
					int(wounded_before[position]) + heal),
				"%s heals living hero %d by %d HP" % [card_id, position, heal])
			_check(party.get_hero(position)["block"] == 0,
				"%s gives living hero %d no Block" % [card_id, position])
		_check(party.get_hero(down_position)["hp"] == 0
			and party.is_downed(down_position),
			"%s never revives the downed hero" % card_id)
		_check(deck.energy == energy_before - 2
			and deck.discard_pile.count(card_id) == 1,
			"%s really spent two energy and discarded one copy" % card_id)
		# Cap: an already full hero cannot overheal, wounded heroes gain exactly.
		party = _party(case["order"])
		_check(party.get_hero(down_position)["hp"] == int(
				party.get_hero(down_position)["max_hp"]),
			"untouched hero really sits at full HP for capped " + card_id)
		var cap_before: Dictionary = {}
		for position: int in [int(living[0]), int(living[1])]:
			_check(party.apply_damage(position, 5 if position == int(living[0]) else 10),
				"capped fixture really wounds hero %d for %s" % [position, card_id])
			cap_before[position] = int(party.get_hero(position)["hp"])
		deck = _deck([card_id, card_id, "filler-c", "filler-d"], 9605)
		_check(CombatSeamstressPoolHeals.new().play_card(deck, party, card_id, 0),
			"real resolver plays the capped case " + card_id)
		for position: int in [int(living[0]), int(living[1])]:
			var maximum: int = int(party.get_hero(position)["max_hp"])
			_check(party.get_hero(position)["hp"] == mini(maximum,
					int(cap_before[position]) + heal),
				"%s healing for hero %d is capped at its maximum HP"
					% [card_id, position])
		_check(party.get_hero(down_position)["hp"] == int(
				party.get_hero(down_position)["max_hp"]),
			"%s never overheals a hero already at maximum HP" % card_id)


func _test_darning_combat_outcomes() -> void:
	for case: Dictionary in [
		{"id": "seamstress_darning", "heal": 4, "block": 3},
		{"id": "seamstress_darning_plus", "heal": 6, "block": 4},
	]:
		var card_id: String = String(case["id"])
		var heal: int = int(case["heal"])
		var block: int = int(case["block"])
		# 1. Wounded ally: heals missing HP up to max_hp, grants exact Block.
		var party := _party(["warden", "seamstress", "tinker"])
		_check(party.apply_damage(1, 10), "target 1 wounded before " + card_id)
		var wounded_hp_before: int = party.get_hero(1)["hp"]
		var deck := _deck([card_id, card_id, "filler-a", "filler-b"], 9701)
		var energy_before: int = deck.energy
		_check(CombatSeamstressPoolHeals.new().play_card(deck, party, card_id, 1),
			"real resolver plays %s on wounded ally" % card_id)
		_check(party.get_hero(1)["hp"] == wounded_hp_before + heal
			and party.get_hero(1)["block"] == block,
			"%s heals %d HP and grants %d Block to wounded ally" % [card_id, heal, block])
		_check(deck.energy == energy_before - 1
			and deck.discard_pile.count(card_id) == 1,
			"%s spends 1 energy and discards 1 copy" % card_id)

		# 2. Full HP ally: healing restores 0 HP (capped at max), Block still applies!
		party = _party(["warden", "seamstress", "tinker"])
		var full_hp: int = party.get_hero(1)["max_hp"]
		_check(party.get_hero(1)["hp"] == full_hp, "ally 1 starts at full HP for " + card_id)
		deck = _deck([card_id, card_id, "filler-c", "filler-d"], 9702)
		_check(CombatSeamstressPoolHeals.new().play_card(deck, party, card_id, 1),
			"real resolver plays %s on full-HP ally" % card_id)
		_check(party.get_hero(1)["hp"] == full_hp
			and party.get_hero(1)["block"] == block,
			"%s on full-HP ally leaves HP at max and still grants %d Block" % [card_id, block])

		# 3. Downed ally: cannot revive, play rejected atomically.
		party = _party(["warden", "seamstress", "tinker"])
		_check(party.apply_damage(1, 99) and party.is_downed(1),
			"ally 1 truly downed for " + card_id)
		deck = _deck([card_id, card_id, "filler-e", "filler-f"], 9703)
		var snap_before := [deck.energy, deck.hand.duplicate(), party.get_hero(1)["hp"]]
		_check(not CombatSeamstressPoolHeals.new().play_card(deck, party, card_id, 1),
			"resolver rejects %s on downed ally" % card_id)
		_check(party.is_downed(1) and party.get_hero(1)["hp"] == 0
			and deck.energy == snap_before[0] and deck.hand == snap_before[1],
			"rejection on downed ally leaves energy, hand and downed hero untouched")


# --- Rejection and fail-closed coverage ------------------------------------

func _test_rejections() -> void:
	var hold := _support_definition("warden_hold_the_line", "warden", 1, [1, 2],
		"self", [], {"block": 5, "other_ally_block": 2})
	var hold_plus := _support_definition("warden_hold_the_line_plus", "warden", 1,
		[1, 2], "self", [], {"block": 7, "other_ally_block": 3})
	var bastion := _support_definition("warden_bastion_quilt", "warden", 3, [1, 2, 3],
		"party_all", [], {"block_all": 10})
	var bastion_plus := _support_definition("warden_bastion_quilt_plus", "warden", 3,
		[1, 2, 3], "party_all", [], {"block_all": 13})
	var field := _support_definition("seamstress_field_mend", "seamstress", 2, [2, 3],
		"party_all", [], {"heal": 4})
	var field_plus := _support_definition("seamstress_field_mend_plus", "seamstress", 2,
		[2, 3], "party_all", [], {"heal": 6})
	# Detached fixtures with the exact authored shape are explained too, proving
	# the row comes from the checked descriptor itself, not a catalog side table.
	for definition: Dictionary in [hold, hold_plus, bastion, bastion_plus, field,
			field_plus]:
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and _names(rows) == [PARTY_ROW],
			"exact detached support shape is explained " + String(definition["id"]))
	var darning_base := _support_definition("seamstress_darning", "seamstress", 1, [1, 2, 3],
		"ally_single", [], {"heal": 4, "block": 3})
	var darning_plus := _support_definition("seamstress_darning_plus", "seamstress", 1, [1, 2, 3],
		"ally_single", [], {"heal": 6, "block": 4})
	for definition: Dictionary in [darning_base, darning_plus]:
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and _names(rows) == [RESCUE_ROW],
			"exact detached Darning shape is explained " + String(definition["id"]))
	# Ordinary authored cards sharing one effect key never gain the new row.
	for real_definition: Dictionary in [warden.get_definition("warden_quick_darn"),
			warden.get_definition("warden_patch_guard"),

			seamstress.get_definition("seamstress_thimble_tea")]:
		_check(CardKeywordGlossary.describe(real_definition).is_empty(),
			"ordinary card %s never gains a Party support row"
				% String(real_definition.get("id", "")))
	_check(not _names(CardKeywordGlossary.describe(seamstress.get_definition("seamstress_darning"))).has(PARTY_ROW),
		"Darning never gains a Party support row")
	_check(not _names(CardKeywordGlossary.describe(seamstress.get_definition("seamstress_darning_plus"))).has(PARTY_ROW),
		"Darning+ never gains a Party support row")
	var fixtures: Array = []
	fixtures.append(["bare party effect without a card identity",
		_shape({"block": 5, "other_ally_block": 2})])
	fixtures.append(["bare heal effect without a card identity", _shape({"heal": 4})])
	fixtures.append(["Hold the Line effects on an unrelated Warden ID",
		_support_definition("warden_quick_darn", "warden", 1, [1, 2], "self", [],
			{"block": 5, "other_ally_block": 2})])
	fixtures.append(["Bastion Quilt effects on an unrelated Warden ID",
		_support_definition("warden_heavy_thimble", "warden", 3, [1, 2, 3],
			"party_all", [], {"block_all": 10})])
	fixtures.append(["Field Mend effects on an unrelated Seamstress ID",
		_support_definition("seamstress_thimble_tea", "seamstress", 2, [2, 3],
			"party_all", [], {"heal": 4})])
	var fixture := hold.duplicate(true)
	fixture["owner"] = "seamstress"
	fixtures.append(["Hold the Line with the wrong owner", fixture])
	fixture = bastion.duplicate(true)
	fixture["owner"] = "seamstress"
	fixtures.append(["Bastion Quilt with the wrong owner", fixture])
	fixture = field.duplicate(true)
	fixture["owner"] = "warden"
	fixtures.append(["Field Mend with the wrong owner", fixture])
	fixture = hold.duplicate(true)
	fixture["cost"] = 2
	fixtures.append(["Hold the Line with the wrong cost", fixture])
	fixture = hold_plus.duplicate(true)
	fixture["cost"] = 2
	fixtures.append(["Hold the Line+ with the wrong cost", fixture])
	fixture = bastion.duplicate(true)
	fixture["cost"] = 2
	fixtures.append(["Bastion Quilt with the wrong cost", fixture])
	fixture = field_plus.duplicate(true)
	fixture["cost"] = 1
	fixtures.append(["Field Mend+ with the wrong cost", fixture])
	fixture = hold.duplicate(true)
	fixture["from_positions"] = [1, 2, 3]
	fixtures.append(["Hold the Line from every slot", fixture])
	fixture = hold.duplicate(true)
	fixture["from_positions"] = [2, 3]
	fixtures.append(["Hold the Line from the back slots only", fixture])
	fixture = hold.duplicate(true)
	fixture["from_positions"] = [1]
	fixtures.append(["Hold the Line from the front slot only", fixture])
	fixture = bastion.duplicate(true)
	fixture["from_positions"] = [1, 2]
	fixtures.append(["Bastion Quilt from two slots only", fixture])
	fixture = bastion.duplicate(true)
	fixture["from_positions"] = [1, 2, 4]
	fixtures.append(["Bastion Quilt from an illegal slot", fixture])
	fixture = field.duplicate(true)
	fixture["from_positions"] = [1, 2, 3]
	fixtures.append(["Field Mend from an illegal front slot", fixture])
	fixture = field.duplicate(true)
	fixture["from_positions"] = [1, 2]
	fixtures.append(["Field Mend from the wrong two slots", fixture])
	fixture = field.duplicate(true)
	fixture["from_positions"] = "2,3"
	fixtures.append(["Field Mend with text source slots", fixture])
	fixture = hold.duplicate(true)
	fixture["target_kind"] = "party_all"
	fixtures.append(["Hold the Line with a party target", fixture])
	fixture = bastion.duplicate(true)
	fixture["target_kind"] = "self"
	fixtures.append(["Bastion Quilt with a self target", fixture])
	fixture = field.duplicate(true)
	fixture["target_kind"] = "ally_single"
	fixtures.append(["Field Mend with a single-ally target", fixture])
	fixture = hold.duplicate(true)
	fixture["to_positions"] = [1]
	fixtures.append(["Hold the Line with a target slot", fixture])
	fixture = bastion.duplicate(true)
	fixture["to_positions"] = [2]
	fixtures.append(["Bastion Quilt with a target slot", fixture])
	fixture = field.duplicate(true)
	fixture["to_positions"] = [1]
	fixtures.append(["Field Mend with a target slot", fixture])
	fixture = hold.duplicate(true)
	fixture.erase("to_positions")
	fixtures.append(["Hold the Line without a target list", fixture])
	fixture = hold.duplicate(true)
	fixture["effects"]["bleed"] = 1
	fixtures.append(["Hold the Line with an extra effect", fixture])
	fixture = bastion.duplicate(true)
	fixture["effects"]["heal"] = 1
	fixtures.append(["Bastion Quilt with an extra effect", fixture])
	fixture = field.duplicate(true)
	fixture["effects"]["block"] = 3
	fixtures.append(["Field Mend with an extra effect", fixture])
	fixture = hold.duplicate(true)
	fixture["effects"].erase("other_ally_block")
	fixtures.append(["Hold the Line without the ally amount", fixture])
	fixture = bastion.duplicate(true)
	fixture["effects"] = {"block": 10}
	fixtures.append(["Bastion Quilt with the plain Block key", fixture])
	fixture = field.duplicate(true)
	fixture["effects"] = {"block": 4}
	fixtures.append(["Field Mend without a heal", fixture])
	fixture = hold.duplicate(true)
	fixture["effects"] = {"block": 7, "other_ally_block": 3}
	fixtures.append(["base Hold the Line with upgraded amounts", fixture])
	fixture = hold_plus.duplicate(true)
	fixture["effects"] = {"block": 5, "other_ally_block": 2}
	fixtures.append(["Hold the Line+ with base amounts", fixture])
	fixture = bastion.duplicate(true)
	fixture["effects"] = {"block_all": 13}
	fixtures.append(["base Bastion Quilt with upgraded Block", fixture])
	fixture = bastion_plus.duplicate(true)
	fixture["effects"] = {"block_all": 10}
	fixtures.append(["Bastion Quilt+ with base Block", fixture])
	fixture = field.duplicate(true)
	fixture["effects"] = {"heal": 6}
	fixtures.append(["base Field Mend with upgraded healing", fixture])
	fixture = field_plus.duplicate(true)
	fixture["effects"] = {"heal": 4}
	fixtures.append(["Field Mend+ with base healing", fixture])
	fixture = hold.duplicate(true)
	fixture["cost"] = "1"
	fixtures.append(["Hold the Line with text cost", fixture])
	fixture = hold.duplicate(true)
	fixture["effects"]["block"] = 5.0
	fixtures.append(["Hold the Line with a float amount", fixture])
	fixture = field.duplicate(true)
	fixture["effects"]["heal"] = "4"
	fixtures.append(["Field Mend with text healing", fixture])
	fixture = hold.duplicate(true)
	fixture["id"] = 7
	fixtures.append(["non-string support ID", fixture])
	fixture = hold.duplicate(true)
	fixture.erase("id")
	fixtures.append(["support descriptor without a card ID", fixture])
	fixture = hold.duplicate(true)
	fixture["id"] = "warden_hold_the_line_plus_plus"
	fixtures.append(["similarly named Hold the Line", fixture])
	fixture = field.duplicate(true)
	fixture["id"] = "seamstress_field_mend_plus_plus"
	fixtures.append(["similarly named Field Mend", fixture])
	fixture = hold.duplicate(true)
	fixture["effects"] = "block"
	fixtures.append(["unreadable support effect block", fixture])
	fixtures.append(["bare Darning heal and block without card identity",
		_shape({"heal": 4, "block": 3})])
	fixtures.append(["Darning effects on an unrelated Seamstress ID",
		_support_definition("seamstress_running_stitch", "seamstress", 1, [1, 2, 3],
			"ally_single", [], {"heal": 4, "block": 3})])
	fixtures.append(["Darning effects on an unrelated Warden ID",
		_support_definition("warden_strike", "warden", 1, [1, 2, 3],
			"ally_single", [], {"heal": 4, "block": 3})])
	fixture = darning_base.duplicate(true)
	fixture["owner"] = "warden"
	fixtures.append(["Darning with wrong owner", fixture])
	fixture = darning_base.duplicate(true)
	fixture["owner"] = "tinker"
	fixtures.append(["Darning with Tinker owner", fixture])
	fixture = darning_base.duplicate(true)
	fixture["cost"] = 0
	fixtures.append(["Darning with cost 0", fixture])
	fixture = darning_base.duplicate(true)
	fixture["cost"] = 2
	fixtures.append(["Darning with cost 2", fixture])
	fixture = darning_plus.duplicate(true)
	fixture["cost"] = 0
	fixtures.append(["Darning+ with cost 0", fixture])
	fixture = darning_plus.duplicate(true)
	fixture["cost"] = 2
	fixtures.append(["Darning+ with cost 2", fixture])
	fixture = darning_base.duplicate(true)
	fixture["cost"] = "1"
	fixtures.append(["Darning with text cost", fixture])
	fixture = darning_base.duplicate(true)
	fixture["from_positions"] = [2, 3]
	fixtures.append(["Darning from back slots only", fixture])
	fixture = darning_base.duplicate(true)
	fixture["from_positions"] = [1, 2]
	fixtures.append(["Darning from front slots only", fixture])
	fixture = darning_base.duplicate(true)
	fixture["from_positions"] = [1]
	fixtures.append(["Darning from slot 1 only", fixture])
	fixture = darning_base.duplicate(true)
	fixture["from_positions"] = []
	fixtures.append(["Darning from empty slots", fixture])
	fixture = darning_base.duplicate(true)
	fixture["from_positions"] = [1, 2, 4]
	fixtures.append(["Darning from an illegal slot", fixture])
	fixture = darning_base.duplicate(true)
	fixture["from_positions"] = "1,2,3"
	fixtures.append(["Darning with text source slots", fixture])
	fixture = darning_base.duplicate(true)
	fixture["target_kind"] = "enemy_single"
	fixtures.append(["Darning with enemy target", fixture])
	fixture = darning_base.duplicate(true)
	fixture["target_kind"] = "self"
	fixtures.append(["Darning with self target", fixture])
	fixture = darning_base.duplicate(true)
	fixture["target_kind"] = "party_all"
	fixtures.append(["Darning with party target", fixture])
	fixture = darning_base.duplicate(true)
	fixture["to_positions"] = [1]
	fixtures.append(["Darning with a target slot", fixture])
	fixture = darning_base.duplicate(true)
	fixture.erase("to_positions")
	fixtures.append(["Darning without a target list", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"]["bleed"] = 1
	fixtures.append(["Darning with extra Bleed effect", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"]["damage"] = 3
	fixtures.append(["Darning with extra damage effect", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"].erase("block")
	fixtures.append(["Darning without Block effect", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"].erase("heal")
	fixtures.append(["Darning without heal effect", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"] = {"heal": 6, "block": 4}
	fixtures.append(["base Darning with upgraded amounts", fixture])
	fixture = darning_plus.duplicate(true)
	fixture["effects"] = {"heal": 4, "block": 3}
	fixtures.append(["Darning+ with base amounts", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"]["heal"] = 4.0
	fixtures.append(["Darning with float heal", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"]["block"] = 3.0
	fixtures.append(["Darning with float Block", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"]["heal"] = "4"
	fixtures.append(["Darning with text heal", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"]["block"] = "3"
	fixtures.append(["Darning with text Block", fixture])
	fixture = darning_base.duplicate(true)
	fixture["id"] = 7
	fixtures.append(["non-string Darning ID", fixture])
	fixture = darning_base.duplicate(true)
	fixture.erase("id")
	fixtures.append(["Darning descriptor without card ID", fixture])
	fixture = darning_base.duplicate(true)
	fixture["id"] = "seamstress_darning_plus_plus"
	fixtures.append(["similarly named Darning ID", fixture])
	fixture = darning_base.duplicate(true)
	fixture["effects"] = "heal and block"
	fixtures.append(["unreadable Darning effect block", fixture])
	for case in fixtures:
		var broken: Dictionary = case[1]
		var broken_before: Dictionary = broken.duplicate(true)
		var rows := CardKeywordGlossary.describe(broken)
		_check(not _names(rows).has(PARTY_ROW),
			"%s never fabricates a Party support row" % String(case[0]))
		_check(not _names(rows).has(RESCUE_ROW),
			"%s never fabricates a Mixed rescue row" % String(case[0]))
		_check(broken == broken_before,
			"%s leaves the fixture untouched" % String(case[0]))
	_check(hold == _support_definition("warden_hold_the_line", "warden", 1, [1, 2],
			"self", [], {"block": 5, "other_ally_block": 2})
		and field_plus == _support_definition("seamstress_field_mend_plus",
			"seamstress", 2, [2, 3], "party_all", [], {"heal": 6})
		and darning_base == _support_definition("seamstress_darning", "seamstress", 1, [1, 2, 3],
			"ally_single", [], {"heal": 4, "block": 3})
		and darning_plus == _support_definition("seamstress_darning_plus", "seamstress", 1, [1, 2, 3],
			"ally_single", [], {"heal": 6, "block": 4}),
		"negative cases never mutate the positive fixtures")


# --- Ordering, detachment and RNG-free reads -------------------------------

func _test_ordering_detachment_and_rng() -> void:
	# The existing keyword and special rows keep their established content and
	# order; only the new support row was appended after them.
	_check(CardKeywordGlossary.KEYWORD_ORDER == ["bleed", "weak", "exposed",
		"pinned", "unravel", "guarding", "thorns"]
		and CardKeywordGlossary.SPECIAL_ORDER == ["conditional_damage", "random_hit",
			"energy_tradeoff", "bleed_doubling", "two_hits"],
		"keyword and special order constants are unchanged")
	var combined := {"id": "warden_strike", "effects": {
		"bleed": 2, "weak": 1, "exposed": 1, "pinned": true, "unravel": 3,
		"guarding": true, "thorns": 3, "junk": 4,
		"conditional_damage": {"damage": 9, "operator": "or",
			"conditions": [{"status": "unravelled"}]},
		"damage": 4, "hit_count": 3, "random_target_each_hit": true,
		"rng_source": "run", "living_targets_only": true}}
	var combined_before: Dictionary = combined.duplicate(true)
	_check(_names(CardKeywordGlossary.describe(combined)) == [
		"Bleed 2", "Weak 1", "Exposed 1", "Pinned", "Unravel 3", "Guarding",
		"Thorns 3", "Conditional damage", "Random hits"],
		"combined descriptor keeps every pre-existing row in its original order")
	_check(combined == combined_before, "combined descriptor is never mutated")
	# An extended support descriptor drops the support claim but keeps the row it
	# genuinely authors, exactly as the other special rules already fail closed.
	var extended := _support_definition("warden_hold_the_line", "warden", 1, [1, 2],
		"self", [], {"block": 5, "other_ally_block": 2, "bleed": 1})
	_check(_names(CardKeywordGlossary.describe(extended)) == ["Bleed 1"],
		"extended Hold the Line keeps only its authored Bleed row")
	var extended_darning := _support_definition("seamstress_darning", "seamstress", 1, [1, 2, 3],
		"ally_single", [], {"heal": 4, "block": 3, "bleed": 1})
	_check(_names(CardKeywordGlossary.describe(extended_darning)) == ["Bleed 1"],
		"extended Darning keeps only its authored Bleed row")
	for case: Dictionary in _authentic_cases():
		var card_id: String = String(case["id"])
		var catalog: Variant = case["catalog"]
		var original: Dictionary = catalog.get_definition(card_id)
		var first := CardKeywordGlossary.describe(original)
		var second := CardKeywordGlossary.describe(original)
		_check(first == second and first.size() == 1,
			"repeated Help reads are identical for " + card_id)
		if first.size() != 1:
			continue
		first[0]["keyword"] = "Tampered"
		first[0]["explanation"] = "Tampered"
		var third := CardKeywordGlossary.describe(original)
		_check(third.size() == 1 and String(third[0]["keyword"]) == PARTY_ROW
			and String(third[0]["explanation"]).contains(
				String(case["phrases"][0])) and original == catalog.get_definition(card_id),
			"Help results are detached from the caller's definition " + card_id)
	for case: Dictionary in _authentic_darning_cases():
		var card_id: String = String(case["id"])
		var catalog: Variant = case["catalog"]
		var original: Dictionary = catalog.get_definition(card_id)
		var first := CardKeywordGlossary.describe(original)
		var second := CardKeywordGlossary.describe(original)
		_check(first == second and first.size() == 1,
			"repeated Help reads are identical for " + card_id)
		if first.size() != 1:
			continue
		first[0]["keyword"] = "Tampered"
		first[0]["explanation"] = "Tampered"
		var third := CardKeywordGlossary.describe(original)
		_check(third.size() == 1 and String(third[0]["keyword"]) == RESCUE_ROW
			and String(third[0]["explanation"]).contains(
				String(case["phrases"][0])) and original == catalog.get_definition(card_id),
			"Help results are detached from the caller's definition " + card_id)
	# Help never consumes the shared global RNG: the next random number is the
	# same with or without these reads in between.
	seed(77123)
	var expected_next: int = randi()
	seed(77123)
	for case: Dictionary in _authentic_cases():
		var catalog: Variant = case["catalog"]
		CardKeywordGlossary.describe(catalog.get_definition(String(case["id"])))
	for case: Dictionary in _authentic_darning_cases():
		var catalog: Variant = case["catalog"]
		CardKeywordGlossary.describe(catalog.get_definition(String(case["id"])))
	CardKeywordGlossary.describe(combined)
	var after: int = randi()
	_check(after == expected_next,
		"Party support Help reads never advance the global RNG")
