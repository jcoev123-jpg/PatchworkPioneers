extends SceneTree
## Deterministic D2-1 pool-heal contract, using real catalog, deck and party.

const CASES := {
	"seamstress_darning": {"cost": 1, "from": [1, 2, 3], "kind": "ally_single",
		"effects": {"heal": 4, "block": 3}},
	"seamstress_darning_plus": {"cost": 1, "from": [1, 2, 3], "kind": "ally_single",
		"effects": {"heal": 6, "block": 4}},
	"seamstress_thimble_tea": {"cost": 0, "from": [2, 3], "kind": "ally_single",
		"effects": {"heal": 3}},
	"seamstress_thimble_tea_plus": {"cost": 0, "from": [2, 3], "kind": "ally_single",
		"effects": {"heal": 4}},
	"seamstress_field_mend": {"cost": 2, "from": [2, 3], "kind": "party_all",
		"effects": {"heal": 4}},
	"seamstress_field_mend_plus": {"cost": 2, "from": [2, 3], "kind": "party_all",
		"effects": {"heal": 6}},
}

var checks: int = 0
var failures: Array[String] = []
var catalog := SeamstressPoolCards.new()
var resolver := CombatSeamstressPoolHeals.new()


func _initialize() -> void:
	_test_authored_definitions_and_all_six()
	_test_full_hp_and_two_copies()
	_test_owner_moves_and_downed_field_mend()
	_test_atomic_rejections()
	_test_replay()
	for failure: String in failures:
		printerr(failure)
	print("combat_seamstress_pool_heals_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _party(order: Array[String] = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	_check(raw is Array, "real starter_party.json is an array")
	if not raw is Array:
		return CombatParty.new([])
	var by_id: Dictionary = {}
	for record in raw:
		if record is Dictionary:
			by_id[record.get("id", "")] = record
	var definitions: Array = []
	for hero_id: String in order:
		_check(by_id.has(hero_id), "authored party contains " + hero_id)
		if not by_id.has(hero_id):
			return CombatParty.new([])
		var hero: Dictionary = by_id[hero_id].duplicate(true)
		var maximum: Variant = hero.get("max_hp")
		_check((maximum is float or maximum is int) and float(maximum) == floor(float(maximum)),
			"authored HP is integral for " + hero_id)
		if not (maximum is float or maximum is int):
			return CombatParty.new([])
		hero["max_hp"] = int(maximum)
		definitions.append(hero)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"real three-hero CombatParty is valid")
	for position in range(1, 4):
		var hero: Dictionary = party.get_hero(position)
		_check(hero.get("id") == order[position - 1] and hero.get("position") == position
			and hero.get("hp") == hero.get("max_hp"), "real hero identity, slot and HP")
	return party


func _deck(cards: Array[String], seed_value: int = 42, start: bool = true) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	if start:
		_check(deck.start_turn() and deck.turn_active
			and deck.energy == CombatState.TURN_ENERGY, "real five-draw, three-energy turn")
		_check(deck.hand.size() == mini(CombatDeck.TURN_DRAW, cards.size()),
			"deck drew five or all remaining cards")
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	return {
		"heroes": party.get_heroes(),
		"draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"turn_active": deck.turn_active,
		"energy": deck.energy,
		"state_turn": deck.combat_state.player_turn_active,
		"state_energy": deck.combat_state.energy,
		"rng": deck._rng.state,
	}


func _expected(before: Dictionary, card_id: String, target: int) -> Dictionary:
	# Oracle uses named design expectations, not the implementation's effects.
	var after: Dictionary = before.duplicate(true)
	var spec: Dictionary = CASES[card_id]
	var effects: Dictionary = spec["effects"]
	after["energy"] -= spec["cost"]
	after["state_energy"] -= spec["cost"]
	if spec["kind"] == "party_all":
		for hero: Dictionary in after["heroes"]:
			if hero["hp"] > 0:
				hero["hp"] = mini(hero["max_hp"], hero["hp"] + effects["heal"])
	else:
		var hero: Dictionary = after["heroes"][target - 1]
		hero["hp"] = mini(hero["max_hp"], hero["hp"] + effects["heal"])
		hero["block"] += effects.get("block", 0)
	after["hand"].remove_at(after["hand"].find(card_id))
	after["discard"].append(card_id)
	return after


