extends SceneTree

const SUPPORT_IDS: Array[String] = ["warden_brace", "seamstress_mend",
	"seamstress_stitch_up", "tinker_tune_up"]
const ATTACK_IDS: Array[String] = ["warden_strike", "warden_shield_bash",
	"seamstress_prick", "tinker_pop_shot", "tinker_scrap_bomb"]

var failures: Array[String] = []
var checks := 0
var catalog := StarterCards.new()
var adapter := CombatStarterSupportPlay.new()


func _initialize() -> void:
	_test_real_catalog()
	_test_brace()
	_test_heal_and_block()
	_test_tune_up()
	_test_rejections()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("combat_starter_support_play_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


func _party(order: Array[String] = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var content := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var authored = JSON.parse_string(content)
	if not authored is Array:
		_check(false, "authored starter_party.json loads as an array")
		return CombatParty.new([])
	var indexed: Dictionary = {}
	for hero in authored:
		if hero is Dictionary:
			indexed[hero.get("id")] = hero
	var definitions: Array = []
	for hero_id in order:
		if not indexed.has(hero_id):
			_check(false, "authored hero exists: " + hero_id)
			return CombatParty.new([])
		var definition: Dictionary = indexed[hero_id].duplicate(true)
		# JSON stores numbers as floats; CombatParty requires integral max_hp.
		var authored_hp = definition["max_hp"]
		if not (authored_hp is float or authored_hp is int) or float(authored_hp) != floor(float(authored_hp)):
			_check(false, "starter hero max HP is integral: " + hero_id)
			return CombatParty.new([])
		definition["max_hp"] = int(authored_hp)
		definitions.append(definition)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"real authored party is valid with positional heroes")
	if party.is_valid():
		for index in range(3):
			var hero := party.get_hero(index + 1)
			_check(hero["id"] == order[index] and hero["position"] == index + 1
				and hero["max_hp"] == indexed[order[index]]["max_hp"]
				and hero["hp"] == hero["max_hp"],
				"hero position and max HP come from starter_party.json")
	return party


func _deck(cards: Array[String], seed_value: int = 42) -> CombatDeck:
	for card_id in cards:
		_check(catalog.has_card(card_id), "fixture deck uses real authored ID: " + card_id)
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == CombatState.TURN_ENERGY,
		"actual shared turn starts with authored cards and three energy")
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var definitions: Dictionary = {}
	for card_id in SUPPORT_IDS + ATTACK_IDS:
		definitions[card_id] = catalog.get_definition(card_id)
	return {
		"heroes": party.get_heroes(),
		"hand": deck.hand.duplicate(),
		"draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"turn_active": deck.turn_active,
		"energy": deck.energy,
		"combat_state": {
			"player_turn_active": deck.combat_state.player_turn_active,
			"energy": deck.combat_state.energy,
		},
		"rng_state": deck._rng.state,
		"catalog": definitions,
	}


func _expected(before: Dictionary, card_id: String, recipient: int = 0) -> Dictionary:
	var after := before.duplicate(true)
	var definition: Dictionary = catalog.get_definition(card_id)
	after["energy"] -= definition["cost"]
	after["combat_state"]["energy"] -= definition["cost"]
	if card_id == "tinker_tune_up":
		_oracle_draw(after, 1)
	else:
		var hero: Dictionary = after["heroes"][recipient - 1]
		match card_id:
			"warden_brace":
				hero["block"] += 7
			"seamstress_mend":
				hero["hp"] = mini(hero["max_hp"], hero["hp"] + 5)
			"seamstress_stitch_up":
				hero["block"] += 5
	after["hand"].remove_at(after["hand"].find(card_id))
	after["discard"].append(card_id)
	return after


func _oracle_draw(state: Dictionary, count: int) -> void:
	# Independent seeded oracle for the existing deck's draw/refill ordering.
	var generator := _rng(0)
	generator.state = state["rng_state"]
	var pile: Array = state["draw"]
	var hand: Array = state["hand"]
	var discard: Array = state["discard"]
	for n in range(count):
		if pile.is_empty():
			if discard.is_empty():
				break
			pile.append_array(discard)
			discard.clear()
			for index in range(pile.size() - 1, 0, -1):
				var other := generator.randi_range(0, index)
				var temp = pile[index]
				pile[index] = pile[other]
				pile[other] = temp
		hand.append(pile.pop_back())
	state["rng_state"] = generator.state


