extends SceneTree
## Deterministic D2-1 pool-energy contract, using real catalog, deck and party.

var checks: int = 0
var failures: Array[String] = []
var resolver := CombatPoolEnergyCards.new()


func _initialize() -> void:
	_test_overclock()
	_test_tailors_trance()
	_test_failures()
	_test_replay()
	for failure: String in failures:
		printerr(failure)
	print("combat_pool_energy_cards_test: ",
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


func _party(order: Array = ["warden", "seamstress", "tinker"]) -> CombatParty:
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
	return party


func _deck(cards: Array[String], seed_value: int = 42, start: bool = true) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	if start:
		_check(deck.start_turn() and deck.turn_active
			and deck.energy == CombatState.TURN_ENERGY, "real five-draw, three-energy turn")
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


func _rejected(deck: CombatDeck, party: CombatParty, id: String, target: int,
		label: String) -> void:
	var before: Dictionary = _snapshot(deck, party)
	var rng_before: int = deck._rng.state
	_check(not resolver.play_card(deck, party, id, target), label + ": rejects")
	_check(_snapshot(deck, party) == before, label + ": atomic rejection preserves state")
	_check(deck._rng.state == rng_before, label + ": RNG preserved")


func _tinker_position(party: CombatParty) -> int:
	for position in range(1, 4):
		if party.get_hero(position).get("id") == "tinker":
			return position
	return 0


func _seamstress_position(party: CombatParty) -> int:
	for position in range(1, 4):
		if party.get_hero(position).get("id") == "seamstress":
			return position
	return 0


func _test_overclock() -> void:
	for id in ["tinker_overclock", "tinker_overclock_plus"]:
		_check(resolver.is_supported_card(id), id + ": supported")
		# All three legal owner positions (reordered parties).
		for order in [["tinker", "warden", "seamstress"],
				["warden", "tinker", "seamstress"],
				["warden", "seamstress", "tinker"]]:
			var party := _party(order)
			var tpos: int = _tinker_position(party)
			_check(tpos >= 1, id + ": tinker present")
			var max_hp: int = party.get_hero(tpos)["max_hp"]

			# Block-first: 2 Block absorbs 2, 1 HP lost.
			_check(party.gain_block(tpos, 2), id + ": gain Block")
			var deck := _deck([id, id, "f-a", "f-b", "f-c"], 17)
			_check(deck.hand.has(id), id + ": held copy")
			var before: Dictionary = _snapshot(deck, party)
			_check(resolver.play_card(deck, party, id, 0), id + ": plays from slot " + str(tpos))
			var after: Dictionary = _snapshot(deck, party)
			_check(after["energy"] == before["energy"] + 1, id + ": +1 energy")
			_check(after["state_energy"] == before["state_energy"] + 1, id + ": state energy +1")
			_check(party.get_hero(tpos)["hp"] == max_hp - 1, id + ": one HP lost after 2 Block")
			_check(party.get_hero(tpos)["block"] == 0, id + ": Block fully consumed")
			_check(deck.hand.count(id) == before["hand"].count(id) - 1, id + ": one copy removed")
			_check(deck.discard_pile.count(id) == before["discard"].count(id) + 1, id + ": one copy discarded")
			_check(deck.draw_pile == before["draw"], id + ": draw pile unchanged")
			_check(deck._rng.state == before["rng"], id + ": RNG unchanged")
			# Collateral heroes unchanged.
			for pos in range(1, 4):
				if pos == tpos:
					continue
				_check(party.get_hero(pos) == before["heroes"][pos - 1],
					id + ": collateral hero " + str(pos) + " unchanged")

			# 3-HP down case.
			party = _party(order)
			tpos = _tinker_position(party)
			_check(party.apply_damage(tpos, max_hp - 3), id + ": wound to 3 HP")
			_check(party.get_hero(tpos)["hp"] == 3, id + ": exactly 3 HP before self-hit")
			deck = _deck([id, "f-a", "f-b", "f-c", "f-d"], 23)
			_check(deck.hand.has(id), id + ": held copy (down case)")
			before = _snapshot(deck, party)
			_check(resolver.play_card(deck, party, id, 0), id + ": lethal self-hit plays")
			_check(party.is_downed(tpos), id + ": Tinker downed at 0 HP")
			_check(party.get_hero(tpos)["hp"] == 0, id + ": HP is zero")
			_check(deck.energy == before["energy"] + 1, id + ": energy still +1 on down")
			_check(deck._rng.state == before["rng"], id + ": RNG unchanged (down)")


func _test_tailors_trance() -> void:
	for id in ["seamstress_tailors_trance", "seamstress_tailors_trance_plus"]:
		var expected_draw: int = 3 if id.ends_with("_plus") else 2
		_check(resolver.is_supported_card(id), id + ": supported")
		# Seamstress at positions 2 or 3.
		for order in [["warden", "seamstress", "tinker"],
				["tinker", "warden", "seamstress"]]:
			var party := _party(order)
			var spos: int = _seamstress_position(party)
			_check(spos == 2 or spos == 3, id + ": seamstress at 2/3 (got " + str(spos) + ")")

			# Basic draw with sufficient supply.
			var cards: Array[String] = [id, id, id, "f-1", "f-2", "f-3", "f-4", "f-5", "f-6", "f-7"]
			var deck := _deck(cards, 55)
			_check(deck.hand.has(id), id + ": held copy")
			var before: Dictionary = _snapshot(deck, party)
			_check(resolver.play_card(deck, party, id, 0), id + ": plays from slot " + str(spos))
			var after: Dictionary = _snapshot(deck, party)
			_check(after["energy"] == before["energy"], id + ": net-zero energy (3 -> 3)")
			_check(after["state_energy"] == before["state_energy"], id + ": state energy net-zero")
			_check(after["hand"].size() == before["hand"].size() - 1 + expected_draw,
				id + ": drew " + str(expected_draw))
			_check(deck.discard_pile.count(id) == before["discard"].count(id) + 1,
				id + ": one copy discarded")
			_check(after["heroes"] == before["heroes"], id + ": party state unchanged")
			var total_before: int = before["hand"].count(id) + before["draw"].count(id) + before["discard"].count(id)
			var total_after: int = deck.hand.count(id) + deck.draw_pile.count(id) + deck.discard_pile.count(id)
			_check(total_after == total_before,
				id + ": card copies conserved across piles")

			# Empty supply: 0 draws, other effects still apply.
			var empty_deck := _deck([id], 77)
			_check(empty_deck.hand.has(id), id + ": held copy (empty supply)")
			var ebefore: Dictionary = _snapshot(empty_deck, party)
			_check(resolver.play_card(empty_deck, party, id, 0), id + ": plays with empty supply")
			var eafter: Dictionary = _snapshot(empty_deck, party)
			_check(eafter["energy"] == ebefore["energy"], id + ": net-zero energy (empty supply)")
			_check(eafter["hand"].size() == ebefore["hand"].size() - 1, id + ": zero draws")
			_check(empty_deck.discard_pile.count(id) == ebefore["discard"].count(id) + 1,
				id + ": discarded despite zero draws")

			# Reshuffle protection: draw pile empty, discard has cards, played copy stays out.
			var refill_deck := _deck([id, "r-1", "r-2", "r-3", "r-4", "r-5"], 91)
			_check(refill_deck.hand.has(id), id + ": held copy (refill)")
			refill_deck.draw_pile.clear()
			refill_deck.discard_pile = ["refill-a", "refill-b", "refill-c", "refill-d", "refill-e"]
			var rbefore: Dictionary = _snapshot(refill_deck, party)
			var r_rng_before: int = refill_deck._rng.state
			_check(refill_deck.draw_pile.is_empty(), id + ": draw pile empty before")
			_check(resolver.play_card(refill_deck, party, id, 0), id + ": plays with refill")
			_check(refill_deck.draw_pile.size() == 5 - expected_draw,
				id + ": refilled draw pile consumed " + str(expected_draw))
			_check(refill_deck.hand.count(id) == rbefore["hand"].count(id) - 1,
				id + ": played copy not redrawn from refill")
			_check(refill_deck.discard_pile.has(id), id + ": played copy discarded after draw")
			_check(refill_deck._rng.state != r_rng_before, id + ": refill consumes RNG (draw)")

	# Replay determinism for trance (draws).
	var seq := func(seed_val: int) -> Array:
		var p: CombatParty = _party(["warden", "seamstress", "tinker"])
		var d: CombatDeck = _deck(["seamstress_tailors_trance", "seamstress_tailors_trance",
			"seamstress_tailors_trance", "f-1", "f-2", "f-3", "f-4", "f-5", "f-6", "f-7"], seed_val)
		var t: Array = [_snapshot(d, p)]
		_check(d.hand.has("seamstress_tailors_trance"), "replay hand has trance")
		_check(resolver.play_card(d, p, "seamstress_tailors_trance", 0), "replay play")
		t.append(_snapshot(d, p))
		return t
	var first: Array = seq.call(123)
	var second: Array = seq.call(123)
	_check(first.size() == 2 and second.size() == 2, "trance replay records snapshots")
	_check(first == second, "same seed replays trance draws and RNG")


func _test_failures() -> void:
	# No held ID.
	var party := _party()
	var deck := _deck(["filler-a", "filler-b", "filler-c", "filler-d", "filler-e"], 9)
	_rejected(deck, party, "tinker_overclock", 0, "overclock absent from hand")
	_rejected(deck, party, "seamstress_tailors_trance", 0, "trance absent from hand")

	# Unsupported card even if held.
	deck = _deck(["tinker_rivet_shot", "filler-a", "filler-b", "filler-c", "filler-d"], 11)
	_rejected(deck, party, "tinker_rivet_shot", 0, "unsupported resolver ID")

	# Unknown card in hand.
	deck = _deck(["not_a_card", "filler-a", "filler-b", "filler-c", "filler-d"], 13)
	_check(deck.hand.has("not_a_card"), "unknown card actually held")
	_rejected(deck, party, "not_a_card", 0, "unknown ID rejected")

	# Nonzero target.
	deck = _deck(["tinker_overclock", "filler-a", "filler-b", "filler-c", "filler-d"], 19)
	party = _party()
	_check(deck.hand.has("tinker_overclock"), "overclock held for nonzero target test")
	_rejected(deck, party, "tinker_overclock", 1, "nonzero target (overclock)")
	deck = _deck(["seamstress_tailors_trance", "filler-a", "filler-b", "filler-c", "filler-d"], 21)
	party = _party()
	_check(deck.hand.has("seamstress_tailors_trance"), "trance held for nonzero target test")
	_rejected(deck, party, "seamstress_tailors_trance", 2, "nonzero target (trance)")

	# Downed owner.
	party = _party()
	_check(party.apply_damage(3, 26) and party.is_downed(3), "tinker downed")
	deck = _deck(["tinker_overclock", "filler-a", "filler-b", "filler-c", "filler-d"], 29)
	_check(deck.hand.has("tinker_overclock"), "overclock held")
	_rejected(deck, party, "tinker_overclock", 0, "downed tinker owner")
	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "seamstress downed")
	deck = _deck(["seamstress_tailors_trance", "filler-a", "filler-b", "filler-c", "filler-d"], 31)
	_check(deck.hand.has("seamstress_tailors_trance"), "trance held")
	_rejected(deck, party, "seamstress_tailors_trance", 0, "downed seamstress owner")

	# Mispositioned owner: trance owner at front (position 1) not in [2,3].
	party = _party(["seamstress", "warden", "tinker"])
	deck = _deck(["seamstress_tailors_trance", "filler-a", "filler-b", "filler-c", "filler-d"], 37)
	_check(deck.hand.has("seamstress_tailors_trance"), "trance held (mispositioned)")
	_rejected(deck, party, "seamstress_tailors_trance", 0, "trance owner at illegal front slot")

	# Overclock owner at any position is legal, so test missing owner instead.
	# Missing owner: party without seamstress (for trance).
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	var by_id: Dictionary = {}
	for record in raw:
		if record is Dictionary:
			by_id[record.get("id", "")] = record
	var defs: Array = []
	for hid in ["warden", "tinker"]:
		var h: Dictionary = by_id[hid].duplicate(true)
		h["max_hp"] = int(h["max_hp"])
		defs.append(h)
	# third hero: reuse seamstress record but rename id to avoid owner match
	var third: Dictionary = by_id["seamstress"].duplicate(true)
	third["id"] = "intruder"
	third["max_hp"] = int(third["max_hp"])
	defs.append(third)
	var missing_party := CombatParty.new(defs)
	_check(missing_party.is_valid(), "missing-owner party valid")
	deck = _deck(["seamstress_tailors_trance", "filler-a", "filler-b", "filler-c", "filler-d"], 41)
	_check(deck.hand.has("seamstress_tailors_trance"), "trance held (missing owner)")
	_rejected(deck, missing_party, "seamstress_tailors_trance", 0, "missing seamstress owner")

	# Insufficient trance energy.
	party = _party()
	deck = _deck(["seamstress_tailors_trance", "filler-a", "filler-b", "filler-c", "filler-d"], 43)
	_check(deck.hand.has("seamstress_tailors_trance"), "trance held (energy)")
	_check(deck.try_spend_energy(3) and deck.energy == 0, "energy exhausted")
	_rejected(deck, party, "seamstress_tailors_trance", 0, "insufficient trance energy")

	# Inactive turn.
	party = _party()
	deck = _deck(["tinker_overclock", "seamstress_tailors_trance"], 47, false)
	_check(not deck.turn_active, "turn inactive")
	_rejected(deck, party, "tinker_overclock", 0, "inactive turn (overclock)")
	_rejected(deck, party, "seamstress_tailors_trance", 0, "inactive turn (trance)")

	# Defeated party.
	party = _party()
	_check(party.apply_damage(1, 40) and party.apply_damage(2, 30) and party.apply_damage(3, 26),
		"all heroes downed")
	_check(party.is_defeated(), "party defeated")
	deck = _deck(["tinker_overclock", "seamstress_tailors_trance", "filler-a", "filler-b", "filler-c"], 51)
	_rejected(deck, party, "tinker_overclock", 0, "defeated party (overclock)")
	_rejected(deck, party, "seamstress_tailors_trance", 0, "defeated party (trance)")

	# Null authorities.
	party = _party()
	deck = _deck(["tinker_overclock"], 53)
	_check(not resolver.play_card(null, party, "tinker_overclock", 0)
		and not resolver.play_card(deck, null, "tinker_overclock", 0),
		"null authorities reject (overclock)")
	deck = _deck(["seamstress_tailors_trance"], 59)
	_check(not resolver.play_card(null, party, "seamstress_tailors_trance", 0)
		and not resolver.play_card(deck, null, "seamstress_tailors_trance", 0),
		"null authorities reject (trance)")


func _test_replay() -> void:
	var run_sequence := func(seed_val: int) -> Array:
		var p: CombatParty = _party(["warden", "seamstress", "tinker"])
		var max_hp: int = p.get_hero(_tinker_position(p))["max_hp"]
		_check(p.gain_block(_tinker_position(p), 2), "replay gain Block")
		var d: CombatDeck = _deck(["tinker_overclock", "tinker_overclock", "f-1", "f-2", "f-3"], seed_val)
		var t: Array = [_snapshot(d, p)]
		_check(d.hand.has("tinker_overclock"), "replay hand has overclock")
		_check(resolver.play_card(d, p, "tinker_overclock", 0), "replay overclock")
		t.append(_snapshot(d, p))
		return t
	var first: Array = run_sequence.call(7)
	var second: Array = run_sequence.call(7)
	_check(first.size() == 2 and second.size() == 2, "overclock replay records snapshots")
	_check(first == second, "same seed replays overclock state and RNG")