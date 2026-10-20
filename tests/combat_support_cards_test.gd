extends SceneTree

const BRACE := {"id": "warden_brace", "owner_id": "warden", "cost": 1,
	"from_positions": [1, 2, 3], "effect": "self_block", "amount": 7}
const MEND := {"id": "seamstress_mend", "owner_id": "seamstress", "cost": 1,
	"from_positions": [2, 3], "effect": "ally_heal", "amount": 5}
const STITCH := {"id": "seamstress_stitch_up", "owner_id": "seamstress", "cost": 1,
	"from_positions": [1, 2, 3], "effect": "ally_block", "amount": 5}
const TUNE := {"id": "tinker_tune_up", "owner_id": "tinker", "cost": 0,
	"from_positions": [1, 2, 3], "effect": "draw", "amount": 1}

var failures: Array[String] = []
var checks := 0
var service := CombatSupportCards.new()


func _initialize() -> void:
	_test_four_cards()
	_test_draw_order()
	_test_rejections()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("combat_support_cards_test: ", "PASS" if failures.is_empty() else "FAIL",
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


func _deck(cards: Array[String], seed_value: int = 42) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"fixture starts a real shared turn with three energy")
	return deck


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"fixture constructs three living heroes")
	return party


func _snapshot(deck: CombatDeck, party: CombatParty) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.turn_active, deck.energy, deck.combat_state.player_turn_active,
		deck.combat_state.energy, party.get_heroes(), deck._rng.state]


func _expected(before: Array, definition: Dictionary, recipient: int = 0) -> Array:
	var after := before.duplicate(true)
	var card_id: String = definition["id"]
	var effect: String = definition["effect"]
	var amount: int = definition["amount"]
	after[4] -= definition["cost"]
	after[6] -= definition["cost"]
	if effect == "draw":
		_oracle_draw(after, amount)
	else:
		var hero: Dictionary = after[7][recipient - 1]
		match effect:
			"self_block", "ally_block":
				hero["block"] += amount
			"ally_heal":
				hero["hp"] = mini(hero["max_hp"], hero["hp"] + amount)
	after[1].remove_at(after[1].find(card_id))
	after[2].append(card_id)
	return after


func _oracle_draw(state: Array, count: int) -> void:
	# Predict the existing CombatDeck refill using an independent copy of the
	# seeded RNG, without mutating the actual deck or its RNG.
	var pile: Array = state[0]
	var hand: Array = state[1]
	var discarded: Array = state[2]
	var generator := _rng(0)
	generator.state = state[8]
	for index in range(count):
		if pile.is_empty():
			if discarded.is_empty():
				break
			pile.append_array(discarded)
			discarded.clear()
			for i in range(pile.size() - 1, 0, -1):
				var other := generator.randi_range(0, i)
				var saved = pile[i]
				pile[i] = pile[other]
				pile[other] = saved
		hand.append(pile.pop_back())
	state[8] = generator.state


func _accepted(deck: CombatDeck, party: CombatParty, definition: Dictionary,
		target: int, recipient: int, label: String) -> void:
	var before := _snapshot(deck, party)
	var card_id: String = definition["id"]
	_check(deck.hand.has(card_id), label + ": actual hand contains the card")
	var original_count := deck.hand.count(card_id)
	var discarded_count := deck.discard_pile.count(card_id)
	var expected := _expected(before, definition, recipient)
	_check(service.play_support(deck, party, definition, target), label + ": accepted")
	_check(_snapshot(deck, party) == expected,
		label + ": full before/after piles, party, energy, turn and RNG")
	_check(deck.hand.count(card_id) == original_count - 1 and
		deck.discard_pile.count(card_id) == discarded_count + 1,
		label + ": exactly one matching copy moved to discard")


func _rejected(deck: CombatDeck, party: CombatParty, definition: Dictionary,
		target: int, label: String) -> void:
	var before := _snapshot(deck, party)
	_check(not service.play_support(deck, party, definition, target), label + ": rejected")
	_check(_snapshot(deck, party) == before,
		label + ": atomic rejection preserves entire party, piles, energy and RNG")


