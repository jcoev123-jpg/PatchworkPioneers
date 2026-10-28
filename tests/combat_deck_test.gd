extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_exact_piles()
	_test_boundaries()
	_test_energy()
	_test_replay()
	_test_frayed_debt()
	if failures.is_empty():
		print("combat_deck_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_deck_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _snapshot(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.turn_active, deck.energy,
		deck.combat_state.player_turn_active, deck.combat_state.energy, deck._rng.state,
		deck.exhausted.duplicate()]


func _reject(deck: CombatDeck, operation: Callable, message: String) -> void:
	var before := _snapshot(deck)
	_check(not operation.call(), message + " returns false")
	_check(_snapshot(deck) == before, message + " preserves full state and RNG")


func _test_energy() -> void:
	var cards: Array[String] = ["a", "a", "b", "c", "d", "e", "f"]
	var deck := CombatDeck.new(cards, _rng(123))
	var other := CombatDeck.new(cards, _rng(123))
	_check(deck.combat_state is CombatState and deck.combat_state != other.combat_state,
		"each deck owns its own CombatState")
	_check(deck.energy == 0 and not deck.turn_active, "initial energy zero and inactive")
	for cost in [-1, 0, 1, 3, 4]:
		_reject(deck, deck.try_spend_energy.bind(cost), "inactive spending %d" % cost)
	_reject(deck, deck.end_turn, "initial end")
	for cost in [0, 1, 2, 3]:
		_check(deck.start_turn(), "energy turn starts")
		_check(deck.energy == 3 and deck.turn_active, "start grants exactly three")
		_reject(deck, deck.start_turn, "duplicate full start")
		_reject(deck, deck.try_spend_energy.bind(-1), "negative active spending")
		_reject(deck, deck.try_spend_energy.bind(4), "unaffordable active spending")
		var before := _snapshot(deck)
		_check(deck.try_spend_energy(cost), "affordable spending succeeds")
		# Only the two energy readers in the full snapshot may change.
		before[4] = 3 - cost
		before[6] = 3 - cost
		_check(_snapshot(deck) == before, "spending changes only authoritative energy")
		_reject(deck, deck.start_turn, "duplicate start cannot refill")
		_reject(deck, deck.try_spend_energy.bind(4 - cost), "overspend remaining energy")
		_check(deck.try_spend_energy(3 - cost) and deck.energy == 0 and deck.turn_active,
			"exact spending exhausts energy without ending turn")
		_reject(deck, deck.try_spend_energy.bind(1), "exhausted spending")
		_reject(deck, deck.try_spend_energy.bind(-1), "exhausted negative spending")
		_reject(deck, deck.start_turn, "exhausted duplicate start")
		before = _snapshot(deck)
		_check(deck.try_spend_energy(0) and _snapshot(deck) == before,
			"zero cost at exhaustion preserves full state and RNG")
		_check(deck.end_turn() and deck.energy == 0 and not deck.turn_active,
			"end deactivates and clears energy")
		_reject(deck, deck.end_turn, "duplicate end")
		_reject(deck, deck.try_spend_energy.bind(0), "spending after end")
		_conserved(deck, cards)
	_check(deck.start_turn() and deck.try_spend_energy(1) and deck.energy == 2,
		"partly spent next turn")
	_check(deck.end_turn() and deck.energy == 0 and not deck.turn_active,
		"end clears unspent energy")
	_check(other.energy == 0 and not other.turn_active, "other deck state stays independent")


func _conserved(deck: CombatDeck, original: Array[String]) -> void:
	var cards: Array[String] = []
	cards.append_array(deck.draw_pile)
	cards.append_array(deck.hand)
	cards.append_array(deck.discard_pile)
	cards.append_array(deck.exhausted)
	cards.sort()
	var expected := original.duplicate()
	expected.sort()
	_check(cards == expected, "all card copies must be conserved")


