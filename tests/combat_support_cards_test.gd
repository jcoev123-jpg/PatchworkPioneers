extends SceneTree

const BRACE := {"id": "warden_brace", "owner_id": "warden", "cost": 1,
	"from_positions": [1, 2, 3], "effect": "self_block", "amount": 7}
const MEND := {"id": "seamstress_mend", "owner_id": "seamstress", "cost": 1,
	"from_positions": [2, 3], "effect": "ally_heal", "amount": 5}
const STITCH := {"id": "seamstress_stitch_up", "owner_id": "seamstress", "cost": 1,
	"from_positions": [1, 2, 3], "effect": "ally_block", "amount": 5}
const BRACE_PLUS := {"id": "warden_brace_plus", "owner_id": "warden", "cost": 1,
	"from_positions": [1, 2, 3], "effect": "self_block", "amount": 10}
const STITCH_PLUS := {"id": "seamstress_stitch_up_plus", "owner_id": "seamstress", "cost": 1,
	"from_positions": [1, 2, 3], "effect": "ally_block", "amount": 7}
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
	_test_spare_spool()
	_test_bound_rejections()
	_test_hemguard_cuff()
	_test_reinforced_browband()
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


func _spool_fixture(mode: String, seed_value: int = 42) -> Dictionary:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in definitions:
		_check(hero.max_hp == floor(hero.max_hp), "authored HP is integral")
		hero.max_hp = int(hero.max_hp)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(2).id == "seamstress", "authored Mend owner exists")
	var torn := RunTornMending.new(party.get_heroes())
	var slots: Array = JSON.parse_string(FileAccess.get_file_as_string(CombatShopPatchRules.SLOTS_CATALOG))
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), [] if mode == "absent" else ["spare_spool"], slots, 5)
	_check(wardrobe.is_valid() and torn.is_valid(), "valid real patch ledgers")
	if mode not in ["absent", "unsewn"]:
		_check(wardrobe.sew("spare_spool", "tinker" if mode == "wrong" else "seamstress", "ARM", "sew", wardrobe.get_snapshot()).ok, "real Spool sew")
	if mode == "moved":
		_check(wardrobe.start_rest("rest", wardrobe.get_snapshot()).ok, "Rest opens for move")
		_check(wardrobe.re_sew("spare_spool", "seamstress", "tinker", "rest", "move", wardrobe.get_snapshot()).ok, "real Spool moves away from Mend owner")
		_check(wardrobe.end_rest("rest", wardrobe.get_snapshot()).ok, "Rest closes")
	if mode == "torn":
		var start: Array = torn.read_state().heroes
		var finish: Array = start.duplicate(true)
		finish[1].hp = 0
		_check(torn.observe_battle_end("fight", start, finish).ok, "actual owner tear")
		var state := wardrobe.get_snapshot()
		_check(wardrobe.refresh_run_context(torn.read_state().heroes, state.owned, state.scraps, state.gold, state.cards, state), "wardrobe reconciles tear")
		party._heroes.assign(torn.read_state().heroes)
	var resolver := CombatSupportCards.new()
	if mode != "unbound":
		_check(resolver.bind_patch_wardrobe(wardrobe, torn), "explicit real Spool binding")
	var deck := _deck(["seamstress_mend"], seed_value)
	_check(party.apply_damage(1, 12) and party.get_hero(1).hp == 28, "eligible wounded ally")
	return {"party": party, "deck": deck, "service": resolver, "wardrobe": wardrobe, "torn": torn}


func _bound_reject(c: Dictionary, definition: Dictionary, target: int, label: String) -> void:
	var before := _snapshot(c.deck, c.party)
	var ledgers := [c.wardrobe.get_snapshot(), c.torn.read_state()]
	_check(not c.service.play_support(c.deck, c.party, definition, target), label + " rejects")
	_check(_snapshot(c.deck, c.party) == before and ledgers == [c.wardrobe.get_snapshot(), c.torn.read_state()], label + " pristine combat/ledgers/RNG")


