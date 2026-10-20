class_name CombatState
extends RefCounted
## Shared energy budget for one player turn, independent of scenes and cards.

const TURN_ENERGY := 3

var energy: int = 0
var player_turn_active: bool = false


func start_player_turn() -> bool:
	if player_turn_active:
		return false
	player_turn_active = true
	energy = TURN_ENERGY
	return true


func try_spend_energy(cost: int) -> bool:
	if not player_turn_active or cost < 0 or cost > energy:
		return false
	energy -= cost
	return true


func end_player_turn() -> bool:
	if not player_turn_active:
		return false
	player_turn_active = false
	energy = 0
	return true
