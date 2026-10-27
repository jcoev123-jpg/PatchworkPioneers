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

## Independent literal expectations for the four authored Scarecrow straw cards,
## never read back from the resolver under test.
const STRAW_BLOCKS := {
	"scarecrow_straw_padding": 4,
	"scarecrow_straw_padding_plus": 6,
	"scarecrow_straw_wrap": 6,
	"scarecrow_straw_wrap_plus": 8,
}
const STRAW_COST := 1

## Independent literal expectations for the two authored Wax Ward pool printings,
## never read back from the resolver under test.
const WAX_BLOCKS := {
	"lantern_monk_wax_ward": 5,
	"lantern_monk_wax_ward_plus": 7,
}
const WAX_COST := 1
const WAX_PARTY_HP := {"warden": 40, "seamstress": 30, "tinker": 26, "lantern_monk": 30}

var failures: Array[String] = []
var checks := 0
var service := CombatSupportCards.new()
var wax := CombatLanternMonkWaxWardCards.new()


func _initialize() -> void:
	_test_four_cards()
	_test_draw_order()
	_test_rejections()
	_test_replay()
	_test_spare_spool()
	_test_bound_rejections()
	_test_hemguard_cuff()
	_test_reinforced_browband()
	_test_scarecrow_straw()
	_test_lantern_monk_wax_ward()
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


## Three distinct living heroes, with the one true Scarecrow at the given position.
func _straw_party(scarecrow_position: int = 1) -> CombatParty:
	var others: Array[String] = ["warden", "seamstress", "tinker"]
	var roster: Array = []
	for position in [1, 2, 3]:
		if position == scarecrow_position:
			roster.append({"id": "scarecrow", "max_hp": 34})
		else:
			roster.append({"id": others.pop_front(), "max_hp": 30})
	var party := CombatParty.new(roster)
	_check(party.is_valid() and party.get_heroes().size() == 3
		and party.get_hero(scarecrow_position).get("id") == "scarecrow",
		"fixture builds three distinct heroes with a living Scarecrow at " + str(scarecrow_position))
	return party


## A real started turn whose hand genuinely holds card_id. Six or more authored
## cards leave a remainder in the draw pile, which a real draw pulls into the hand.
func _straw_deck(cards: Array[String], seed_value: int, card_id: String) -> CombatDeck:
	var deck := _deck(cards, seed_value)
	var guard := 0
	while not deck.hand.has(card_id) and guard < cards.size():
		_check(deck.draw_extra(1) == 1, "fixture draws " + card_id + " into the shared hand")
		guard += 1
	_check(deck.hand.has(card_id) and deck.turn_active and deck.energy == CombatState.TURN_ENERGY,
		"fixture genuinely holds a playable " + card_id)
	return deck


## Independent oracle: one printed-energy charge, Block on the selected recipient,
## one shared-deck draw through the existing seeded refill, then one discard.
func _straw_expected(before: Array, card_id: String, block: int, recipient: int) -> Array:
	var after := before.duplicate(true)
	after[4] -= STRAW_COST
	after[6] -= STRAW_COST
	after[7][recipient - 1]["block"] += block
	_oracle_draw(after, 1)
	var index: int = after[1].find(card_id)
	if index < 0:
		return after
	after[1].remove_at(index)
	after[2].append(card_id)
	return after


func _straw_accepted(deck: CombatDeck, party: CombatParty, card_id: String, target: int,
		label: String) -> void:
	var block: int = STRAW_BLOCKS[card_id]
	var blocks_before: Array[int] = []
	for position in [1, 2, 3]:
		blocks_before.append(party.get_hero(position)["block"])
	var hand_before: int = deck.hand.count(card_id)
	var discard_before: int = deck.discard_pile.count(card_id)
	var energy_before: int = deck.energy
	var hand_size_before: int = deck.hand.size()
	var drawable: int = deck.draw_pile.size() + deck.discard_pile.size()
	var before := _snapshot(deck, party)
	_check(deck.hand.has(card_id) and deck.turn_active and energy_before >= STRAW_COST,
		label + ": real shared hand, active turn and energy before play")

	_check(service.play_scarecrow_straw(deck, party, card_id, target), label + ": accepted")
	_check(_snapshot(deck, party) == _straw_expected(before, card_id, block, target),
		label + ": complete piles, party, energy, turn and seeded RNG transition")
	_check(party.get_hero(target)["block"] == blocks_before[target - 1] + block,
		label + ": target alone gains printed Block " + str(block))
	for other in [1, 2, 3]:
		if other != target:
			_check(party.get_hero(other)["block"] == blocks_before[other - 1],
				label + ": non-target " + str(other) + " gains no Block")
	_check(deck.energy == energy_before - STRAW_COST, label + ": exactly one energy spent")
	_check(deck.hand.count(card_id) == hand_before - 1
		and deck.discard_pile.count(card_id) == discard_before + 1,
		label + ": exactly one held copy moved to discard")
	_check(deck.hand.size() == hand_size_before - 1 + (1 if drawable > 0 else 0),
		label + ": exactly one shared-deck draw attempted")


func _straw_rejected(deck: CombatDeck, party: CombatParty, card_id: Variant, target: int,
		label: String) -> void:
	var before := _snapshot(deck, party)
	_check(not service.play_scarecrow_straw(deck, party, card_id, target), label + ": rejected")
	_check(_snapshot(deck, party) == before,
		label + ": atomic rejection preserves party, piles, energy, turn and seeded RNG")


