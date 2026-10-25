class_name CombatPositionSwaps
extends RefCounted

## Proposes an adjacent hero swap without mutating the authoritative CombatParty.
## Returns a dictionary with "ok" (bool) and "heroes" (Array[Dictionary] deep copies).
## On success, heroes are ordered by final position 1..3 with position fields updated.
## On failure, returns {"ok": false, "heroes": []} and leaves party unchanged.
static func preview_adjacent_swap(party: CombatParty, mover_position: int, direction: int) -> Dictionary:
	# Validate party
	if party == null or not party.is_valid():
		return {"ok": false, "heroes": []}
	
	# Validate mover position
	if mover_position < 1 or mover_position > 3:
		return {"ok": false, "heroes": []}
	
	# Validate direction
	if direction != -1 and direction != 1:
		return {"ok": false, "heroes": []}
	
	var destination := mover_position + direction
	
	# Validate destination position
	if destination < 1 or destination > 3:
		return {"ok": false, "heroes": []}
	
	# Check if either hero is downed
	if party.is_downed(mover_position) or party.is_downed(destination):
		return {"ok": false, "heroes": []}
	
	# Get deep copy of heroes
	var heroes_copy := party.get_heroes()
	
	# Swap the two heroes in the copy
	var mover_index := mover_position - 1
	var dest_index := destination - 1
	var temp := heroes_copy[mover_index]
	heroes_copy[mover_index] = heroes_copy[dest_index]
	heroes_copy[dest_index] = temp
	
	# Update position fields to match final indices (1-based)
	for i in range(heroes_copy.size()):
		heroes_copy[i]["position"] = i + 1
	
	return {"ok": true, "heroes": heroes_copy}

## Consume one legitimately held caller-defined movement card and exchange the
## authoritative actor dictionaries. Every check runs before the first write.
## In particular a preview is only a detached proposal, never committed state.
static func play_move_card(deck: CombatDeck, party: CombatParty, card_id: Variant, definition: Variant) -> bool:
	if deck == null or party == null or not party.is_valid():
		return false
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return false
	if not card_id is String or card_id.is_empty() or not definition is Dictionary:
		return false
	if not deck.hand.has(card_id):
		return false

	var defined_id = definition.get("id")
	var owner = definition.get("owner")
	var cost = definition.get("cost")
	var from_positions = definition.get("from_positions")
	var direction = definition.get("direction")
	if not defined_id is String or defined_id.is_empty() or defined_id != card_id:
		return false
	if not owner is String or owner.is_empty():
		return false
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY or cost > deck.energy:
		return false
	if not from_positions is Array or from_positions.is_empty():
		return false
	if definition.get("action_kind") != "adjacent_swap":
		return false
	if not direction is int or (direction != -1 and direction != 1):
		return false
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return false

	# is_valid() only checks the array size; externally corrupted rosters
	# must not permit half a transaction. Do not replace actor dictionaries.
	var owner_position := 0
	var ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		var hero_id = hero.get("id")
		var hero_position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		if not hero_id is String or hero_id.is_empty() or ids.has(hero_id):
			return false
		if not hero_position is int or hero_position != index + 1:
			return false
		if not hp is int or not max_hp is int or max_hp <= 0 or hp < 0 or hp > max_hp:
			return false
		ids.append(hero_id)
		if hero_id == owner:
			owner_position = index + 1
	if owner_position == 0 or not from_positions.has(owner_position):
		return false

	# The existing preview owns adjacent, on-board and living-neighbor
	# legality. Its deep copies are discarded; the originals stay in place.
	if not preview_adjacent_swap(party, owner_position, direction)["ok"]:
		return false

	# V3-2 Tangled: a hero afflicted by its own side cannot move itself or be
	# moved by its team, so both participants of this allied swap are inspected
	# before any charge, discard or roster edit. Only this hero-owned paid
	# transaction is gated: the generic preview (and so an enemy shove, which is
	# not movement "by its own side") keeps its old behavior.
	if _tangled_blocks(party._heroes[owner_position - 1]) \
			or _tangled_blocks(party._heroes[owner_position + direction - 1]):
		return false

	# The two deck operations cannot fail after the complete preflight above:
	# the turn is active, energy is sufficient and the held ID exists.
	if not deck.try_spend_energy(cost):
		return false
	deck.discard_played(card_id)
	var destination_index: int = owner_position + direction - 1
	var mover_index: int = owner_position - 1
	var mover: Dictionary = party._heroes[mover_index]
	var neighbor: Dictionary = party._heroes[destination_index]
	party._heroes[mover_index] = neighbor
	party._heroes[destination_index] = mover
	mover["position"] = destination_index + 1
	neighbor["position"] = mover_index + 1
	return true

## V3-2 Tangled N: a positive integer count blocks this allied move for the actor
## whether it is the mover or the one being moved. Absent statuses or an absent
## key mean no active Tangled, and zero means expired. Any other stored value is
## malformed and rejects the play instead of being coerced into a legal stack.
static func _tangled_blocks(actor: Dictionary) -> bool:
	var statuses = actor.get("statuses")
	if statuses == null:
		return false
	if not statuses is Dictionary:
		return true
	if not statuses.has("tangled"):
		return false
	var count = statuses["tangled"]
	if not count is int:
		return true
	return count != 0

