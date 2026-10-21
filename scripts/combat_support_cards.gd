class_name CombatSupportCards
extends RefCounted
## Resolves caller-supplied support definitions against the authoritative shared
## CombatDeck and CombatParty. Does not own card definitions or duplicate state.


func play_support(deck: CombatDeck, party: CombatParty, definition: Dictionary, target_position: int = 0) -> bool:
	return _play_support(deck, party, definition, target_position, true)


## Only for a detached transaction: all ordinary validation/effects, but the
## enclosing composite owns its single charge/discard after both halves resolve.
func resolve_staged_half(deck: CombatDeck, party: CombatParty,
		definition: Dictionary, target_position: int = 0) -> bool:
	return _play_support(deck, party, definition, target_position, false)


func _play_support(deck: CombatDeck, party: CombatParty, definition: Dictionary,
		target_position: int, consume_card: bool) -> bool:
	if deck == null or party == null or not deck.turn_active or not party.is_valid():
		return false

	var card_id = definition.get("id")
	var owner_id = definition.get("owner_id")
	var cost = definition.get("cost")
	var from_positions = definition.get("from_positions")
	var effect = definition.get("effect")
	var amount = definition.get("amount")
	if not card_id is String or card_id.is_empty():
		return false
	if not owner_id is String or owner_id.is_empty():
		return false
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY:
		return false
	if not from_positions is Array or from_positions.is_empty():
		return false
	if not effect is String or not effect in ["self_block", "ally_block", "ally_heal", "draw"]:
		return false
	if not amount is int or amount < 0:
		return false
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return false

	# No mutation, including RNG movement, occurs before every precondition
	# has been checked. Hand membership is by ID, not just card definition.
	if not deck.hand.has(card_id) or deck.energy < cost:
		return false
	var owner_position := 0
	for hero in party.get_heroes():
		if hero["id"] == owner_id:
			owner_position = hero["position"]
			break
	if owner_position == 0 or not from_positions.has(owner_position) or party.is_downed(owner_position):
		return false

	var recipient := owner_position
	match effect:
		"self_block", "draw":
			if target_position != 0:
				return false
		"ally_block", "ally_heal":
			if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
				return false
			if party.is_downed(target_position):
				return false
			recipient = target_position

	if effect == "self_block" or effect == "ally_block":
		var current_block: int = party.get_hero(recipient)["block"]
		if amount > CombatParty.MAX_INT - current_block:
			return false

	# After prevalidation all following operations are guaranteed by the
	# existing deck/party APIs to succeed; charge exactly once.
	if consume_card and not deck.try_spend_energy(cost):
		return false
	match effect:
		"self_block", "ally_block":
			party.gain_block(recipient, amount)
		"ally_heal":
			party.heal(recipient, amount)
		"draw":
			# This card is still in hand, hence cannot enter the reshuffle
			# during its own draw (important for zero-cost self-draw cards).
			deck.draw_extra(amount)
	if consume_card:
		deck.discard_played(card_id)
	return true