func _spool_sequence(seed_value: int) -> Array:
	var c := _spool_fixture("sewn", seed_value)
	var trace: Array = [_snapshot(c.deck, c.party)]
	_bound_reject(c, MEND, 0, "missing target before patched heal")
	_check(c.service.play_support(c.deck, c.party, MEND, 1), "bound canonical Mend commits")
	_check(c.party.get_hero(1).hp == 35 and c.deck.energy == 2 and c.deck.hand.is_empty()
		and c.deck.discard_pile == ["seamstress_mend"], "actual seven HP, one energy and discard")
	trace.append(_snapshot(c.deck, c.party))
	return trace


func _test_spare_spool() -> void:
	_check(StarterCards.new().get_definition("seamstress_mend").effects.heal == MEND.amount, "canonical five-heal precondition")
	for seed_value in [0, 42, 987654]:
		_check(_spool_sequence(seed_value) == _spool_sequence(seed_value), "bound seeded replay")
	for mode in ["absent", "unsewn", "wrong", "moved", "unbound"]:
		var c := _spool_fixture(mode)
		var before := _snapshot(c.deck, c.party)
		_check(c.service.play_support(c.deck, c.party, MEND, 1), mode + " remains ordinary Mend")
		_check(_snapshot(c.deck, c.party) == _expected(before, MEND, 1) and c.party.get_hero(1).hp == 33, mode + " exactly five, normal piles/energy/RNG")
	var c := _spool_fixture("sewn")
	_check(c.party.heal(1, 10) and c.party.get_hero(1).hp == 38, "two missing HP cap fixture")
	_check(c.service.play_support(c.deck, c.party, MEND, 1) and c.party.get_hero(1).hp == 40, "seven healing clamps at max HP")
	c = _spool_fixture("sewn")
	var heroes: Array = c.party.get_heroes()
	c.party = CombatParty.new([heroes[0], heroes[2], heroes[1]])
	_check(c.party.apply_damage(1, 12) and c.party.get_hero(3).id == "seamstress", "living wearer moved to legal back slot")
	_check(c.service.play_support(c.deck, c.party, MEND, 1) and c.party.get_hero(1).hp == 35, "bonus follows owner identity across slots")
	c = _spool_fixture("torn")
	_check(c.party.is_downed(2) and c.torn.read_state().tear_counts.seamstress == 1, "torn owner truly downed")
	_bound_reject(c, MEND, 1, "torn owner cannot play or grant phantom healing")


func _test_bound_rejections() -> void:
	var c := _spool_fixture("sewn")
	for change in [{"amount": 7}, {"amount": 0}, {"amount": 999}, {"owner_id": "tinker"},
		{"id": "fake_mend"}, {"from_positions": [1, 2, 3]}, {"cost": 0}, {"effect": "ally_block"}]:
		var forged := MEND.duplicate(true)
		for key in change:
			forged[key] = change[key]
		if change.has("id"):
			c.deck.hand.append("fake_mend")
		_bound_reject(c, forged, 1, "spoofed heal " + str(change))
	for target in [-1, 0, 4]:
		_bound_reject(c, MEND, target, "illegal patched target")
	_check(c.party.apply_damage(3, 26), "downed target prepared")
	_bound_reject(c, MEND, 3, "patched Mend cannot revive")
	c = _spool_fixture("sewn")
	_check(c.deck.try_spend_energy(3), "energy exhausted")
	_bound_reject(c, MEND, 1, "patched no energy")
	for mode in ["null", "invalid", "stale_wardrobe", "stale_torn", "drift", "unreconciled"]:
		c = _spool_fixture("sewn")
		var w: Dictionary = c.wardrobe.get_snapshot()
		var t: Dictionary = c.torn.read_state()
		match mode:
			"null":
				_check(not c.service.bind_patch_wardrobe(null, c.torn), "null explicit binding fails")
			"invalid":
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, RunTornMending.new()), "invalid authority fails binding")
			"stale_wardrobe":
				w.scraps += 1
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn, w, t), "stale expected wardrobe fails")
			"stale_torn":
				t.heroes[0].hp -= 1
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn, w, t), "stale expected torn fails")
			"drift":
				_check(c.wardrobe.start_rest("later", w).ok, "ledger really advances after binding")
			"unreconciled":
				var finish: Array = t.heroes.duplicate(true)
				finish[0].hp -= 1
				_check(c.torn.observe_battle_end("later_fight", t.heroes, finish).ok, "torn ledger really advances")
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn), "inconsistent authoritative ledgers reject binding")
		_bound_reject(c, MEND, 1, mode + " explicit binding never becomes neutral")
		if mode == "unreconciled":
			_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes, w.owned, w.scraps, w.gold, w.cards, w), "reconcile authority before recovery")
		_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn), "fresh binding recovers explicitly")
		_check(c.service.play_support(c.deck, c.party, MEND, 1) and c.party.get_hero(1).hp == 35, "fresh valid binding restores seven heal")


