class_name CombatBasicAttacks
extends RefCounted
## Resolves the two authored basic attack cards (Strike and Pop Shot) against the
## real shared CombatDeck, CombatParty and CombatEnemies state. No RNG usage.


const SUPPORTED_CARD_IDS := ["warden_strike", "warden_strike_plus", "tinker_pop_shot"]


func play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		target_position: int, final_damage: Variant = null) -> bool:
	# null preserves the original authored-damage, five-argument contract.
	# Keep this a Variant so malformed overrides fail closed rather than coerce.
	if final_damage != null and (not final_damage is int or final_damage < 0
			or final_damage > CombatStatuses.MAX_INT):
		return false
	if deck == null or party == null or enemies == null:
		return false
	if not deck.turn_active:
		return false
	if not party.is_valid() or not enemies.is_valid():
		return false

	var catalog := StarterCards.new()
	var definition := catalog.get_definition(card_id)
	if definition.is_empty():
		return false
	if not SUPPORTED_CARD_IDS.has(card_id):
		return false

	var owner_id = definition.get("owner")
	var cost = definition.get("cost")
	var from_positions = definition.get("from_positions")
	var to_positions = definition.get("to_positions")
	var target_kind = definition.get("target_kind")
	var effects = definition.get("effects")

	if not owner_id is String or owner_id.is_empty():
		return false
	if not cost is int or cost < 0:
		return false
	if not from_positions is Array or from_positions.is_empty():
		return false
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return false
	if not to_positions is Array or to_positions.is_empty():
		return false
	for position in to_positions:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return false
	if target_kind != "enemy_single":
		return false
	if not effects is Dictionary:
		return false
	var damage = effects.get("damage")
	if not damage is int or damage < 0:
		return false
	if final_damage != null:
		damage = final_damage

	# Held copy and affordable energy.
	if not deck.hand.has(card_id):
		return false
	if deck.energy < cost:
		return false

	# Living matching owner in an allowed from-position. Derive the actual slot
	# from the roster instead of assuming a fixed hero order.
	var owner_position := 0
	var owner_count := 0
	for hero in party.get_heroes():
		if hero["id"] == owner_id:
			owner_count += 1
			owner_position = hero["position"]
	if owner_count != 1:
		return false
	if owner_position == 0 or party.is_downed(owner_position):
		return false
	if not from_positions.has(owner_position):
		return false

	# Allowed, occupied, living enemy target.
	if not target_position is int:
		return false
	if not to_positions.has(target_position):
		return false
	var target_enemy := enemies.get_enemy(target_position)
	if target_enemy.is_empty():
		return false
	if enemies.is_slain(target_position):
		return false

	# All checks passed; mutate exactly once through the shared APIs.
	if not deck.try_spend_energy(cost):
		return false
	if not enemies.apply_damage(target_position, damage):
		return false
	if not deck.discard_played(card_id):
		return false
	return true