func _test_scarecrow_straw() -> void:
	_test_scarecrow_straw_matrix()
	_test_scarecrow_straw_draw_paths()
	_test_scarecrow_straw_replay()
	_test_scarecrow_straw_rejections()


## AC1: all four genuine IDs, every legal Scarecrow source slot and every legal
## living recipient (Scarecrow itself included) receive only the printed Block
## while the one shared hand draws once.
func _test_scarecrow_straw_matrix() -> void:
	var starter := ScarecrowStarterCards.new()
	var pool := ScarecrowPoolCards.new()
	for card_id: String in STRAW_BLOCKS:
		_check(starter.has_card(card_id) or pool.has_card(card_id),
			card_id + " is a genuine authored Scarecrow catalog record")
		var record: Dictionary = starter.get_definition(card_id)
		if record.is_empty():
			record = pool.get_definition(card_id)
		_check(record.get("effects").get("block") == STRAW_BLOCKS[card_id],
			card_id + " authored Block matches the independent expectation")
		_check(record.get("effects").get("draw") == 1, card_id + " authored draw is exactly one")
		_check(record.get("cost") == STRAW_COST, card_id + " authored cost is one energy")
		_check(record.get("owner") == "scarecrow" and record.get("target_kind") == "ally_single",
			card_id + " is a Scarecrow ally support card")
		for scarecrow_position in [1, 2, 3]:
			for target in [1, 2, 3]:
				var party := _straw_party(scarecrow_position)
				var deck := _straw_deck([card_id, "straw_a", "straw_b", "straw_c",
					"straw_d", "straw_e"], 42, card_id)
				_straw_accepted(deck, party, card_id, target, card_id + " from "
					+ str(scarecrow_position) + " to " + str(target))


## AC2: ordinary draw, older-discard refill and a genuinely exhausted deck all
## succeed with exactly one energy and one discard, and two plays in one turn
## never charge or discard twice.
func _test_scarecrow_straw_draw_paths() -> void:
	# Exhausted deck: the paid Block still resolves and zero cards are drawn.
	var empty_party := _straw_party(3)
	var empty_deck := _straw_deck(["scarecrow_straw_wrap_plus"], 42, "scarecrow_straw_wrap_plus")
	_check(empty_deck.draw_pile.is_empty() and empty_deck.discard_pile.is_empty(),
		"exhausted fixture genuinely has nothing to draw")
	_straw_accepted(empty_deck, empty_party, "scarecrow_straw_wrap_plus", 1, "exhausted deck")
	_check(empty_deck.hand.is_empty()
		and empty_deck.discard_pile == ["scarecrow_straw_wrap_plus"] and empty_deck.energy == 2,
		"exhausted deck: zero drawn, one printed energy and one discard")

	# Refill: the still-held card cannot enter its own reshuffle, so the older
	# discard is drawn instead of the card being played.
	var refill_party := _straw_party(1)
	var refill := _deck(["scarecrow_straw_padding", "straw_older"], 42)
	_check(refill.hand.size() == 2 and refill.draw_pile.is_empty(),
		"refill fixture deals both cards into the real shared hand")
	_check(refill.discard_played("straw_older") and refill.discard_pile == ["straw_older"],
		"refill fixture keeps exactly one older discard")
	_straw_accepted(refill, refill_party, "scarecrow_straw_padding", 2, "older-discard refill")
	_check(refill.hand == ["straw_older"] and refill.discard_pile == ["scarecrow_straw_padding"],
		"refill drew the older discard, never the card it was resolving")

	# Ordinary draw from a nonempty pile, without any reshuffle. A bounded
	# deterministic seed search finds a deal that holds the card in the initial
	# five-card hand while leaving a real card in the draw pile.
	var ordinary_party := _straw_party(2)
	var ordinary: CombatDeck = null
	for seed_value in range(1, 65):
		var candidate := CombatDeck.new(["scarecrow_straw_padding", "straw_a", "straw_b",
			"straw_c", "straw_d", "straw_e"], _rng(seed_value))
		if candidate.start_turn() and candidate.hand.has("scarecrow_straw_padding") \
				and not candidate.draw_pile.is_empty():
			ordinary = candidate
			break
	_check(ordinary != null, "bounded seeded search finds an ordinary nonempty draw pile")
	if ordinary != null:
		var pile_before: int = ordinary.draw_pile.size()
		_straw_accepted(ordinary, ordinary_party, "scarecrow_straw_padding", 3, "ordinary pile draw")
		_check(ordinary.draw_pile.size() == pile_before - 1,
			"ordinary draw consumed exactly one card from the existing draw pile")

	# A second held copy stays in hand: one play consumes exactly one copy.
	var twin_party := _straw_party(1)
	var twin := _deck(["scarecrow_straw_padding", "scarecrow_straw_padding", "straw_a"], 42)
	_check(twin.hand.count("scarecrow_straw_padding") == 2,
		"duplicate-copy fixture genuinely holds two straw copies")
	_straw_accepted(twin, twin_party, "scarecrow_straw_padding", 1, "one of two held copies")
	_check(twin.hand.count("scarecrow_straw_padding") == 1
		and twin.discard_pile.count("scarecrow_straw_padding") == 1,
		"one play leaves the second held copy untouched")

	# Two legal plays in one turn charge and discard once each.
	var pair_party := _straw_party(2)
	var pair := _deck(["scarecrow_straw_padding", "scarecrow_straw_wrap", "straw_a",
		"straw_b", "straw_c"], 42)
	_check(pair.hand.has("scarecrow_straw_padding") and pair.hand.has("scarecrow_straw_wrap"),
		"two-play fixture genuinely holds both straw cards")
	_straw_accepted(pair, pair_party, "scarecrow_straw_padding", 1, "first straw play of the turn")
	_check(pair.energy == 2, "first straw play leaves two energy")
	_straw_accepted(pair, pair_party, "scarecrow_straw_wrap", 3, "second straw play of the turn")
	_check(pair.energy == 1
		and pair_party.get_hero(1)["block"] == STRAW_BLOCKS["scarecrow_straw_padding"]
		and pair_party.get_hero(3)["block"] == STRAW_BLOCKS["scarecrow_straw_wrap"]
		and pair_party.get_hero(2)["block"] == 0,
		"two plays grant their own printed Block and spend one energy each")