func _cuff_fixture(mode: String, card_id: String = "warden_brace", seed_value: int = 42) -> Dictionary:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in definitions:
		_check(hero.max_hp == floor(hero.max_hp), "authored HP is integral")
		hero.max_hp = int(hero.max_hp)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(1).id == "warden" and party.get_hero(2).id == "seamstress", "authored Warden and Seamstress exist")
	var torn := RunTornMending.new(party.get_heroes())
	var slots: Array = [
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "spare_spool", "slot": "ARM"},
		{"id": "hemguard_cuff", "slot": "ARM"},
	]
	var owned: Array = []
	if mode != "absent":
		owned.append("hemguard_cuff")
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, slots, 5)
	_check(wardrobe.is_valid() and torn.is_valid(), "valid real patch ledgers for cuff")
	if mode not in ["absent", "unsewn"]:
		var wearer := "warden"
		if mode in ["sewn_seamstress", "target_cuff"]:
			wearer = "seamstress"
		elif mode == "wrong":
			wearer = "tinker"
		_check(wardrobe.sew("hemguard_cuff", wearer, "ARM", "cuff-sew", wardrobe.get_snapshot()).ok, "real Cuff sew")
	if mode == "moved":
		_check(wardrobe.start_rest("rest", wardrobe.get_snapshot()).ok, "Rest opens for move")
		_check(wardrobe.re_sew("hemguard_cuff", "warden", "seamstress", "rest", "cuff-move", wardrobe.get_snapshot()).ok, "real Cuff moves to seamstress")
		_check(wardrobe.end_rest("rest", wardrobe.get_snapshot()).ok, "Rest closes")
	if mode == "torn":
		var start: Array = torn.read_state().heroes
		var finish: Array = start.duplicate(true)
		finish[0].hp = 0
		_check(torn.observe_battle_end("fight", start, finish).ok, "actual warden tear")
		var state := wardrobe.get_snapshot()
		_check(wardrobe.refresh_run_context(torn.read_state().heroes, state.owned, state.scraps, state.gold, state.cards, state), "wardrobe reconciles tear")
		party._heroes.assign(torn.read_state().heroes)
	var resolver := CombatSupportCards.new()
	if mode != "unbound":
		_check(resolver.bind_patch_wardrobe(wardrobe, torn), "explicit real Cuff binding")
	var deck := _deck([card_id], seed_value)
	return {"party": party, "deck": deck, "service": resolver, "wardrobe": wardrobe, "torn": torn}


func _cuff_sequence(seed_value: int) -> Array:
	var c := _cuff_fixture("sewn_warden", "warden_brace", seed_value)
	_check(c.party.gain_block(1, 6), "opening six Block fixture")
	var trace: Array = [_snapshot(c.deck, c.party)]
	_bound_reject(c, BRACE, 2, "self block rejects wrong target before cuff play")
	_check(c.service.play_support(c.deck, c.party, BRACE, 0), "bound canonical Brace commits with Cuff")
	_check(c.party.get_hero(1).block == 15 and c.deck.energy == 2 and c.deck.hand.is_empty()
		and c.deck.discard_pile == ["warden_brace"], "actual fifteen Block (6+7+2), one energy and discard")
	trace.append(_snapshot(c.deck, c.party))
	return trace