func _test_four_cards() -> void:
	var party := _party()
	var deck := _deck(["warden_brace", "warden_brace"])
	_accepted(deck, party, BRACE, 0, 1, "Brace, first of two copies")
	_check(deck.hand.count("warden_brace") == 1 and party.get_hero(1)["block"] == 7
		and party.get_hero(2)["block"] == 0 and party.get_hero(3)["block"] == 0,
		"Brace grants exactly 7 only to its owner while preserving other copy")
	_accepted(deck, party, BRACE, 0, 1, "Brace, second copy")
	_check(party.get_hero(1)["block"] == 14 and deck.energy == 1,
		"Brace stacks once per paid play")

	party = _party()
	_check(party.apply_damage(1, 8) and party.gain_block(3, 4),
		"Mend fixture wounds Warden and protects Tinker")
	deck = _deck(["seamstress_mend"])
	_accepted(deck, party, MEND, 1, 1, "Mend wounded allied Warden")
	_check(party.get_hero(1)["hp"] == 37 and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["block"] == 4, "Mend heals selected living ally only")

	party = _party()
	_check(party.apply_damage(2, 4), "Mend self-heal fixture is wounded")
	deck = _deck(["seamstress_mend"])
	_accepted(deck, party, MEND, 2, 2, "Mend self as ally")
	_check(party.get_hero(2)["hp"] == 30, "Mend self-healing respects max HP")

	party = _party()
	deck = _deck(["seamstress_mend"])
	_accepted(deck, party, MEND, 3, 3, "Mend full-HP ally")
	_check(party.get_hero(3)["hp"] == 26 and deck.energy == 2,
		"full-HP heal still spends card/energy and never overheals")

	party = _party()
	_check(party.gain_block(3, 2), "Stitch fixture has existing Block")
	deck = _deck(["seamstress_stitch_up"])
	_accepted(deck, party, STITCH, 3, 3, "Stitch Up Tinker")
	_check(party.get_hero(3)["block"] == 7 and party.get_hero(1)["block"] == 0
		and party.get_hero(2)["block"] == 0, "Stitch Up grants 5 Block only to recipient")

	party = _party()
	deck = _deck(["seamstress_stitch_up"])
	_accepted(deck, party, STITCH, 2, 2, "Stitch Up self as ally")
	_check(party.get_hero(2)["block"] == 5, "Stitch Up may target self")

	party = _party()
	deck = _deck(["tinker_tune_up"])
	_accepted(deck, party, TUNE, 0, 0, "Tune Up solo deck")
	_check(deck.hand.is_empty() and deck.draw_pile.is_empty()
		and deck.discard_pile == ["tinker_tune_up"] and deck.energy == 3,
		"zero-cost only-Tune-Up cannot self-redraw during its resolution")
	_rejected(deck, party, TUNE, 0, "solo Tune Up unavailable for repeat play")


func _test_draw_order() -> void:
	var party := _party()
	var deck := _deck(["tinker_tune_up", "spare", "x", "y", "z"])
	_check(deck.hand.size() == 5 and deck.draw_pile.is_empty()
		and deck.hand.has("spare"), "refill fixture has real five-card hand")
	_check(deck.discard_played("spare") and deck.discard_pile == ["spare"],
		"refill fixture puts a different card into discard")
	_accepted(deck, party, TUNE, 0, 0, "Tune Up reshuffles eligible discarded card first")
	_check(deck.hand.has("spare") and not deck.hand.has("tinker_tune_up")
		and deck.discard_pile == ["tinker_tune_up"], "Tune Up draws old discard not itself")

	# Draw with a nonempty draw pile and show untouched earlier discards.
	var cards: Array[String] = ["tinker_tune_up", "a", "b", "c", "d", "e", "f"]
	deck = _deck(cards, 71)
	if not deck.hand.has("tinker_tune_up"):
		_check(deck.draw_extra(2) == 2, "seeded fixture draws Tune Up into hand")
	_check(deck.hand.has("tinker_tune_up"), "seeded multicard fixture holds Tune Up")
	if deck.hand.has("tinker_tune_up"):
		_accepted(deck, party, TUNE, 0, 0, "Tune Up normal draw/refill")
	_check(deck.energy == 3 and deck.hand.count("tinker_tune_up") == 0,
		"multicard Tune Up did not spend energy or redraw itself")


