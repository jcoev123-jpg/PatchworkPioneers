class_name CombatAttackTargeting
extends RefCounted
## Read-only legal-enemy preview for the five authored starter attacks.
## The eventual play resolver must independently validate its committed target.

const ATTACK_IDS := [
	"warden_strike_plus",
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]


func get_preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String) -> Dictionary:
	var target_positions: Array[int] = []
	var rejected := {
		"playable": false,
		"requires_selection": false,
		"target_positions": target_positions
	}
	if deck == null or party == null or enemies == null:
		return rejected
	if not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return rejected
	if not ATTACK_IDS.has(card_id) or not deck.hand.has(card_id):
		return rejected

	# Consult the authored catalog for all card rules, not a parallel rules table.
	var definition := StarterCards.new().get_definition(card_id)
	if definition.is_empty():
		return rejected
	var owner = definition.get("owner")
	var cost = definition.get("cost")
	var from_positions = definition.get("from_positions")
	var to_positions = definition.get("to_positions")
	var target_kind = definition.get("target_kind")
	if not owner is String or owner.is_empty():
		return rejected
	if not cost is int or cost < 0 or deck.energy < cost:
		return rejected
	if not from_positions is Array or from_positions.is_empty():
		return rejected
	if not to_positions is Array or to_positions.is_empty():
		return rejected
	if target_kind != "enemy_single" and target_kind != "enemy_all":
		return rejected
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return rejected
	for position in to_positions:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return rejected

	# Positions come from the actual (possibly reordered) roster; missing or
	# ambiguous owners fail closed. Downed heroes remain in their slots.
	var owner_position := 0
	var owner_count := 0
	for hero in party.get_heroes():
		if hero.get("id") == owner:
			owner_count += 1
			owner_position = hero.get("position", 0)
	if owner_count != 1 or owner_position == 0:
		return rejected
	if party.is_downed(owner_position) or not from_positions.has(owner_position):
		return rejected

	# Scan slots in position order, never compacting slain or absent enemies.
	# For enemy_all these are affected slots, not selectable target choices.
	for position in range(1, CombatEnemies.MAX_ENEMIES + 1):
		if not to_positions.has(position):
			continue
		if enemies.get_enemy(position).is_empty() or enemies.is_slain(position):
			continue
		target_positions.append(position)
	if target_positions.is_empty():
		return rejected
	return {
		"playable": true,
		"requires_selection": target_kind == "enemy_single",
		"target_positions": target_positions
	}