func _straw_sequence(seed_value: int) -> Array:
	var party := _straw_party(2)
	var deck := _straw_deck(["scarecrow_straw_padding", "scarecrow_straw_wrap",
		"straw_a", "straw_b", "straw_c", "straw_d"], seed_value, "scarecrow_straw_padding")
	var trace: Array = [_snapshot(deck, party)]
	_check(service.play_scarecrow_straw(deck, party, "scarecrow_straw_padding", 3),
		"straw replay Padding commits")
	trace.append(_snapshot(deck, party))
	if not deck.hand.has("scarecrow_straw_wrap"):
		_check(deck.draw_extra(1) == 1, "straw replay fixture draws Wrap into the shared hand")
	_check(deck.hand.has("scarecrow_straw_wrap"), "straw replay fixture genuinely holds Wrap")
	_check(service.play_scarecrow_straw(deck, party, "scarecrow_straw_wrap", 1),
		"straw replay Wrap commits")
	trace.append(_snapshot(deck, party))
	_straw_rejected(deck, party, "scarecrow_straw_wrap", 2, "straw replay Wrap is consumed")
	_check(deck.end_turn() and deck.start_turn(), "straw replay refills a real next shared turn")
	trace.append(_snapshot(deck, party))
	return trace


## Seeded refill order and RNG progression replay exactly across identical runs.
func _test_scarecrow_straw_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var first := _straw_sequence(seed_value)
		var second := _straw_sequence(seed_value)
		_check(first.size() == 4 and second.size() == 4,
			"straw replay records four complete real snapshots")
		_check(first == second, "identical straw plays, seed and refill replay exactly")