func _test_rejections() -> void:
	var party := _party()
	var deck := CombatDeck.new(["warden_brace"], _rng(5))
	_rejected(deck, party, BRACE, 0, "inactive shared turn")
	_check(deck.start_turn(), "inactive rejection did not prevent a real turn")
	_rejected(deck, party, MEND, 2, "Mend absent from actual hand")
	_rejected(deck, party, BRACE, 2, "self Block cannot be redirected")
	_rejected(deck, party, BRACE, 4, "self Block rejects extra target")
	var wrong := BRACE.duplicate(true)
	wrong["owner_id"] = "missing_hero"
	_rejected(deck, party, wrong, 0, "unknown owner ID")
	wrong = BRACE.duplicate(true)
	wrong["owner_id"] = "seamstress"
	wrong["from_positions"] = [1]
	_rejected(deck, party, wrong, 0, "different owner not in allowed position")
	wrong = BRACE.duplicate(true)
	wrong["from_positions"] = [2, 3]
	_rejected(deck, party, wrong, 0, "Warden from-ineligible position")
	_check(party.apply_damage(1, 40) and party.is_downed(1), "owner downed fixture")
	_rejected(deck, party, BRACE, 0, "downed Warden cannot play")
	party = _party()
	_check(deck.try_spend_energy(3) and deck.energy == 0, "energy shortage fixture")
	_rejected(deck, party, BRACE, 0, "missing shared energy")

	party = _party()
	deck = _deck(["seamstress_mend", "seamstress_stitch_up"])
	_rejected(deck, party, MEND, 0, "Mend requires ally target")
	_rejected(deck, party, MEND, -1, "negative ally target")
	_rejected(deck, party, MEND, 4, "out-of-range ally target")
	_rejected(deck, party, STITCH, 0, "Stitch Up requires ally target")
	_rejected(deck, party, STITCH, 4, "Stitch Up invalid ally target")
	_check(party.apply_damage(3, 26) and party.is_downed(3), "target downed fixture")
	_rejected(deck, party, MEND, 3, "Mend cannot revive downed target")
	_rejected(deck, party, STITCH, 3, "Stitch cannot shield downed target")
	_check(party.apply_damage(2, 30) and party.is_downed(2), "Seamstress downed fixture")
	_rejected(deck, party, MEND, 1, "downed Seamstress cannot heal")
	_rejected(deck, party, STITCH, 1, "downed Seamstress cannot give Block")

	party = _party()
	deck = _deck(["warden_brace", "tinker_tune_up"])
	var malformed: Array = []
	for key in ["id", "owner_id", "cost", "from_positions", "effect", "amount"]:
		var missing := BRACE.duplicate(true)
		missing.erase(key)
		malformed.append(missing)
	for value in ["", 0, null]:
		var bad_id := BRACE.duplicate(true)
		bad_id["id"] = value
		malformed.append(bad_id)
	for value in ["", 7, null]:
		var bad_owner := BRACE.duplicate(true)
		bad_owner["owner_id"] = value
		malformed.append(bad_owner)
	for value in [-1, 4, 1.5, "1", null]:
		var bad_cost := BRACE.duplicate(true)
		bad_cost["cost"] = value
		malformed.append(bad_cost)
	for value in [[], [0], [4], [1, "2"], [2.0], "1,2", null]:
		var bad_positions := BRACE.duplicate(true)
		bad_positions["from_positions"] = value
		malformed.append(bad_positions)
	for value in ["attack", "draw_two", 5, null]:
		var bad_effect := BRACE.duplicate(true)
		bad_effect["effect"] = value
		malformed.append(bad_effect)
	for value in [-1, 1.25, "7", null]:
		var bad_amount := BRACE.duplicate(true)
		bad_amount["amount"] = value
		malformed.append(bad_amount)
	for index in range(malformed.size()):
		_rejected(deck, party, malformed[index], 0, "malformed metadata #%d" % index)

	_check(party.gain_block(1, CombatParty.MAX_INT),
		"Block capacity fixture reaches maximum representable value")
	_rejected(deck, party, BRACE, 0, "Block overflow rejects before spending")
	var empty_party := CombatParty.new([])
	_rejected(deck, empty_party, BRACE, 0, "invalid party is rejected")
	_check(not service.play_support(null, party, BRACE), "null deck rejects safely")
	_check(not service.play_support(deck, null, BRACE), "null party rejects safely")
	_rejected(deck, party, TUNE, 1, "draw rejects extra target")
	_check(deck.discard_played("tinker_tune_up"), "absent-Tune fixture discards its real copy")
	_rejected(deck, party, TUNE, 0, "Tune Up must be in active hand")


func _sequence(seed_value: int) -> Array:
	var party := _party()
	var deck := _deck(["warden_brace", "seamstress_mend", "seamstress_stitch_up",
		"tinker_tune_up", "filler"], seed_value)
	var trace: Array = [_snapshot(deck, party)]
	_check(party.apply_damage(1, 9), "replay wound prepared")
	trace.append(_snapshot(deck, party))
	_check(service.play_support(deck, party, MEND, 1), "replay Mend succeeds")
	trace.append(_snapshot(deck, party))
	_check(service.play_support(deck, party, STITCH, 1), "replay Stitch succeeds")
	trace.append(_snapshot(deck, party))
	_check(service.play_support(deck, party, TUNE, 0), "replay Tune succeeds")
	trace.append(_snapshot(deck, party))
	_check(service.play_support(deck, party, BRACE, 0), "replay Brace succeeds")
	trace.append(_snapshot(deck, party))
	_check(deck.end_turn() and deck.start_turn(), "replay refills next real shared turn")
	trace.append(_snapshot(deck, party))
	return trace


func _test_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var first := _sequence(seed_value)
		var second := _sequence(seed_value)
		_check(first.size() == 7 and second.size() == 7,
			"replay includes seven actual full snapshots")
		_check(first == second, "identical injected cards, party and seed replay exactly")