func _test_hemguard_cuff() -> void:
	_check(StarterCards.new().get_definition("warden_brace").effects.block == BRACE.amount, "canonical seven-block precondition")
	_check(StarterCards.new().get_definition("warden_brace_plus").effects.block == BRACE_PLUS.amount, "canonical ten-block precondition")
	_check(StarterCards.new().get_definition("seamstress_stitch_up").effects.block == STITCH.amount, "canonical five-block precondition")
	_check(StarterCards.new().get_definition("seamstress_stitch_up_plus").effects.block == STITCH_PLUS.amount, "canonical seven-block stitch plus precondition")

	for seed_value in [0, 42, 987654]:
		_check(_cuff_sequence(seed_value) == _cuff_sequence(seed_value), "bound cuff seeded replay")

	# AC1: Brace grants 9 Block (7+2) and Brace+ grants 12 (10+2) atop existing 6 opening Block
	var c := _cuff_fixture("sewn_warden", "warden_brace")
	_check(c.party.gain_block(1, 6), "Warden opening block setup")
	var before := _snapshot(c.deck, c.party)
	_check(c.service.play_support(c.deck, c.party, BRACE, 0), "Brace commits with cuff")
	_check(c.party.get_hero(1).block == 15 and c.deck.energy == 2 and c.deck.hand.is_empty()
		and c.deck.discard_pile == ["warden_brace"], "Brace grants 9 (7+2) atop opening 6 Block")
	_check(c.deck._rng.state == before[8], "run RNG unchanged after Brace play")

	c = _cuff_fixture("sewn_warden", "warden_brace_plus")
	_check(c.party.gain_block(1, 6), "Warden opening block setup for Brace+")
	before = _snapshot(c.deck, c.party)
	_check(c.service.play_support(c.deck, c.party, BRACE_PLUS, 0), "Brace+ commits with cuff")
	_check(c.party.get_hero(1).block == 18 and c.deck.energy == 2 and c.deck.hand.is_empty()
		and c.deck.discard_pile == ["warden_brace_plus"], "Brace+ grants 12 (10+2) atop opening 6 Block")
	_check(c.deck._rng.state == before[8], "run RNG unchanged after Brace+ play")

	# Unworn, wrong-wearer, unsewn, moved, absent, unbound grant no bonus (base 7 Block)
	for mode in ["absent", "unsewn", "wrong", "moved", "unbound"]:
		c = _cuff_fixture(mode, "warden_brace")
		before = _snapshot(c.deck, c.party)
		_check(c.service.play_support(c.deck, c.party, BRACE, 0), mode + " remains ordinary Brace")
		_check(_snapshot(c.deck, c.party) == _expected(before, BRACE, 1) and c.party.get_hero(1).block == 7,
			mode + " exactly seven Block, normal piles/energy/RNG")

	# AC2: Stitch Up grants 7 Block (5+2) and Stitch Up+ grants 9 (7+2) only to selected ally
	for target in [1, 2, 3]:
		c = _cuff_fixture("sewn_seamstress", "seamstress_stitch_up")
		before = _snapshot(c.deck, c.party)
		_check(c.service.play_support(c.deck, c.party, STITCH, target), "Stitch Up commits with cuff on Seamstress targeting " + str(target))
		_check(c.party.get_hero(target).block == 7, "Stitch Up grants exactly 7 (5+2) Block to recipient " + str(target))
		for other in [1, 2, 3]:
			if other != target:
				_check(c.party.get_hero(other).block == 0, "non-target hero " + str(other) + " gains no Block")
		_check(c.deck.energy == 2 and c.deck.hand.is_empty() and c.deck.discard_pile == ["seamstress_stitch_up"], "one energy and discard")
		_check(c.deck._rng.state == before[8], "run RNG unchanged after Stitch Up")

	c = _cuff_fixture("sewn_seamstress", "seamstress_stitch_up_plus")
	before = _snapshot(c.deck, c.party)
	_check(c.service.play_support(c.deck, c.party, STITCH_PLUS, 1), "Stitch Up+ commits with cuff on Seamstress")
	_check(c.party.get_hero(1).block == 9 and c.deck.energy == 2, "Stitch Up+ grants 9 (7+2) Block only to recipient")
	_check(c.deck._rng.state == before[8], "run RNG unchanged after Stitch Up+")

	# AC2: Cuff on target rather than owner gives NO bonus
	c = _cuff_fixture("sewn_warden", "seamstress_stitch_up")
	before = _snapshot(c.deck, c.party)
	_check(c.service.play_support(c.deck, c.party, STITCH, 1), "Stitch Up targeting cuff wearer Warden")
	_check(c.party.get_hero(1).block == 5, "cuff on target rather than card owner grants NO bonus (base 5)")
	_check(_snapshot(c.deck, c.party) == _expected(before, STITCH, 1), "exact standard 5-block transition")

	# AC2: Unrelated cards preserve exact behavior
	c = _cuff_fixture("sewn_warden", "seamstress_mend")
	_check(c.party.apply_damage(1, 12) and c.party.get_hero(1).hp == 28, "wounded ally fixture")
	before = _snapshot(c.deck, c.party)
	_check(c.service.play_support(c.deck, c.party, MEND, 1), "Mend with cuff sewn on Warden")
	_check(c.party.get_hero(1).hp == 33, "Mend heals exactly base 5 (not 7)")
	_check(_snapshot(c.deck, c.party) == _expected(before, MEND, 1), "exact 5-heal transition")

	c = _cuff_fixture("sewn_warden", "tinker_tune_up")
	before = _snapshot(c.deck, c.party)
	_check(c.service.play_support(c.deck, c.party, TUNE, 0), "Tune Up with cuff on Warden")
	_check(c.deck.energy == 3 and c.deck.discard_pile == ["tinker_tune_up"], "Tune Up exact behavior preserved")

	# Rejections
	c = _cuff_fixture("sewn_warden", "warden_brace")
	for change in [{"amount": 9}, {"amount": 0}, {"amount": 999}, {"owner_id": "seamstress"},
		{"id": "fake_brace"}, {"from_positions": [2, 3]}, {"cost": 0}, {"effect": "self_heal"}]:
		var forged := BRACE.duplicate(true)
		for key in change:
			forged[key] = change[key]
		if change.has("id"):
			c.deck.hand.append("fake_brace")
		_bound_reject(c, forged, 0, "spoofed brace " + str(change))

	# Block overflow with cuff bonus
	c = _cuff_fixture("sewn_warden", "warden_brace")
	_check(c.party.gain_block(1, CombatParty.MAX_INT - 8), "Warden Block almost full")
	_bound_reject(c, BRACE, 0, "cuff Block overflow rejects before spending")

	# Torn wearer in ledger cannot play or grant bonus
	c = _cuff_fixture("torn", "warden_brace")
	_check(c.party.is_downed(1) and c.torn.read_state().tear_counts.warden == 1, "Warden truly torn")
	_bound_reject(c, BRACE, 0, "torn Warden cannot play Brace")

	# Divergent state (Lesson 37): fresh combat party with positive HP while run ledger has Warden torn
	c = _cuff_fixture("torn", "warden_brace")
	var fresh_heroes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in fresh_heroes:
		hero.max_hp = int(hero.max_hp)
	c.party = CombatParty.new(fresh_heroes)
	_check(c.party.is_valid() and not c.party.is_downed(1) and c.torn.read_state().heroes[0]["hp"] == 0,
		"divergent fixture: party alive, torn ledger zero HP")
	_check(c.service.play_support(c.deck, c.party, BRACE, 0), "divergent party plays Brace")
	_check(c.party.get_hero(1).block == 7, "torn wearer in run ledger receives base 7 Block, NO cuff bonus")