## AC3: every failed precondition rejects without spending, drawing, discarding,
## granting Block or advancing the seeded RNG.
func _test_scarecrow_straw_rejections() -> void:
	var card_id := "scarecrow_straw_padding"

	# Inactive shared turn while the genuine card and all three energy remain.
	var inactive := _straw_deck([card_id, "straw_a", "straw_b"], 42, card_id)
	inactive.combat_state.end_player_turn()
	inactive.combat_state.energy = CombatState.TURN_ENERGY
	_check(not inactive.turn_active and inactive.hand.has(card_id) and inactive.energy == 3,
		"inactive-turn fixture still holds the real card and full energy")
	_straw_rejected(inactive, _straw_party(1), card_id, 1, "inactive shared turn")

	# Null services and an invalid party.
	var ready := _straw_deck([card_id], 42, card_id)
	_check(not service.play_scarecrow_straw(null, _straw_party(1), card_id, 1),
		"null deck rejects safely")
	_check(not service.play_scarecrow_straw(ready, null, card_id, 1), "null party rejects safely")
	_straw_rejected(ready, CombatParty.new([]), card_id, 1, "invalid party")

	# The card exists but is not in the actual hand.
	var absent := _straw_deck([card_id, "straw_a", "straw_b", "straw_c"], 42, card_id)
	_check(absent.discard_played(card_id) and not absent.hand.has(card_id)
		and absent.discard_pile.has(card_id),
		"absent-from-hand fixture really moved the card into discard")
	_straw_rejected(absent, _straw_party(1), card_id, 1, "card absent from the actual hand")

	# Genuine but unsupported Scarecrow and other-hero IDs, each really held.
	for bad_id: String in ["scarecrow_fork_jab", "scarecrow_crow_peck", "warden_brace"]:
		var bad_deck := _straw_deck([bad_id], 42, bad_id)
		_check(bad_deck.hand.has(bad_id), "unsupported-ID fixture genuinely holds " + bad_id)
		_straw_rejected(bad_deck, _straw_party(1), bad_id, 1, "unsupported card ID " + bad_id)

	# Unknown, malformed and forged values reject while the real straw card is held.
	var held := _straw_deck([card_id], 42, card_id)
	for bad_value in ["scarecrow_straw_padding_plus_plus", "", "straw_padding", 7, null,
			StringName("scarecrow_straw_padding"),
			{"id": card_id, "effects": {"block": 999, "draw": 1}}]:
		_straw_rejected(held, _straw_party(1), bad_value, 1, "unsupported identifier " + str(bad_value))

	# Missing Scarecrow in an otherwise valid, funded party.
	var no_scarecrow := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(no_scarecrow.is_valid(), "party without Scarecrow is otherwise valid")
	var missing := _straw_deck([card_id], 42, card_id)
	_check(missing.hand.has(card_id) and missing.energy == 3,
		"missing-owner fixture is otherwise entirely playable")
	_straw_rejected(missing, no_scarecrow, card_id, 1, "no Scarecrow in the party")

	# Downed Scarecrow in each legal source slot.
	for scarecrow_position in [1, 2, 3]:
		var downed_party := _straw_party(scarecrow_position)
		_check(downed_party.apply_damage(scarecrow_position, 999)
			and downed_party.is_downed(scarecrow_position),
			"downed Scarecrow fixture at " + str(scarecrow_position))
		_straw_rejected(_straw_deck([card_id], 42, card_id), downed_party, card_id, 1,
			"downed Scarecrow at " + str(scarecrow_position))

	# Insufficient shared energy.
	var poor := _straw_deck([card_id], 42, card_id)
	_check(poor.try_spend_energy(3) and poor.energy == 0,
		"energy-shortage fixture really spent all three energy")
	_straw_rejected(poor, _straw_party(1), card_id, 1, "insufficient shared energy")

	# Invalid recipients.
	var targets := _straw_deck([card_id], 42, card_id)
	for bad_target in [-1, 0, 4]:
		_straw_rejected(targets, _straw_party(2), card_id, bad_target,
			"invalid recipient " + str(bad_target))

	# Downed recipients, while the Scarecrow owner itself stays living.
	for target in [1, 3]:
		var hurt := _straw_party(2)
		_check(hurt.apply_damage(target, 999) and hurt.is_downed(target) and not hurt.is_downed(2),
			"downed recipient fixture at " + str(target))
		_straw_rejected(_straw_deck([card_id], 42, card_id), hurt, card_id, target,
			"downed recipient " + str(target))

	# Target Block overflow rejects before spending; the exact boundary is legal.
	var full := _straw_party(1)
	_check(full.gain_block(1, CombatParty.MAX_INT - STRAW_BLOCKS[card_id] + 1),
		"overflow fixture leaves one point less room than the printed Block")
	_straw_rejected(_straw_deck([card_id], 42, card_id), full, card_id, 1,
		"target Block overflow rejects before spending")
	var boundary := _straw_party(1)
	_check(boundary.gain_block(1, CombatParty.MAX_INT - STRAW_BLOCKS[card_id]),
		"capacity boundary fixture leaves exactly enough room")
	var boundary_deck := _straw_deck([card_id], 42, card_id)
	var boundary_before := _snapshot(boundary_deck, boundary)
	_check(service.play_scarecrow_straw(boundary_deck, boundary, card_id, 1),
		"exact capacity boundary play succeeds")
	_check(boundary.get_hero(1)["block"] == CombatParty.MAX_INT
		and _snapshot(boundary_deck, boundary) == _straw_expected(boundary_before, card_id,
			STRAW_BLOCKS[card_id], 1),
		"capacity boundary reaches MAX_INT with no overflow")

	# A consumed copy cannot be played twice.
	var consumed_party := _straw_party(1)
	var consumed := _straw_deck([card_id], 42, card_id)
	_check(service.play_scarecrow_straw(consumed, consumed_party, card_id, 1),
		"first straw play really commits")
	_straw_rejected(consumed, consumed_party, card_id, 1, "consumed copy cannot be replayed")

	# The existing patch-binding validity guard covers straw support too.
	var classic := _party()
	var torn := RunTornMending.new(classic.get_heroes())
	var slots: Array = JSON.parse_string(FileAccess.get_file_as_string(CombatShopPatchRules.SLOTS_CATALOG))
	var wardrobe := RunPatchWardrobe.new(classic.get_heroes(), [], slots, 5)
	_check(wardrobe.is_valid() and torn.is_valid(), "real patch ledgers for the straw binding guard")
	_check(service.bind_patch_wardrobe(wardrobe, torn) and service.is_patch_binding_valid(),
		"valid patch binding still allows straw support")
	_straw_accepted(_straw_deck([card_id], 42, card_id), _straw_party(1), card_id, 1,
		"straw support under a valid patch binding")
	_check(wardrobe.start_rest("straw-rest", wardrobe.get_snapshot()).ok,
		"real ledger really advances after binding")
	_check(not service.is_patch_binding_valid(), "advanced ledger really invalidates the binding")
	_straw_rejected(_straw_deck([card_id], 42, card_id), _straw_party(1), card_id, 1,
		"stale patch binding rejects straw support atomically")
	_check(service.bind_patch_wardrobe(wardrobe, torn) and service.is_patch_binding_valid(),
		"fresh binding recovers the straw resolver")
	var recovered := _straw_deck([card_id], 42, card_id)
	var recovered_party := _straw_party(1)
	_check(service.play_scarecrow_straw(recovered, recovered_party, card_id, 1)
		and recovered_party.get_hero(1)["block"] == STRAW_BLOCKS[card_id],
		"recovered binding restores the printed straw Block")


## ------------------------------------------------------------------ Lantern Monk Wax Ward