func _accepted(deck: CombatDeck, party: CombatParty, card_id: String,
		target: int, recipient: int, label: String) -> void:
	var before := _snapshot(deck, party)
	_check(deck.turn_active and deck.hand.has(card_id) and catalog.has_card(card_id),
		label + ": real authored card is held on active turn")
	var previous_hand := deck.hand.count(card_id)
	var previous_discard := deck.discard_pile.count(card_id)
	var expected := _expected(before, card_id, recipient)
	_check(adapter.play_card(deck, party, card_id, target), label + ": succeeds")
	_check(_snapshot(deck, party) == expected,
		label + ": all HP/Block, piles, energy, turn, RNG and catalog match oracle")
	# For Tune Up a different copy can be drawn; avoid this case in the fixtures.
	_check(deck.hand.count(card_id) == previous_hand - 1
		and deck.discard_pile.count(card_id) == previous_discard + 1,
		label + ": exactly one played copy discarded")


func _rejected(deck: CombatDeck, party: CombatParty, card_id: String,
		target: int, label: String) -> void:
	var before := _snapshot(deck, party)
	_check(not adapter.play_card(deck, party, card_id, target),
		label + ": rejected")
	_check(_snapshot(deck, party) == before,
		label + ": atomic entire party, hand, piles, energy, combat state, RNG, catalog")


func _test_real_catalog() -> void:
	for card_id in SUPPORT_IDS + ATTACK_IDS:
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(definition.get("id") == card_id and catalog.has_card(card_id),
			"catalog contains real authored card " + card_id)
	var starter_deck := catalog.get_starting_deck()
	for card_id in SUPPORT_IDS + ATTACK_IDS:
		_check(starter_deck.has(card_id), "authored starter deck includes " + card_id)
	var authored_pairs := {
		"warden_brace": ["warden", "self", "block", 7],
		"seamstress_mend": ["seamstress", "ally_single", "heal", 5],
		"seamstress_stitch_up": ["seamstress", "ally_single", "block", 5],
		"tinker_tune_up": ["tinker", "none", "draw", 1],
	}
	for card_id in SUPPORT_IDS:
		var def: Dictionary = catalog.get_definition(card_id)
		var pair: Array = authored_pairs[card_id]
		_check(def["owner"] == pair[0] and def["target_kind"] == pair[1]
			and def["effects"] == {pair[2]: pair[3]}
			and def["to_positions"].is_empty(),
			"authored target/effect pair is exactly supported for " + card_id)
		_check(def["cost"] == (0 if card_id == "tinker_tune_up" else 1)
			and def["from_positions"] is Array and not def["from_positions"].is_empty(),
			"cost and legal positions read from authored " + card_id)


func _test_brace() -> void:
	var party := _party()
	var deck := _deck(["warden_brace", "warden_brace"])
	_rejected(deck, party, "warden_brace", 1, "Brace rejects nonzero target")
	_rejected(deck, party, "warden_brace", -1, "Brace rejects negative target")
	_accepted(deck, party, "warden_brace", 0, 1, "first Brace")
	_check(party.get_hero(1)["block"] == 7 and party.get_hero(2)["block"] == 0
		and party.get_hero(3)["block"] == 0, "Brace grants seven Block only to Warden")
	_accepted(deck, party, "warden_brace", 0, 1, "second Brace")
	_check(party.get_hero(1)["block"] == 14 and deck.energy == 1,
		"separate Brace copies stack and each costs one energy")


func _test_heal_and_block() -> void:
	var party := _party()
	_check(party.apply_damage(1, 8) and party.gain_block(3, 4),
		"wounded Warden and blocked Tinker prepared")
	var deck := _deck(["seamstress_mend", "seamstress_stitch_up"])
	_accepted(deck, party, "seamstress_mend", 1, 1, "Mend wounded ally")
	_check(party.get_hero(1)["hp"] == 37 and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["block"] == 4,
		"Mend heals only living selected ally by five")
	_accepted(deck, party, "seamstress_stitch_up", 2, 2, "Stitch Up self")
	_check(party.get_hero(2)["block"] == 5 and party.get_hero(3)["block"] == 4,
		"Stitch Up can select owner without touching other Block")

	party = _party()
	deck = _deck(["seamstress_mend"])
	_accepted(deck, party, "seamstress_mend", 3, 3, "Mend full HP")
	_check(party.get_hero(3)["hp"] == party.get_hero(3)["max_hp"] and deck.energy == 2,
		"full HP Mend costs once, no overheal")

	party = _party()
	_check(party.apply_damage(2, 4), "Seamstress wounded for self Mend")
	deck = _deck(["seamstress_mend"])
	_accepted(deck, party, "seamstress_mend", 2, 2, "Mend owner as ally")
	_check(party.get_hero(2)["hp"] == 30, "Mend self caps at max HP")

	party = _party()
	_check(party.gain_block(3, 2), "Tinker has Block before Stitch")
	deck = _deck(["seamstress_stitch_up"])
	_accepted(deck, party, "seamstress_stitch_up", 3, 3, "Stitch Up other ally")
	_check(party.get_hero(3)["block"] == 7, "Stitch adds exactly five to existing Block")