func _played(deck: CombatDeck, party: CombatParty, id: String, target: int,
		label: String) -> void:
	var before: Dictionary = _snapshot(deck, party)
	_check(deck.turn_active and party.is_valid() and deck.hand.has(id),
		label + ": authentic precondition (active hand, valid party)")
	_check(deck.energy >= CASES[id]["cost"], label + ": affordable before action")
	var expected: Dictionary = _expected(before, id, target)
	_check(resolver.play_card(deck, party, id, target), label + ": succeeds")
	_check(_snapshot(deck, party) == expected,
		label + ": exact HP, Block, caps, all piles, three-energy budget and RNG")
	_check(deck.hand.count(id) == before["hand"].count(id) - 1
		and deck.discard_pile.count(id) == before["discard"].count(id) + 1,
		label + ": exactly one matching copy is discarded")


func _rejected(deck: CombatDeck, party: CombatParty, id: String, target: int,
		label: String) -> void:
	var before: Dictionary = _snapshot(deck, party)
	_check(not resolver.play_card(deck, party, id, target), label + ": rejects")
	_check(_snapshot(deck, party) == before,
		label + ": atomic rejection preserves HP, Block, piles, energy and RNG")


func _wound_all(party: CombatParty) -> void:
	_check(party.apply_damage(1, 9) and party.apply_damage(2, 5)
		and party.apply_damage(3, 8), "all three living heroes genuinely wounded")
	_check(party.gain_block(1, 2) and party.gain_block(3, 3),
		"preexisting Block belongs to two different recipients")
	_check(party.get_hero(1)["hp"] == 31 and party.get_hero(3)["block"] == 3,
		"wound/Block fixture verified before resolution")


func _test_authored_definitions_and_all_six() -> void:
	for id: String in CASES:
		var spec: Dictionary = CASES[id]
		var definition: Dictionary = catalog.get_definition(id)
		_check(not definition.is_empty() and catalog.has_card(id),
			id + ": authentic catalog entry exists")
		_check(definition.get("id") == id and definition.get("owner") == "seamstress",
			id + ": authoritative ID and owner")
		_check(definition.get("cost") == spec["cost"]
			and definition.get("from_positions") == spec["from"]
			and definition.get("target_kind") == spec["kind"]
			and definition.get("to_positions") == []
			and definition.get("effects") == spec["effects"],
			id + ": all printed cost, slots, target kind and effect amounts")
		var party := _party()
		_wound_all(party)
		# Seven real cards leave two in the draw pile; four copies guarantee
		# at least two copies in the initial five-card hand for any seed.
		var deck := _deck([id, id, id, id, "filler-a", "filler-b", "filler-c"])
		_check(deck.hand.count(id) >= 2 and deck.draw_pile.size() == 2,
			id + ": real shuffled hand has duplicates and remaining draw order")
		var target: int = 0 if spec["kind"] == "party_all" else (3 if id in [
			"seamstress_thimble_tea", "seamstress_thimble_tea_plus"] else 1)
		_played(deck, party, id, target, id)


func _test_full_hp_and_two_copies() -> void:
	var party := _party()
	_check(party.gain_block(2, 7), "full-HP target has prior Block")
	var id := "seamstress_darning_plus"
	var deck := _deck([id, id, "filler-a", "filler-b", "filler-c"])
	_check(party.get_hero(2)["hp"] == 30 and deck.hand.count(id) == 2,
		"full-HP Seamstress and two copies really in hand")
	_played(deck, party, id, 2, "Darning+ on full-HP self")
	_check(party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 11,
		"full HP still pays once and gains exactly four Block")
	_check(deck.hand.count(id) == 1 and deck.energy == 2,
		"other Darning+ copy remains playable")
	_played(deck, party, id, 2, "second Darning+ copy")
	_check(party.get_hero(2)["block"] == 15 and deck.energy == 1,
		"both paid plays stack Block without overhealing")