## A catalog double whose records can be rewritten, so forged or relinked pool metadata is
## mockable without touching the real Lantern Monk catalog.
class ForgedWaxCatalog extends RefCounted:
	var records: Dictionary = {}


	func _init(definitions: Dictionary) -> void:
		records = definitions


	## Mirrors LanternMonkPoolCards.get_definition: a non-string or unknown ID is {}.
	func get_definition(card_id: Variant) -> Dictionary:
		if typeof(card_id) != TYPE_STRING:
			return {}
		var id: String = card_id
		if not records.has(id):
			return {}
		var record: Dictionary = records[id]
		return record.duplicate(true)


## Three distinct living heroes, with the one true Lantern Monk at the given position.
func _wax_party(monk_position: int) -> CombatParty:
	var others: Array[String] = ["warden", "seamstress", "tinker"]
	var roster: Array = []
	for position in [1, 2, 3]:
		if position == monk_position:
			roster.append({"id": "lantern_monk", "max_hp": WAX_PARTY_HP["lantern_monk"]})
		else:
			var hero_id: String = others.pop_front()
			roster.append({"id": hero_id, "max_hp": WAX_PARTY_HP[hero_id]})
	var party := CombatParty.new(roster)
	_check(party.is_valid() and party.get_heroes().size() == 3
		and party.get_hero(monk_position).get("id") == "lantern_monk",
		"Wax Ward fixture builds three distinct heroes with a living Monk at "
			+ str(monk_position))
	return party


## A real started turn whose hand genuinely holds every required ID. Extra authored cards leave
## a remainder in the draw pile, which a real draw pulls into the hand.
func _wax_deck(cards: Array[String], seed_value: int, required: Array[String]) -> CombatDeck:
	var deck := _deck(cards, seed_value)
	var guard := 0
	while guard < cards.size():
		var held := true
		for card_id in required:
			if not deck.hand.has(card_id):
				held = false
		if held:
			break
		_check(deck.draw_extra(1) == 1, "Wax Ward fixture draws the next required card")
		guard += 1
	for card_id in required:
		_check(deck.hand.has(card_id) and deck.turn_active
			and deck.energy == CombatState.TURN_ENERGY,
			"Wax Ward fixture genuinely holds a playable " + card_id)
	return deck


## Independent oracle: one printed-energy charge, additive Block on the Monk's own current seat,
## one discard, and no draw, heal, cleanse, status or RNG advance.
func _wax_expected(before: Array, card_id: String, block: int, owner_position: int) -> Array:
	var after := before.duplicate(true)
	after[4] -= WAX_COST
	after[6] -= WAX_COST
	after[7][owner_position - 1]["block"] += block
	var index: int = after[1].find(card_id)
	if index < 0:
		return after
	after[1].remove_at(index)
	after[2].append(card_id)
	return after


func _wax_accepted(deck: CombatDeck, party: CombatParty, card_id: String, monk_position: int,
		label: String) -> void:
	var block: int = WAX_BLOCKS[card_id]
	var heroes_before := party.get_heroes()
	var block_before: int = heroes_before[monk_position - 1]["block"]
	var hand_before: int = deck.hand.count(card_id)
	var discard_before: int = deck.discard_pile.count(card_id)
	var energy_before: int = deck.energy
	var draw_before: Array = deck.draw_pile.duplicate()
	var before := _snapshot(deck, party)
	_check(deck.hand.has(card_id) and deck.turn_active and energy_before >= WAX_COST,
		label + ": real shared hand, active turn and energy before play")

	var receipt := wax.play_card(deck, party, card_id)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": accepted")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == WAX_COST
		and receipt.get("owner_position") == monk_position
		and receipt.get("block_gained") == block
		and receipt.get("block_before") == block_before
		and receipt.get("block_after") == block_before + block,
		label + ": receipt names exact card, cost, owner seat and Block")
	_check(_snapshot(deck, party) == _wax_expected(before, card_id, block, monk_position),
		label + ": complete piles, party, energy, turn and seeded RNG transition")
	_check(party.get_hero(monk_position)["block"] == block_before + block,
		label + ": Monk alone gains additive printed Block " + str(block))
	var heroes_after := party.get_heroes()
	for position in [1, 2, 3]:
		if position != monk_position:
			_check(heroes_after[position - 1] == heroes_before[position - 1],
				label + ": non-owner hero " + str(position) + " record is byte-identical")
	_check(deck.energy == energy_before - WAX_COST,
		label + ": exactly one printed energy spent")
	_check(deck.hand.count(card_id) == hand_before - 1
		and deck.discard_pile.count(card_id) == discard_before + 1,
		label + ": exactly one held copy moved to discard")
	_check(deck.draw_pile == draw_before, label + ": no card is drawn or reshuffled")


func _wax_rejected(deck: CombatDeck, party: CombatParty, card_id: Variant, target: int,
		label: String) -> void:
	var before := _snapshot(deck, party)
	var receipt := wax.play_card(deck, party, card_id, target)
	_check(receipt.get("ok") == false and receipt.get("reason") is String,
		label + ": refused with a structured reason")
	_check(_snapshot(deck, party) == before,
		label + ": atomic refusal preserves party, piles, energy, turn and seeded RNG")


func _test_lantern_monk_wax_ward() -> void:
	_test_wax_ward_matrix()
	_test_wax_ward_two_copies()
	_test_wax_ward_replay()
	_test_wax_ward_rejections()