func _test_tune_up() -> void:
	var party := _party()
	var deck := _deck(["tinker_tune_up"])
	_accepted(deck, party, "tinker_tune_up", 0, 0, "solo Tune Up")
	_check(deck.hand.is_empty() and deck.draw_pile.is_empty()
		and deck.discard_pile == ["tinker_tune_up"] and deck.energy == 3,
		"solo Tune Up cannot redraw itself and costs zero")
	_rejected(deck, party, "tinker_tune_up", 0, "solo Tune Up absent after play")

	# Put two real authored non-Tune cards in discard: Tune must refill from
	# the seeded shuffle BEFORE discarding itself.
	deck = _deck(["tinker_tune_up", "warden_strike",
		"seamstress_prick", "seamstress_stitch_up"], 83)
	_check(deck.discard_played("warden_strike")
		and deck.discard_played("seamstress_prick"),
		"seeded refill has two eligible discarded real cards")
	_check(deck.draw_pile.is_empty() and deck.discard_pile.size() == 2,
		"seeded refill precondition")
	_accepted(deck, party, "tinker_tune_up", 0, 0, "Tune Up seeded refill")
	_check(not deck.hand.has("tinker_tune_up") and deck.energy == 3,
		"refill draws another card rather than played Tune Up")

	# Find a fixed seeded deck with Tune held and an existing draw pile:
	# every candidate uses only authored IDs and the selection is deterministic.
	var cards: Array[String] = ["tinker_tune_up", "warden_brace", "warden_strike",
		"seamstress_prick", "seamstress_mend", "tinker_pop_shot",
		"seamstress_stitch_up", "tinker_scrap_bomb"]
	var found: CombatDeck = null
	for seed_value in range(1, 80):
		var candidate := _deck(cards, seed_value)
		if candidate.hand.has("tinker_tune_up") and not candidate.draw_pile.is_empty():
			found = candidate
			break
	_check(found != null, "seed search finds actual held Tune with nonempty draw pile")
	if found != null:
		_check(found.draw_pile.size() == 3,
			"normal Tune draw fixture still has three cards waiting")
		_accepted(found, party, "tinker_tune_up", 0, 0, "Tune Up nonempty draw")
		_check(found.draw_pile.size() == 2 and found.energy == 3
			and not found.hand.has("tinker_tune_up"),
			"nonempty draw consumes exactly one and costs no energy")