## Genuine M05 HEAD ledger, never a fabricated bonus projection. Each fixture
## starts from the authored roster and sews through RunPatchWardrobe.
func _browband_fixture(mode: String, card_id: String, owner_id: String,
		seed_value: int = 42) -> Dictionary:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in definitions:
		_check(hero.max_hp == floor(hero.max_hp), "HEAD fixture authored integral HP")
		hero.max_hp = int(hero.max_hp)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(1).id == "warden"
		and party.get_hero(2).id == "seamstress", "HEAD fixture has authentic owners")
	var torn := RunTornMending.new(party.get_heroes())
	var slots: Array = []
	for catalog_path in [CombatM05HeadPatchRules.CATALOG_PATH,
			CombatPatchAttackRules.SUPPORT_CATALOG]:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		_check(records is Array, "HEAD fixture real patch catalog loads: " + catalog_path)
		for record in records:
			if record.get("id") in ["reinforced_browband", "hemguard_cuff"]:
				slots.append({"id": record.id, "slot": record.slot})
	_check(slots.size() == 2, "HEAD and ARM definitions come from both real catalogs")
	var owned: Array = []
	if mode not in ["absent", "arm_only"]:
		owned.append("reinforced_browband")
	if mode in ["both", "arm_only"]:
		owned.append("hemguard_cuff")
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, slots, 5)
	_check(wardrobe.is_valid() and torn.is_valid(), "authentic HEAD/ARM wardrobe and torn ledgers")
	if mode not in ["absent", "unsewn", "arm_only"]:
		var actual_head_wearer := owner_id
		if mode == "wrong":
			actual_head_wearer = "seamstress" if owner_id == "warden" else "warden"
		_check(wardrobe.sew("reinforced_browband", actual_head_wearer, "HEAD",
			"head-sew", wardrobe.get_snapshot()).ok, "authentic HEAD sew: " + mode)
	if mode in ["both", "arm_only"]:
		_check(wardrobe.sew("hemguard_cuff", owner_id, "ARM", "arm-sew",
			wardrobe.get_snapshot()).ok, "authentic ARM sew alongside HEAD")
	if mode == "torn":
		var start: Array = torn.read_state().heroes
		var finish: Array = start.duplicate(true)
		for hero in finish:
			if hero.id == owner_id:
				hero.hp = 0
		_check(torn.observe_battle_end("head-tear", start, finish).ok,
			"real HEAD wearer torn in run ledger")
		var state := wardrobe.get_snapshot()
		_check(wardrobe.refresh_run_context(torn.read_state().heroes, state.owned,
			state.scraps, state.gold, state.cards, state), "reconcile torn HEAD wearer")
		party._heroes.assign(torn.read_state().heroes)
	var resolver := CombatSupportCards.new()
	if mode != "unbound":
		var ws := wardrobe.get_snapshot()
		var ts := torn.read_state()
		_check(resolver.bind_patch_wardrobe(wardrobe, torn, ws, ts)
			and resolver.is_patch_binding_valid(),
			"HEAD binding authentic and snapshot-matched: " + mode)
	return {"party": party, "deck": _deck([card_id], seed_value),
		"service": resolver, "wardrobe": wardrobe, "torn": torn}