## AC1: both genuine printings, from a living Monk at each of seats 1-3, spend one printed energy,
## discard one held copy and add only the printed Block to the Monk atop any existing Block.
func _test_wax_ward_matrix() -> void:
	var pool := LanternMonkPoolCards.new()
	for card_id: String in WAX_BLOCKS:
		_check(pool.has_card(card_id),
			card_id + " is a genuine authored Lantern Monk pool record")
		var record: Dictionary = pool.get_definition(card_id)
		_check(record.get("owner") == "lantern_monk" and record.get("target_kind") == "self"
			and record.get("cost") == WAX_COST
			and record.get("effects") == {"block": WAX_BLOCKS[card_id]}
			and record.get("from_positions") == [1, 2, 3] and record.get("to_positions") == [],
			card_id + " authored line matches the independent expectation")
		_check(wax.is_supported_card(card_id), card_id + " is supported")
		for monk_position in [1, 2, 3]:
			var party := _wax_party(monk_position)
			_check(party.gain_block(monk_position, 3), "Monk already carries Block")
			for other in [1, 2, 3]:
				if other != monk_position:
					_check(party.gain_block(other, 2 + other), "ally carries independent Block")
			party._heroes[monk_position - 1]["statuses"] = {"weak": 2}
			var deck := _wax_deck([card_id, "wax_a", "wax_b", "wax_c", "wax_d", "wax_e"],
				42, [card_id])
			_wax_accepted(deck, party, card_id, monk_position,
				card_id + " from a living Monk at " + str(monk_position))
			_check(party.get_hero(monk_position)["block"] == 3 + WAX_BLOCKS[card_id],
				card_id + " adds to prior Block instead of resetting it at seat "
					+ str(monk_position))
			_check(party.get_hero(monk_position)["statuses"] == {"weak": 2},
				card_id + " leaves the Monk's status map untouched")


## AC2: two separate held copies add their exact printed Block, charge one energy each and
## discard one copy each, while every other hero record, draw pile, status map and RNG stay put.
func _test_wax_ward_two_copies() -> void:
	var party := _wax_party(2)
	_check(party.gain_block(2, 4) and party.gain_block(1, 6) and party.gain_block(3, 1),
		"two-copy fixture seeds independent Block on every hero")
	party._heroes[0]["statuses"] = {"bleed": 1}
	party._heroes[2]["statuses"] = {"exposed": 2}
	var deck := _wax_deck(["lantern_monk_wax_ward", "lantern_monk_wax_ward_plus",
		"wax_a", "wax_b", "wax_c"], 42,
		["lantern_monk_wax_ward", "lantern_monk_wax_ward_plus"])
	var rng_before: int = deck._rng.state
	var draw_before: Array = deck.draw_pile.duplicate()
	var warden_before := party.get_hero(1)
	var tinker_before := party.get_hero(3)

	_wax_accepted(deck, party, "lantern_monk_wax_ward", 2, "first of two held copies")
	_check(party.get_hero(2)["block"] == 9 and deck.energy == 2,
		"first copy grants 5 atop existing 4 Block and leaves two energy")
	_wax_accepted(deck, party, "lantern_monk_wax_ward_plus", 2, "second of two held copies")
	_check(party.get_hero(2)["block"] == 16 and deck.energy == 1,
		"second copy adds 7 for 16 total and leaves one energy")
	_check(deck.discard_pile.count("lantern_monk_wax_ward") == 1
		and deck.discard_pile.count("lantern_monk_wax_ward_plus") == 1
		and deck.discard_pile.size() == 2,
		"each held copy was discarded exactly once")
	_check(not deck.hand.has("lantern_monk_wax_ward")
		and not deck.hand.has("lantern_monk_wax_ward_plus"),
		"both played copies left the shared hand")
	_check(party.get_hero(1) == warden_before and party.get_hero(3) == tinker_before,
		"both plays leave the non-Monk hero records byte-identical")
	_check(party.get_hero(1)["statuses"] == {"bleed": 1}
		and party.get_hero(3)["statuses"] == {"exposed": 2},
		"both plays leave every status map exactly as it was")
	_check(deck._rng.state == rng_before and deck.draw_pile == draw_before,
		"both plays neither draw nor advance the seeded RNG")
	_wax_rejected(deck, party, "lantern_monk_wax_ward", 0,
		"a spent copy cannot be played a third time")


## Seeded shared-deck state, two plays and a real turn refill replay exactly.
func _wax_sequence(seed_value: int) -> Array:
	var party := _wax_party(2)
	var deck := _wax_deck(["lantern_monk_wax_ward", "lantern_monk_wax_ward_plus",
		"wax_a", "wax_b", "wax_c"], seed_value,
		["lantern_monk_wax_ward", "lantern_monk_wax_ward_plus"])
	var trace: Array = [_snapshot(deck, party)]
	_check(wax.play_card(deck, party, "lantern_monk_wax_ward", 0).get("ok", false),
		"Wax Ward replay base commits")
	trace.append(_snapshot(deck, party))
	_check(wax.play_card(deck, party, "lantern_monk_wax_ward_plus", 0).get("ok", false),
		"Wax Ward replay '+' commits")
	trace.append(_snapshot(deck, party))
	_wax_rejected(deck, party, "lantern_monk_wax_ward", 0, "Wax Ward replay consumed base")
	trace.append(_snapshot(deck, party))
	_check(deck.end_turn() and deck.start_turn(),
		"Wax Ward replay refills a real next shared turn")
	trace.append(_snapshot(deck, party))
	return trace


