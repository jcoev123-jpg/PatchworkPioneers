class_name CombatAreaAttacks
extends RefCounted
## Resolves the authored, target-free Scrap Bomb against the real shared combat state.
## Live hand/UI routing is intentionally handled by a separate battle integration.

const SCRAP_BOMB_ID := "tinker_scrap_bomb"


func play_scrap_bomb(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> bool:
	# Finish all validation before spending, discarding, or damaging any target.
	if deck == null or party == null or enemies == null:
		return false
	if not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return false
	if enemies.is_victorious() or not deck.hand.has(SCRAP_BOMB_ID):
		return false

	var definition := StarterCards.new().get_definition(SCRAP_BOMB_ID)
	var cost_value: Variant = definition.get("cost")
	var effects_value: Variant = definition.get("effects")
	var from_value: Variant = definition.get("from_positions")
	var to_value: Variant = definition.get("to_positions")
	if definition.get("id") != SCRAP_BOMB_ID or definition.get("owner") != "tinker":
		return false
	if definition.get("target_kind") != "enemy_all":
		return false
	if not cost_value is int or not effects_value is Dictionary:
		return false
	if not from_value is Array or not to_value is Array:
		return false
	var damage_value: Variant = effects_value.get("damage")
	if not damage_value is int or damage_value <= 0 or cost_value < 0:
		return false
	var cost: int = cost_value
	var damage: int = damage_value
	var from_positions: Array = from_value
	var to_positions: Array = to_value
	if deck.energy < cost:
		return false

	var owner_found := false
	for hero in party.get_heroes():
		if hero.get("id") != definition["owner"]:
			continue
		# A matching owner elsewhere does not make an invalid duplicate playable.
		if owner_found:
			return false
		owner_found = true
		var position: int = hero.get("position", 0)
		if not from_positions.has(position) or party.is_downed(position):
			return false
	if not owner_found:
		return false

	# Position order is the roster's 1-based slot order, including slain slots.
	var targets: Array[int] = []
	var roster := enemies.get_enemies()
	for index in range(roster.size()):
		var position := index + 1
		var enemy: Dictionary = roster[index]
		if enemy.get("position") != position:
			return false
		if enemies.is_dead(position):
			continue
		if not to_positions.has(position):
			return false
		targets.append(position)
	if targets.is_empty():
		return false

	# All calls below are guaranteed to succeed by the checked real state.
	if not deck.try_spend_energy(cost):
		return false
	for position in targets:
		enemies.apply_damage(position, damage)
	deck.discard_played(SCRAP_BOMB_ID)
	return true