func _head_block_case(mode: String, definition: Dictionary, amount: int, seed_value: int) -> void:
	var owner: String = definition.owner_id
	var card_id: String = definition.id
	var c := _browband_fixture(mode, card_id, owner, seed_value)
	var target := 0 if owner == "warden" else 1
	var recipient := 1
	var before := _snapshot(c.deck, c.party)
	var original_wardrobe: Dictionary = c.wardrobe.get_snapshot()
	var original_torn: Dictionary = c.torn.read_state()
	_check(c.deck.hand.count(card_id) == 1 and c.deck.energy == 3
		and not c.party.is_downed(1 if owner == "warden" else 2),
		"nonvacuous held HEAD support and living owner: " + card_id + "/" + mode)
	if mode != "unbound":
		var projection: Dictionary = c.service._head_patches.read_projection()
		var head_bonus: int = c.service._head_patches.get_bonus(owner, card_id, "block")
		_check(projection.get("ok") == true and head_bonus == (2 if mode in ["head", "both"] else 0),
			"read-only original-owner HEAD projection: " + card_id + "/" + mode)
		_check(_snapshot(c.deck, c.party) == before
			and c.wardrobe.get_snapshot() == original_wardrobe
			and c.torn.read_state() == original_torn,
			"HEAD projection never plays a card, touches ledgers or advances RNG")
	var predicted := definition.duplicate(true)
	predicted.amount = amount
	var expected := _expected(before, predicted, recipient)
	_check(c.service.play_support(c.deck, c.party, definition, target),
		"HEAD held support commits: " + card_id + "/" + mode)
	_check(_snapshot(c.deck, c.party) == expected,
		"exact HEAD+ARM Block, one printed-energy spend, piles, heroes, turn and RNG: " + card_id + "/" + mode)
	_check(c.party.get_hero(recipient).block == amount
		and c.deck.hand.count(card_id) == 0 and c.deck.discard_pile.count(card_id) == 1,
		"one award to correct recipient and exactly one held discard: " + card_id + "/" + mode)
	for other in [1, 2, 3]:
		if other != recipient:
			_check(c.party.get_hero(other).block == 0,
				"HEAD support never grants Block to nonrecipient: " + card_id + "/" + mode)
	_check(c.wardrobe.get_snapshot() == original_wardrobe
		and c.torn.read_state() == original_torn, "committed support does not sew or mutate run ledgers")
	_bound_reject(c, definition, target, "HEAD spent card cannot replay " + card_id + "/" + mode)


