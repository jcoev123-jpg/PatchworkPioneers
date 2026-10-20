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