func _test_exact_piles() -> void:
	var cards: Array[String] = ["a", "b", "c", "d", "e", "f", "g"]
	var rng := _rng(42)
	var deck := CombatDeck.new(cards, rng)
	var initial := deck.draw_pile.duplicate()
	_check(initial.size() == cards.size(), "initial deck contains every copy")
	_check(initial != cards, "seed 42 shuffles the initial order")
	_check(deck.hand.is_empty() and deck.discard_pile.is_empty(), "initial hand/discard empty")
	cards[0] = "changed input"
	_check(deck.draw_pile == initial, "constructor copies caller's array")
	cards[0] = "a"
	_check(deck.start_turn(), "first turn starts")
	var expected_hand: Array[String] = []
	var remaining := initial.duplicate()
	for index in range(5):
		expected_hand.append(remaining.pop_back())
	_check(deck.hand == expected_hand and deck.draw_pile == remaining,
		"start draws exactly five in pile order")
	_check(deck.discard_pile.is_empty(), "start does not discard cards")
	_conserved(deck, cards)
	var played: String = expected_hand.pop_at(1)
	_check(deck.discard_played(played), "play a held card")
	_check(deck.hand == expected_hand and deck.discard_pile == [played], "play moves exact card")
	_check(deck.draw_pile == remaining, "play preserves draw pile")
	_conserved(deck, cards)
	_check(deck.draw_extra(1) == 1, "extra draw returns number drawn")
	expected_hand.append(remaining.pop_back())
	_check(deck.hand == expected_hand and deck.draw_pile == remaining, "extra draw exact piles")
	var rng_before := rng.state
	_check(deck.draw_extra(1) == 1, "last draw before refill")
	expected_hand.append(remaining.pop_back())
	_check(rng.state == rng_before and deck.discard_pile == [played],
		"exhausting draw without further demand does not refill")
	_check(deck.draw_extra(3) == 1, "mid-draw refill stops after available cards")
	expected_hand.append(played)
	_check(deck.hand == expected_hand and deck.draw_pile.is_empty()
		and deck.discard_pile.is_empty(), "refill uses only discarded cards")
	_conserved(deck, cards)
	_check(deck.end_turn(), "turn ends")
	_check(deck.hand.is_empty() and deck.discard_pile == expected_hand
		and not deck.turn_active, "end discards all remaining cards in order")
	_conserved(deck, cards)
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.draw_pile.size() == 2
		and deck.discard_pile.is_empty(), "next turn refills from ended turn")
	_conserved(deck, cards)


func _test_boundaries() -> void:
	var cards: Array[String] = ["copy", "copy", "other"]
	var rng := _rng(91)
	var deck := CombatDeck.new(cards, rng)
	var before := _snapshot(deck)
	var rng_before := rng.state
	_check(not deck.end_turn(), "cannot end inactive turn")
	_check(not deck.discard_played("copy"), "cannot discard outside turn")
	_check(deck.draw_extra(2) == -1, "cannot draw outside turn")
	_check(_snapshot(deck) == before and rng.state == rng_before, "inactive rejections are atomic")
	_check(deck.start_turn() and deck.hand.size() == 3, "short deck draws up to five")
	before = _snapshot(deck)
	rng_before = rng.state
	_check(not deck.start_turn(), "double start rejected")
	_check(not deck.discard_played("missing"), "missing card rejected")
	_check(deck.draw_extra(-1) == -1, "negative draw rejected")
	_check(deck.draw_extra(0) == 0, "zero draw does nothing")
	_check(deck.draw_extra(100) == 0, "empty piles terminate despite nonempty hand")
	_check(_snapshot(deck) == before and rng.state == rng_before, "invalid/empty draws preserve state and RNG")
	var expected := deck.hand.duplicate()
	expected.remove_at(expected.find("copy"))
	_check(deck.discard_played("copy"), "duplicate play succeeds")
	_check(deck.hand == expected and deck.hand.count("copy") == 1
		and deck.discard_pile == ["copy"], "only one matching copy moves")
	_conserved(deck, cards)
	_check(deck.discard_played("copy"), "second copy can be played")
	before = _snapshot(deck)
	_check(not deck.discard_played("copy") and _snapshot(deck) == before, "third copy rejected without mutation")
	_check(deck.end_turn(), "duplicate deck ends")
	before = _snapshot(deck)
	_check(not deck.end_turn() and _snapshot(deck) == before, "double end preserves piles")
	_conserved(deck, cards)
	var empty := CombatDeck.new([], _rng(0))
	_check(empty.start_turn(), "empty deck turn is valid")
	_check(empty.draw_extra(1000) == 0 and empty.hand.is_empty(), "empty deck draw terminates")
	_check(empty.end_turn(), "empty deck turn ends")
	_conserved(empty, [])