func _test_reinforced_browband() -> void:
	# Four complete printed/HEAD/ARM/additive outcome matrices. Each run
	# asserts the full exact party/deck/RNG transition, not just a Block number.
	for definition in [BRACE, BRACE_PLUS, STITCH, STITCH_PLUS]:
		for mode in ["absent", "unsewn", "wrong", "unbound", "arm_only", "head", "both"]:
			var bonus := 4 if mode == "both" else (2 if mode in ["head", "arm_only"] else 0)
			for seed_value in [42, 987654]:
				_head_block_case(mode, definition, int(definition.amount) + bonus, seed_value)

	# The wearer identity survives legal physical position movement.
	var c := _browband_fixture("both", "warden_brace_plus", "warden")
	var heroes: Array = c.party.get_heroes()
	c.party = CombatParty.new([heroes[1], heroes[2], heroes[0]])
	_check(c.party.get_hero(3).id == "warden" and not c.party.is_downed(3),
		"HEAD+ARM Warden physically moves to legal back slot")
	_check(c.service.play_support(c.deck, c.party, BRACE_PLUS, 0)
		and c.party.get_hero(3).block == 14 and c.party.get_hero(1).block == 0,
		"legal moved Warden receives precisely 10+2+2, not position-owner bonus")

	# Wrong-wearer contrast: Warden wearing HEAD is the *recipient*, not the
	# Seamstress card owner. It must not improve Stitch Up or Stitch Up+.
	for definition in [STITCH, STITCH_PLUS]:
		c = _browband_fixture("wrong", definition.id, "seamstress")
		var before := _snapshot(c.deck, c.party)
		_check(c.wardrobe.project_active(c.torn.read_state()).active.warden.has("reinforced_browband"),
			"recipient really wears the wrong-owner Browband")
		_check(c.service.play_support(c.deck, c.party, definition, 1)
			and _snapshot(c.deck, c.party) == _expected(before, definition, 1),
			"target-owned HEAD cannot add to original Stitch Block")

	# Reject rather than charge when printed Block fits but HEAD or HEAD+ARM
	# makes the authoritative resulting Block exceed capacity.
	for mode in ["head", "both"]:
		c = _browband_fixture(mode, BRACE.id, "warden")
		var limit := CombatParty.MAX_INT - (8 if mode == "head" else 10)
		_check(c.party.gain_block(1, limit), "HEAD Block-capacity boundary prepared")
		_bound_reject(c, BRACE, 0, mode + " overflow checked before spend")

	# All failed preconditions leave every HP/Block, pile, energy, turn, RNG
	# and both genuine ledgers byte-for-byte identical.
	c = _browband_fixture("both", BRACE.id, "warden")
	_bound_reject(c, BRACE, 2, "HEAD self targeting forbidden")
	for edit in [{"amount": 11}, {"cost": 0}, {"owner_id": "seamstress"},
			{"from_positions": [2, 3]}, {"effect": "ally_block"}]:
		var forged := BRACE.duplicate(true)
		for key in edit:
			forged[key] = edit[key]
		_bound_reject(c, forged, 0, "forged HEAD card " + str(edit))
	_check(c.deck.try_spend_energy(3), "HEAD no-energy fixture actually depleted")
	_bound_reject(c, BRACE, 0, "HEAD cannot play without energy")
	c = _browband_fixture("both", STITCH.id, "seamstress")
	_bound_reject(c, STITCH, 0, "HEAD Stitch requires a selected ally")
	_check(c.party.apply_damage(3, 26) and c.party.is_downed(3),
		"HEAD recipient genuinely downed")
	_bound_reject(c, STITCH, 3, "HEAD cannot grant Block to downed ally")

	# A run tear disables the HEAD even in a reconciled wardrobe.
	for definition in [BRACE, STITCH]:
		c = _browband_fixture("torn", definition.id, definition.owner_id)
		_check(c.torn.read_state().tear_counts[definition.owner_id] == 1,
			"authentic HEAD owner tear counted")
		_bound_reject(c, definition, 0 if definition.owner_id == "warden" else 1,
			"torn HEAD owner cannot cast")

	# A changed run authority invalidates an old explicit binding, including a
	# legal re-sew; only a new matching binding recovers plain printed Block.
	c = _browband_fixture("head", BRACE.id, "warden")
	var wardrobe: RunPatchWardrobe = c.wardrobe
	_check(wardrobe.start_rest("head-rest", wardrobe.get_snapshot()).ok,
		"HEAD Rest opens for re-sew")
	_check(wardrobe.re_sew("reinforced_browband", "warden", "seamstress",
		"head-rest", "move-head", wardrobe.get_snapshot()).ok,
		"HEAD moved off caster by real re-sew")
	_check(wardrobe.end_rest("head-rest", wardrobe.get_snapshot()).ok,
		"HEAD Rest closes")
	_bound_reject(c, BRACE, 0, "stale HEAD ledger after re-sew")
	_check(c.service.bind_patch_wardrobe(wardrobe, c.torn, wardrobe.get_snapshot(),
		c.torn.read_state()), "fresh HEAD rebind follows re-sew")
	var before := _snapshot(c.deck, c.party)
	_check(c.service.play_support(c.deck, c.party, BRACE, 0)
		and _snapshot(c.deck, c.party) == _expected(before, BRACE, 1),
		"re-sewn Browband on other hero never adds to Warden Block")

	for failure_mode in ["null", "forged_wardrobe", "forged_torn", "invalid_torn"]:
		c = _browband_fixture("head", BRACE.id, "warden")
		var ws: Dictionary = c.wardrobe.get_snapshot()
		var ts: Dictionary = c.torn.read_state()
		var bound_ok := false
		match failure_mode:
			"null":
				bound_ok = c.service.bind_patch_wardrobe(null, c.torn)
			"forged_wardrobe":
				ws.scraps += 1
				bound_ok = c.service.bind_patch_wardrobe(c.wardrobe, c.torn, ws, ts)
			"forged_torn":
				ts.heroes[0].hp -= 1
				bound_ok = c.service.bind_patch_wardrobe(c.wardrobe, c.torn, ws, ts)
			"invalid_torn":
				bound_ok = c.service.bind_patch_wardrobe(c.wardrobe, RunTornMending.new())
		_check(not bound_ok and not c.service.is_patch_binding_valid(),
			"invalid explicit HEAD bind fails closed: " + failure_mode)
		_bound_reject(c, BRACE, 0, "explicitly failed HEAD bind " + failure_mode)

	# Neither Mend nor a zero-cost draw acquires Block from HEAD.
	for choice in [{"id": "seamstress_mend", "owner": "seamstress", "def": MEND, "target": 1},
			{"id": "tinker_tune_up", "owner": "tinker", "def": TUNE, "target": 0}]:
		c = _browband_fixture("head", choice.id, choice.owner)
		var initial := _snapshot(c.deck, c.party)
		_check(c.service._head_patches.get_bonus(choice.owner, choice.id, "block") == 0,
			"HEAD cannot project Block for non-Block starter support")
		if choice.id == "seamstress_mend":
			_check(c.party.apply_damage(1, 8), "non-Block Mend target wounded")
			initial = _snapshot(c.deck, c.party)
		_check(c.service.play_support(c.deck, c.party, choice["def"], choice.target),
			"authentic non-Block support still plays")
		_check(_snapshot(c.deck, c.party) == _expected(initial, choice["def"], 1),
			"HEAD leaves original Mend/Tune effect, cost, piles and RNG unchanged")