func _test_rejections() -> void:
	var party := _party()
	var deck := _deck(["warden_brace", "seamstress_mend",
		"seamstress_stitch_up", "tinker_tune_up"])
	_rejected(deck, party, "invalid_support_id", 0, "unknown ID")
	_rejected(deck, party, "", 0, "empty ID")
	_rejected(deck, party, "warden_brace", 3, "Brace cannot target others")
	_rejected(deck, party, "tinker_tune_up", 3, "Tune Up rejects extra target")
	for card_id in ["seamstress_mend", "seamstress_stitch_up"]:
		for position in [-1, 0, 4, 100]:
			_rejected(deck, party, card_id, position,
				card_id + " invalid target " + str(position))
	_rejected(deck, party, "warden_shield_bash", 1, "attack absent from hand")
	_check(party.apply_damage(3, 26) and party.is_downed(3), "downed target prepared")
	_rejected(deck, party, "seamstress_mend", 3, "cannot Mend downed ally")
	_rejected(deck, party, "seamstress_stitch_up", 3, "cannot Stitch downed ally")
	_check(party.apply_damage(2, 30) and party.is_downed(2), "downed owner prepared")
	_rejected(deck, party, "seamstress_mend", 1, "downed Seamstress cannot Mend")
	_rejected(deck, party, "seamstress_stitch_up", 1, "downed Seamstress cannot Stitch")
	_rejected(deck, party, "tinker_tune_up", 0, "downed Tinker cannot Tune")
	_check(party.apply_damage(1, 40) and party.is_downed(1), "downed Warden prepared")
	_rejected(deck, party, "warden_brace", 0, "downed Warden cannot Brace")

	party = _party(["seamstress", "warden", "tinker"])
	deck = _deck(["seamstress_mend", "seamstress_stitch_up"])
	_check(party.get_hero(1)["id"] == "seamstress",
		"invalid from-position actually moves Seamstress to front")
	_rejected(deck, party, "seamstress_mend", 2,
		"authored Mend from_positions rejects Seamstress in front")
	_accepted(deck, party, "seamstress_stitch_up", 2, 2,
		"authored Stitch still legal from front")

	party = _party()
	deck = _deck(["warden_brace", "seamstress_mend", "tinker_tune_up"])
	_check(deck.try_spend_energy(3) and deck.energy == 0,
		"spent shared energy fixture is zero")
	_rejected(deck, party, "warden_brace", 0, "Brace insufficient energy")
	_rejected(deck, party, "seamstress_mend", 1, "Mend insufficient energy")
	_accepted(deck, party, "tinker_tune_up", 0, 0, "zero cost Tune at zero energy")

	party = _party()
	deck = _deck(["warden_brace"])
	_check(deck.discard_played("warden_brace"), "missing-hand fixture removes Brace")
	_rejected(deck, party, "warden_brace", 0, "catalog card missing from hand")
	_check(deck.end_turn() and not deck.turn_active, "inactive end turn prepared")
	_rejected(deck, party, "warden_brace", 0, "inactive turn rejects")
	_rejected(deck, party, "tinker_tune_up", 0, "inactive turn rejects Tune")
	# Independently hold a card while state is inactive to prove inactivity,
	# rather than relying on End Turn's normal clearing of the hand.
	deck = _deck(["warden_brace"])
	_check(deck.combat_state.end_player_turn() and deck.hand.has("warden_brace"),
		"inactive-with-card fixture retains a real held Brace")
	_rejected(deck, party, "warden_brace", 0, "inactive hand still cannot play")

	# Null and invalid callers are checked on a genuinely active held-card turn.
	deck = _deck(["warden_brace"])
	var before := _snapshot(deck, party)
	_check(deck.hand.has("warden_brace") and deck.turn_active,
		"null/invalid fixture has real held Brace and active energy")
	_check(not adapter.play_card(null, party, "warden_brace"),
		"null deck rejects")
	_check(_snapshot(deck, party) == before, "null deck leaves party/catalog/deck intact")
	_check(not adapter.play_card(deck, null, "warden_brace"),
		"null party rejects")
	_check(_snapshot(deck, party) == before, "null party leaves deck RNG/catalog intact")
	var invalid_party := CombatParty.new([])
	_rejected(deck, invalid_party, "warden_brace", 0, "invalid party rejects")

	# Attack definitions are present in the same real active hand, not merely
	# absent IDs that the support service would reject independently.
	party = _party()
	deck = _deck(ATTACK_IDS)
	_check(deck.hand.size() == ATTACK_IDS.size(), "all five attack IDs held together")
	for card_id in ATTACK_IDS:
		_check(deck.hand.has(card_id)
			and catalog.get_definition(card_id)["target_kind"].begins_with("enemy"),
			"offensive authored definition is actually held: " + card_id)
		_rejected(deck, party, card_id, 1, "offensive ID excluded " + card_id)

	party = _party()
	deck = _deck(["warden_brace"])
	_check(party.gain_block(1, CombatParty.MAX_INT),
		"overflow fixture has max representable Warden Block")
	_rejected(deck, party, "warden_brace", 0, "Block overflow is atomic")


func _sequence(seed_value: int) -> Array:
	var party := _party()
	var deck := _deck(["warden_brace", "seamstress_mend",
		"seamstress_stitch_up", "tinker_tune_up", "warden_strike"], seed_value)
	_check(deck.hand.size() == 5, "replay all support cards held in actual shared hand")
	var trace: Array = [_snapshot(deck, party)]
	_check(party.apply_damage(1, 9), "replay wound prepared")
	trace.append(_snapshot(deck, party))
	_check(adapter.play_card(deck, party, "seamstress_mend", 1), "replay Mend")
	trace.append(_snapshot(deck, party))
	_check(adapter.play_card(deck, party, "seamstress_stitch_up", 1), "replay Stitch Up")
	trace.append(_snapshot(deck, party))
	_check(adapter.play_card(deck, party, "tinker_tune_up"), "replay Tune Up")
	trace.append(_snapshot(deck, party))
	_check(adapter.play_card(deck, party, "warden_brace"), "replay Brace")
	trace.append(_snapshot(deck, party))
	_check(deck.end_turn() and deck.start_turn(), "replay next seeded refill turn")
	trace.append(_snapshot(deck, party))
	return trace


func _test_replay() -> void:
	for seed_value in [1, 42, 987654]:
		var first := _sequence(seed_value)
		var second := _sequence(seed_value)
		_check(first.size() == 7 and second.size() == 7,
			"seven full replay snapshots include seeded refill")
		_check(first == second,
			"same real catalog, seed, initial hand, actions give bitwise-identical states")