func _test_replay() -> void:
	var cards: Array[String] = ["a", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k"]
	for seed_value in [0, 42, 987654]:
		var rng_a := _rng(seed_value)
		var rng_b := _rng(seed_value)
		var a := CombatDeck.new(cards, rng_a)
		var b := CombatDeck.new(cards, rng_b)
		_check(_snapshot(a) == _snapshot(b) and rng_a.state == rng_b.state, "initial shuffle replay")
		for turn in range(12):
			_check(a.start_turn() and b.start_turn(), "replay turns start")
			_check(a.hand.size() == 5, "replay starts with a real five-card hand")
			_check(_snapshot(a) == _snapshot(b), "initial draw replay")
			for play in range(2):
				var card := a.hand[0]
				_check(a.discard_played(card) and b.discard_played(card), "replay plays real held cards")
				_check(_snapshot(a) == _snapshot(b), "played discard replay")
				_conserved(a, cards)
			# At least one draw crosses from old draw pile into shuffled discards.
			var available_draw := a.draw_pile.duplicate()
			var discards := a.discard_pile.duplicate()
			var oracle := _rng(0)
			oracle.state = rng_a.state
			for index in range(discards.size() - 1, 0, -1):
				var other := oracle.randi_range(0, index)
				var saved: String = discards[index]
				discards[index] = discards[other]
				discards[other] = saved
			var expected := a.hand.duplicate()
			while not available_draw.is_empty():
				expected.append(available_draw.pop_back())
			while not discards.is_empty():
				expected.append(discards.pop_back())
			var count := 30
			var drawn_a := a.draw_extra(count)
			_check(drawn_a == b.draw_extra(count) and drawn_a == 9, "refill draw counts replay")
			_check(a.hand == expected and a.draw_pile.is_empty() and a.discard_pile.is_empty(),
				"mid-draw preserves existing order then uses seeded shuffled discard")
			_check(_snapshot(a) == _snapshot(b) and rng_a.state == rng_b.state, "complete refill replay")
			_conserved(a, cards)
			_conserved(b, cards)
			_check(a.end_turn() and b.end_turn(), "replay turns end")
			_check(_snapshot(a) == _snapshot(b), "end discard replay")
			_conserved(a, cards)


const CURSE := MpwFrayedDebt.CARD_ID


func _circulating(deck: CombatDeck) -> Array[String]:
	var cards: Array[String] = []
	cards.append_array(deck.draw_pile)
	cards.append_array(deck.hand)
	cards.append_array(deck.discard_pile)
	return cards


## A deck whose draw pile is set to an exact order (top card last) after construction.
func _fixed(order: Array[String], seed_value: int = 7) -> CombatDeck:
	var deck := CombatDeck.new([], _rng(seed_value))
	deck.draw_pile.assign(order)
	return deck


## Independent oracle for `slots` draw slots: pops from a copy of the piles, refilling from the
## discard with the same Fisher-Yates on a cloned RNG; a Frayed Debt pop uses its slot and is dropped.
func _draw_oracle(deck: CombatDeck, slots: int) -> Dictionary:
	var draw: Array[String] = deck.draw_pile.duplicate()
	var hand: Array[String] = deck.hand.duplicate()
	var discard: Array[String] = deck.discard_pile.duplicate()
	var exhausted: Array[String] = deck.exhausted.duplicate()
	var rng := _rng(0)
	rng.state = deck._rng.state
	var added := 0
	for slot in range(slots):
		if draw.is_empty():
			if discard.is_empty():
				break
			draw.append_array(discard)
			discard.clear()
			for index in range(draw.size() - 1, 0, -1):
				var other := rng.randi_range(0, index)
				var saved: String = draw[index]
				draw[index] = draw[other]
				draw[other] = saved
		var card: String = draw.pop_back()
		if card == CURSE:
			exhausted.append(card)
		else:
			hand.append(card)
			added += 1
	return {"draw": draw, "hand": hand, "discard": discard, "exhausted": exhausted,
		"rng": rng.state, "added": added}


func _matches(deck: CombatDeck, oracle: Dictionary) -> bool:
	return deck.draw_pile == oracle.draw and deck.hand == oracle.hand and deck.discard_pile == oracle.discard \
		and deck.exhausted == oracle.exhausted and deck._rng.state == oracle.rng


func _test_frayed_debt() -> void:
	_check(CURSE == "frayed_debt" and MpwFrayedDebt.new().get_definition(CURSE).exhaust_on_first_draw
		and MpwFrayedDebt.new().get_definition(CURSE).consumes_draw, "canonical curse carries the exhaust contract")
	# Drawn immediately: five slots, the curse uses one, four normal cards reach the hand.
	var deck := _fixed(["a", "b", "c", "d", "e", "f", CURSE])
	var rng_before: int = deck._rng.state
	_check(deck.start_turn(), "turn with curse on top starts")
	_check(deck.hand == ["f", "e", "d", "c"] and deck.draw_pile == ["a", "b"] and deck.discard_pile.is_empty()
		and deck.exhausted == [CURSE], "five requested slots yield four normal cards and exhaust the curse")
	_check(deck._rng.state == rng_before, "the consumed slot is not retried and draws no RNG")
	_reject(deck, deck.start_turn, "repeated turn entry after exhaust")
	_check(deck.draw_extra(-1) == -1 and deck.hand.size() == 4 and deck.exhausted == [CURSE], "negative extra draw refused")
	_check(deck.end_turn() and deck.discard_pile == ["f", "e", "d", "c"] and not deck.discard_pile.has(CURSE),
		"end of turn never discards an exhausted curse")
	var before := _snapshot(deck)
	_check(deck.draw_extra(1) == -1 and _snapshot(deck) == before, "inactive extra draw refused without mutation")
	for turn in range(6):
		_check(deck.start_turn() and not deck.hand.has(CURSE), "exhausted curse is never drawn again this fight")
		_check(not _circulating(deck).has(CURSE) and deck.exhausted == [CURSE], "curse stays out of circulation")
		_check(deck.end_turn(), "replay turn ends")
	# Later via extra draw: the curse consumes one of n slots and draw_extra reports cards received.
	deck = _fixed(["a", "b", CURSE, "c", "d", "e", "f", "g"])
	_check(deck.start_turn() and deck.hand == ["g", "f", "e", "d", "c"] and deck.exhausted.is_empty(),
		"ordinary start draws five normal cards")
	_check(deck.draw_extra(2) == 1 and deck.hand.back() == "b" and deck.draw_pile == ["a"]
		and deck.exhausted == [CURSE], "extra draw of two meets the curse: one slot spent, one card received")
	_check(deck.draw_extra(1) == 1 and deck.hand.back() == "a" and deck.draw_pile.is_empty(), "next extra draw is normal")
	_check(deck.draw_extra(3) == 0 and deck.exhausted == [CURSE], "empty piles terminate with no replay")
	# Two copies: each consumes its own slot; the hand is short, never refilled for them.
	deck = _fixed([CURSE, "a", CURSE, "b"])
	_check(deck.start_turn() and deck.hand == ["b", "a"] and deck.draw_pile.is_empty()
		and deck.exhausted == [CURSE, CURSE], "both copies exhaust on their first draws")
	_check(deck.draw_extra(5) == 0 and deck.end_turn() and deck.start_turn() and deck.hand.size() == 2
		and not deck.hand.has(CURSE) and deck.exhausted == [CURSE, CURSE],
		"no copy returns after the discard refill")
	# A curse met across a seeded discard refill, against the independent oracle.
	for seed_value in [0, 42, 358, 987654]:
		deck = CombatDeck.new([], _rng(seed_value))
		_check(deck.start_turn(), "refill witness turn starts")
		deck.draw_pile.assign(["p", "q"])
		deck.discard_pile.assign(["a", CURSE, "b", "c", CURSE, "d"])
		var partial := _draw_oracle(deck, 4)
		var oracle := _draw_oracle(deck, 8)
		var added := deck.draw_extra(8)
		_check(added == oracle.added and added == 6 and _matches(deck, oracle) and partial.added + partial.exhausted.size() == 4,
			"seed %d: refill shuffle path is unchanged and both curses use slots" % seed_value)
		_check(deck.exhausted == [CURSE, CURSE] and not _circulating(deck).has(CURSE), "seed %d: curses exhausted" % seed_value)
		before = _snapshot(deck)
		_check(deck.draw_extra(-2) == -1 and _snapshot(deck) == before, "seed %d: refused draw keeps RNG" % seed_value)
	# Seeded replay from one run ledger: same seed, same piles, same exhaust; a fresh fight exhausts again.
	var ledger: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h", CURSE, "i", "j", "k"]
	var ledger_before := ledger.duplicate()
	for seed_value in [1, 77, 4242]:
		var a := CombatDeck.new(ledger, _rng(seed_value))
		var b := CombatDeck.new(ledger, _rng(seed_value))
		for turn in range(5):
			var oracle := _draw_oracle(a, CombatDeck.TURN_DRAW)
			_check(a.start_turn() and b.start_turn(), "seeded curse turns start")
			_check(_matches(a, oracle) and _snapshot(a) == _snapshot(b), "seed %d turn %d: start_turn oracle and replay" % [seed_value, turn])
			_check(not a.hand.has(CURSE), "curse never reaches the hand")
			_conserved(a, ledger)
			if not a.hand.is_empty():
				var card := a.hand[0]
				_check(a.discard_played(card) and b.discard_played(card), "replay plays a real card")
			oracle = _draw_oracle(a, 2)
			var received := a.draw_extra(2)
			_check(received == oracle.added and received == b.draw_extra(2) and _matches(a, oracle)
				and _snapshot(a) == _snapshot(b), "seed %d turn %d: draw_extra oracle and replay" % [seed_value, turn])
			_check(a.end_turn() and b.end_turn(), "seeded curse turns end")
		_check(a.exhausted == [CURSE] and not _circulating(a).has(CURSE), "seed %d: curse met once, exhausted once" % seed_value)
		_check(ledger == ledger_before, "the battle never edits the run ledger")
		var fresh := CombatDeck.new(ledger, _rng(seed_value))
		_check(fresh.exhausted.is_empty() and fresh.draw_pile.count(CURSE) == 1, "a fresh fight starts with the curse again")
		_check(_snapshot(fresh) == _snapshot(CombatDeck.new(ledger, _rng(seed_value))), "fresh fight replays")
	# An ordinary deck without the curse never exhausts anything.
	var plain := CombatDeck.new(["a", "b", "c", "d", "e", "f", "g"], _rng(42))
	var plain_oracle := _draw_oracle(plain, CombatDeck.TURN_DRAW)
	_check(plain.start_turn() and _matches(plain, plain_oracle) and plain.hand.size() == 5 and plain.exhausted.is_empty(),
		"no-curse draw is unchanged")
