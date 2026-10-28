class_name CombatDeck
extends RefCounted
## Shared combat deck. The next card is at the end of draw_pile.
## The caller owns and seeds the run RNG; this class never reseeds it.

const TURN_DRAW := 5

var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
## Cards exhausted for this battle only (Frayed Debt on its first draw). The run deck still owns them.
var exhausted: Array[String] = []
var combat_state := CombatState.new()
var turn_active: bool:
	get:
		return combat_state.player_turn_active
var energy: int:
	get:
		return combat_state.energy
var _rng: RandomNumberGenerator


func _init(card_ids: Array[String], rng: RandomNumberGenerator) -> void:
	_rng = rng
	draw_pile.assign(card_ids)
	_shuffle_draw_pile()


## False means a turn was already active. No state changes on rejection.
func start_turn() -> bool:
	if not combat_state.start_player_turn():
		return false
	_draw(TURN_DRAW)
	return true


## Returns cards actually added to the hand, or -1 for an inactive turn or a negative count.
func draw_extra(count: int) -> int:
	if not turn_active or count < 0:
		return -1
	return _draw(count)


## Moves only the first matching copy from hand to discard.
func discard_played(card_id: String) -> bool:
	if not turn_active:
		return false
	var index := hand.find(card_id)
	if index < 0:
		return false
	discard_pile.append(hand[index])
	hand.remove_at(index)
	return true


func end_turn() -> bool:
	if not combat_state.end_player_turn():
		return false
	discard_pile.append_array(hand)
	hand.clear()
	return true


func try_spend_energy(cost: int) -> bool:
	return combat_state.try_spend_energy(cost)


## Each requested slot pops at most one card. A Frayed Debt pop uses its slot and
## exhausts: it leaves this battle's circulation and the slot is not retried.
func _draw(count: int) -> int:
	var drawn := 0
	for slot in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			_shuffle_draw_pile()
		var card: String = draw_pile.pop_back()
		if card == MpwFrayedDebt.CARD_ID:
			exhausted.append(card)
			continue
		hand.append(card)
		drawn += 1
	return drawn


func _shuffle_draw_pile() -> void:
	# Fisher-Yates uses only the injected generator, including on refills.
	for index in range(draw_pile.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var card := draw_pile[index]
		draw_pile[index] = draw_pile[other]
		draw_pile[other] = card