func _test_owner_moves_and_downed_field_mend() -> void:
	var party := _party(["seamstress", "warden", "tinker"])
	_check(party.apply_damage(3, 10) and party.get_hero(1)["id"] == "seamstress",
		"Seamstress legally occupies front slot")
	var deck := _deck(["seamstress_darning"])
	_played(deck, party, "seamstress_darning", 3, "Darning legal from front")

	party = _party(["warden", "tinker", "seamstress"])
	_check(party.apply_damage(1, 8) and party.get_hero(3)["id"] == "seamstress",
		"Seamstress moved to back slot with wounded Warden")
	deck = _deck(["seamstress_thimble_tea_plus", "seamstress_field_mend"])
	_played(deck, party, "seamstress_thimble_tea_plus", 1,
		"Tea+ follows owner identity in back slot")
	_played(deck, party, "seamstress_field_mend", 0,
		"Field Mend follows owner identity in back slot")

	party = _party()
	_check(party.apply_damage(1, 40) and party.is_downed(1),
		"Field Mend target is actually downed at zero HP")
	_check(party.apply_damage(2, 10) and party.apply_damage(3, 9)
		and party.gain_block(3, 4), "other two living Field Mend targets wounded")
	deck = _deck(["seamstress_field_mend_plus"])
	_played(deck, party, "seamstress_field_mend_plus", 0,
		"Field Mend+ skips downed slot and heals other two")
	_check(party.is_downed(1) and party.get_hero(1)["hp"] == 0
		and party.get_hero(3)["block"] == 4,
		"Field Mend+ neither revives a downed hero nor changes existing Block")


