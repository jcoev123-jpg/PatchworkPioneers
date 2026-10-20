extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_exact_piles()
	_test_boundaries()
	_test_replay()
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
		deck.discard_pile.duplicate(), deck.turn_active]


func _conserved(deck: CombatDeck, original: Array[String]) -> void:
	var cards: Array[String] = []
	cards.append_array(deck.draw_pile)
	cards.append_array(deck.hand)
	cards.append_array(deck.discard_pile)
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