func _test_wax_ward_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var first := _wax_sequence(seed_value)
		var second := _wax_sequence(seed_value)
		_check(first.size() == 5 and second.size() == 5,
			"Wax Ward replay records five complete real snapshots")
		_check(first == second, "identical Wax Ward plays, party and seed replay exactly")


## AC3: every failed precondition refuses before any payment or mutation and leaves a valid
## retry possible.
func _test_wax_ward_rejections() -> void:
	var base := "lantern_monk_wax_ward"
	var plus := "lantern_monk_wax_ward_plus"

	_check(wax.is_supported_card(base) and wax.is_supported_card(plus),
		"both genuine Wax Ward printings are supported")
	for unsupported in ["warden_brace", "seamstress_mend", "lantern_monk_moth_shroud",
			"lantern_monk_wick_flicker", "lantern_monk_wax_ward_plus_plus", "", 7, null,
			StringName(base), {"id": base, "effects": {"block": 99}}]:
		_check(not wax.is_supported_card(unsupported),
			"unsupported ID is not reported as supported: " + str(unsupported))

	# Inactive shared turn while the genuine card and all three energy remain.
	var inactive := _wax_deck([base, "wax_a", "wax_b"], 42, [base])
	_check(inactive.combat_state.end_player_turn(), "inactive-turn fixture really ends the turn")
	inactive.combat_state.energy = CombatState.TURN_ENERGY
	_check(not inactive.turn_active and inactive.hand.has(base) and inactive.energy == 3,
		"inactive fixture still holds the real card and full energy")
	_wax_rejected(inactive, _wax_party(1), base, 0, "inactive shared turn")

	# Null services and an invalid party.
	var ready := _wax_deck([base], 42, [base])
	_check(not wax.play_card(null, _wax_party(1), base, 0).get("ok", true),
		"null deck rejects safely")
	_check(not wax.play_card(ready, null, base, 0).get("ok", true),
		"null party rejects safely")
	_wax_rejected(ready, CombatParty.new([]), base, 0, "invalid empty party")

	# The card exists but is not in the actual hand.
	var absent := _wax_deck([base, "wax_a", "wax_b"], 42, [base])
	_check(absent.discard_played(base) and not absent.hand.has(base)
		and absent.discard_pile.has(base), "absent fixture really moved the card into discard")
	_wax_rejected(absent, _wax_party(1), base, 0, "card absent from the actual hand")

	# Genuine but unsupported other-hero and other-Lantern-Monk-pool IDs, each really held.
	for other_id: String in ["warden_brace", "seamstress_mend", "tinker_tune_up",
			"lantern_monk_moth_shroud", "lantern_monk_wick_flicker", "lantern_monk_lantern_glow"]:
		var foreign := _wax_deck([other_id], 42, [other_id])
		_check(foreign.hand.has(other_id), "foreign-card fixture genuinely holds " + other_id)
		_wax_rejected(foreign, _wax_party(1), other_id, 0, "other hero/pool card " + other_id)

	# Unknown, malformed and forged identifiers while the real card is held.
	var held := _wax_deck([base], 42, [base])
	for bad_value in ["", "wax_ward", "lantern_monk_wax_ward_plus_plus", 7, 3.5, null,
			StringName(base), {"id": base, "cost": 1, "effects": {"block": 5}}]:
		_wax_rejected(held, _wax_party(1), bad_value, 0,
			"unsupported identifier " + str(bad_value))

	# Missing and duplicated Monk records in otherwise valid, funded parties.
	var no_monk := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(no_monk.is_valid(), "party without the Monk is otherwise valid")
	_wax_rejected(_wax_deck([base], 42, [base]), no_monk, base, 0,
		"no Lantern Monk in the party")
	var duplicate := _wax_party(2)
	duplicate._heroes[0]["id"] = "lantern_monk"
	_check(duplicate.is_valid() and duplicate.get_hero(1)["id"] == "lantern_monk"
		and duplicate.get_hero(2)["id"] == "lantern_monk",
		"duplicate-Monk fixture really holds two Monk records")
	_wax_rejected(_wax_deck([base], 42, [base]), duplicate, base, 0,
		"duplicate Lantern Monk records")

	# A torn (0 HP) Monk in each legal source seat.
	for monk_position in [1, 2, 3]:
		var downed := _wax_party(monk_position)
		_check(downed.apply_damage(monk_position, 999) and downed.is_downed(monk_position),
			"torn Monk fixture at " + str(monk_position))
		_wax_rejected(_wax_deck([base], 42, [base]), downed, base, 0,
			"torn Monk at " + str(monk_position))

	# Malformed roster records.
	var roster_edits := [
		["block", -1], ["hp", 999], ["max_hp", 0], ["position", 5],
		["statuses", "not a map"], ["statuses", {"weak": "2"}], ["statuses", {7: 1}],
	]
	for edit in roster_edits:
		var malformed := _wax_party(2)
		malformed._heroes[0][edit[0]] = edit[1]
		_wax_rejected(_wax_deck([base], 42, [base]), malformed, base, 0,
			"malformed roster record " + str(edit))

	# Seat 1-3 is never a target choice for a self card: every explicit target is refused.
	var targets := _wax_deck([base], 42, [base])
	for bad_target in [-1, 1, 2, 3, 4]:
		_wax_rejected(targets, _wax_party(2), base, bad_target,
			"explicit nonzero or invalid target " + str(bad_target))
	_wax_rejected(targets, _wax_party(2), base, 2,
		"the Monk's own seat is still not a target choice")

	# A refusal leaves the held copy retryable with the implicit self sentinel.
	var retry_party := _wax_party(3)
	var retry_deck := _wax_deck([base], 42, [base])
	_wax_rejected(retry_deck, retry_party, base, 3, "rejected target leaves the copy retryable")
	_wax_accepted(retry_deck, retry_party, base, 3, "valid retry after a target refusal")
	_check(retry_party.get_hero(3)["block"] == WAX_BLOCKS[base]
		and retry_deck.energy == 2,
		"retry grants the printed Block and spends one energy")

	# Block overflow refuses before charging; the exact capacity boundary is legal.
	var full := _wax_party(3)
	_check(full.gain_block(3, CombatParty.MAX_INT - WAX_BLOCKS[base] + 1),
		"overflow fixture leaves one point less room than the printed Block")
	_wax_rejected(_wax_deck([base], 42, [base]), full, base, 0,
		"Block overflow rejects before spending")
	var boundary := _wax_party(2)
	_check(boundary.gain_block(2, CombatParty.MAX_INT - WAX_BLOCKS[plus]),
		"capacity boundary fixture leaves exactly enough room")
	var boundary_deck := _wax_deck([plus], 42, [plus])
	_wax_accepted(boundary_deck, boundary, plus, 2, "exact capacity boundary play")
	_check(boundary.get_hero(2)["block"] == CombatParty.MAX_INT,
		"capacity boundary reaches MAX_INT with no overflow")

	# Insufficient shared energy.
	var poor := _wax_deck([base], 42, [base])
	_check(poor.try_spend_energy(3) and poor.energy == 0,
		"energy-shortage fixture really spent all three energy")
	_wax_rejected(poor, _wax_party(1), base, 0, "insufficient shared energy")

	# A rewritten or relinked catalog record is refused, never paid for.
	var forgeries: Array = [
		{"label": "changed Block", "id": base, "set": {"effects": {"block": 9}}},
		{"label": "extra effect", "id": base,
			"set": {"effects": {"block": 5, "blind_next_attack": true}}},
		{"label": "coercible Block", "id": base, "set": {"effects": {"block": "5"}}},
		{"label": "other owner", "id": base, "set": {"owner": "warden"}},
		{"label": "free cost", "id": base, "set": {"cost": 0}},
		{"label": "coercible cost", "id": base, "set": {"cost": "1"}},
		{"label": "wrong seats", "id": base, "set": {"from_positions": [2, 3]}},
		{"label": "ally target", "id": base, "set": {"target_kind": "ally_single"}},
		{"label": "withheld reward flag", "id": base, "set": {"reward_eligible": false}},
		{"label": "starting copy", "id": base, "set": {"starting_copies": 1}},
		{"label": "relinked upgrade", "id": base,
			"set": {"upgrade_id": "lantern_monk_moth_shroud"}},
		{"label": "missing upgrade link", "id": base, "erase": ["upgrade_id"]},
		{"label": "forged upgrade Block", "id": plus, "set": {"effects": {"block": 8}}},
		{"label": "missing back link", "id": plus, "erase": ["upgrade_of"]},
	]
	for forgery in forgeries:
		var card_id: String = forgery["id"]
		var forged := CombatLanternMonkWaxWardCards.new()
		forged._catalog = _forged_wax_catalog(card_id, forgery.get("set", {}),
			forgery.get("erase", []))
		var forged_deck := _wax_deck([card_id], 42, [card_id])
		var forged_party := _wax_party(1)
		var before := _snapshot(forged_deck, forged_party)
		_check(not forged.is_supported_card(card_id),
			"forged " + forgery["label"] + " is not supported")
		_check(forged.play_card(forged_deck, forged_party, card_id, 0).get("ok") == false,
			"forged " + forgery["label"] + " refuses")
		_check(_snapshot(forged_deck, forged_party) == before,
			"forged " + forgery["label"] + " changes no party, pile, energy or RNG state")

	# The genuine service and state still play after every refusal above.
	var recovered_deck := _wax_deck([base], 42, [base])
	var recovered_party := _wax_party(2)
	_wax_accepted(recovered_deck, recovered_party, base, 2,
		"genuine service recovers after forged-catalog refusals")


## A catalog double that keeps both genuine records but rewrites one of them.
func _forged_wax_catalog(target_id: String, changes: Dictionary,
		erased: Array) -> ForgedWaxCatalog:
	var pool := LanternMonkPoolCards.new()
	var definitions := {}
	for card_id: String in WAX_BLOCKS:
		definitions[card_id] = pool.get_definition(card_id)
	var record: Dictionary = definitions[target_id]
	for key in changes:
		record[key] = changes[key]
	for key in erased:
		record.erase(key)
	definitions[target_id] = record
	return ForgedWaxCatalog.new(definitions)