func _test_atomic_rejections() -> void:
	var party := _party()
	var deck := _deck(["seamstress_darning", "seamstress_thimble_tea",
		"seamstress_field_mend", "seamstress_running_stitch", "other"])
	_check(deck.hand.has("seamstress_darning") and deck.hand.has("seamstress_field_mend"),
		"negative case has authentic three healing cards")
	_rejected(deck, party, "seamstress_darning", 0, "Darning missing selection")
	_rejected(deck, party, "seamstress_thimble_tea", 0, "Tea missing selection")
	for target in [-1, 4]:
		_rejected(deck, party, "seamstress_darning", target, "Darning invalid slot " + str(target))
		_rejected(deck, party, "seamstress_thimble_tea", target, "Tea invalid slot " + str(target))
	for target in [-1, 1, 4]:
		_rejected(deck, party, "seamstress_field_mend", target,
			"party_all forbids selected slot " + str(target))
	_rejected(deck, party, "seamstress_field_mend_plus", 0, "upgrade absent from hand")
	_rejected(deck, party, "seamstress_darning_plus", 1, "Darning upgrade absent from hand")
	_rejected(deck, party, "seamstress_running_stitch", 1,
		"real but unhandled pool attack ID rejected")
	_rejected(deck, party, "seamstress_not_a_card", 1,
		"unknown card ID rejected even when present in hand")

	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"chosen ally is genuinely downed")
	_rejected(deck, party, "seamstress_darning", 3, "Darning cannot revive")
	_rejected(deck, party, "seamstress_thimble_tea", 3, "Tea cannot revive")

	party = _party(["seamstress", "warden", "tinker"])
	deck = _deck(["seamstress_thimble_tea", "seamstress_field_mend"])
	_check(party.get_hero(1)["id"] == "seamstress", "wrong-slot owner fixture")
	_rejected(deck, party, "seamstress_thimble_tea", 2, "Tea owner at illegal front slot")
	_rejected(deck, party, "seamstress_field_mend", 0, "Field owner at illegal front slot")

	party = _party()
	deck = _deck(["seamstress_darning", "seamstress_thimble_tea",
		"seamstress_field_mend"])
	_check(party.apply_damage(2, 30) and party.is_downed(2), "owner truly downed")
	_rejected(deck, party, "seamstress_darning", 1, "downed owner Darning")
	_rejected(deck, party, "seamstress_thimble_tea", 1, "downed owner Tea")
	_rejected(deck, party, "seamstress_field_mend", 0, "downed owner Field")

	party = _party()
	deck = _deck(["seamstress_darning", "seamstress_field_mend"])
	_check(deck.try_spend_energy(2) and deck.energy == 1, "Field cannot afford two energy")
	_rejected(deck, party, "seamstress_field_mend", 0, "Field insufficient energy")
	_check(deck.try_spend_energy(1) and deck.energy == 0, "Darning cannot afford one energy")
	_rejected(deck, party, "seamstress_darning", 1, "Darning exhausted energy")
	var zero_deck := _deck(["seamstress_thimble_tea"])
	_check(zero_deck.try_spend_energy(3) and zero_deck.energy == 0,
		"zero-cost exception truly has no energy")
	_played(zero_deck, party, "seamstress_thimble_tea", 1,
		"Tea legitimately plays with exhausted energy")

	party = _party()
	_check(party.apply_damage(1, 7) and party.gain_block(1, CombatParty.MAX_INT - 2),
		"Darning overflow fixture has wounded recipient near MAX_INT")
	deck = _deck(["seamstress_darning", "seamstress_darning_plus"])
	_rejected(deck, party, "seamstress_darning", 1,
		"Block overflow preflight rejects before healing")
	_rejected(deck, party, "seamstress_darning_plus", 1,
		"Block overflow preflight rejects upgrade before healing")

	party = _party()
	deck = _deck(["seamstress_darning"], 71, false)
	_check(not deck.turn_active and deck.energy == 0 and deck.hand.is_empty(),
		"turn really inactive with card still in draw")
	_rejected(deck, party, "seamstress_darning", 1, "inactive turn")
	_check(deck.start_turn(), "inactive fixture can start after rejection")
	_rejected(deck, CombatParty.new([]), "seamstress_darning", 1, "invalid party")
	_check(not resolver.play_card(null, party, "seamstress_darning", 1)
		and not resolver.play_card(deck, null, "seamstress_darning", 1),
		"null authorities safely reject")


func _sequence(seed_value: int) -> Array:
	var party := _party()
	_wound_all(party)
	var deck := _deck(["seamstress_darning", "seamstress_thimble_tea",
		"seamstress_field_mend", "filler-a", "filler-b"], seed_value)
	var trace: Array = [_snapshot(deck, party)]
	_check(deck.hand.has("seamstress_darning") and deck.hand.has("seamstress_thimble_tea")
		and deck.hand.has("seamstress_field_mend"), "replay draws all three actual cards")
	_played(deck, party, "seamstress_darning", 1, "replay Darning")
	trace.append(_snapshot(deck, party))
	_played(deck, party, "seamstress_thimble_tea", 3, "replay Tea")
	trace.append(_snapshot(deck, party))
	_played(deck, party, "seamstress_field_mend", 0, "replay Field")
	trace.append(_snapshot(deck, party))
	_check(deck.energy == 0 and deck.discard_pile.size() == 3,
		"replay uses full three-energy budget and discards three genuine copies")
	_check(deck.end_turn() and party.start_player_turn() and deck.start_turn(),
		"real turn boundary discards hand, clears Block and refills via seeded RNG")
	trace.append(_snapshot(deck, party))
	_check(party.get_hero(1)["block"] == 0 and party.get_hero(3)["block"] == 0,
		"next player turn resets accumulated Block")
	return trace


func _test_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var first: Array = _sequence(seed_value)
		var second: Array = _sequence(seed_value)
		_check(first.size() == 5 and second.size() == 5,
			"both runs record real initial, three plays and next-turn snapshots")
		_check(first == second,
			"same seeded run replays hand, energy, every hero, discard, draw and RNG")
