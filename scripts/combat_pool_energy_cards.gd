class_name CombatPoolEnergyCards
extends RefCounted
## Scene-free resolution of two complementary pool energy plays:
## Tinker Overclock (+1 energy, 3 self-damage) and Seamstress Tailor's Trance
## (+1 energy for its 1 cost, draw 2/3). Definitions come only from the real
## catalogs; CombatDeck and CombatParty retain all authoritative state and the
## caller's seeded RNG.

const OVERCLOCK_IDS := ["tinker_overclock", "tinker_overclock_plus"]
const TRANCE_IDS := ["seamstress_tailors_trance", "seamstress_tailors_trance_plus"]
const SUPPORTED_IDS := [
	"tinker_overclock", "tinker_overclock_plus",
	"seamstress_tailors_trance", "seamstress_tailors_trance_plus"
]


func is_supported_card(card_id: Variant) -> bool:
	if not card_id is String:
		return false
	return SUPPORTED_IDS.has(card_id)


func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> bool:
	if not card_id is String:
		return false
	var id: String = card_id
	if deck == null or party == null or not is_supported_card(id):
		return false
	if not deck.turn_active or not party.is_valid() or party.is_defeated():
		return false

	var is_overclock: bool = OVERCLOCK_IDS.has(id)
	var definition: Dictionary = {}
	if is_overclock:
		definition = TinkerPoolCards.new().get_definition(id)
	else:
		definition = SeamstressPoolCards.new().get_definition(id)
	if definition.is_empty() or definition.get("id") != id:
		return false

	var owner_id: String = definition.get("owner", "")
	var expected_owner: String = "tinker" if is_overclock else "seamstress"
	if owner_id != expected_owner:
		return false

	var cost: Variant = definition.get("cost")
	var from_positions: Variant = definition.get("from_positions")
	var target_kind: Variant = definition.get("target_kind")
	var to_positions: Variant = definition.get("to_positions")
	var effects: Variant = definition.get("effects")
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY:
		return false
	if not from_positions is Array or from_positions.is_empty():
		return false
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return false
	if target_kind != "self":
		return false
	if not to_positions is Array or not to_positions.is_empty():
		return false
	if not effects is Dictionary:
		return false

	if is_overclock:
		if cost != 0:
			return false
		if effects.size() != 2 or effects.get("gain_energy") != 1 \
				or effects.get("self_hp_loss") != 3:
			return false
	else:
		if cost != 1:
			return false
		if effects.get("energy") != 1:
			return false
		var draw_count: Variant = effects.get("draw")
		if not draw_count is int or (draw_count != 2 and draw_count != 3):
			return false
		var is_plus: bool = id.ends_with("_plus")
		if is_plus and draw_count != 3:
			return false
		if not is_plus and draw_count != 2:
			return false

	# Hand membership is the actual played copy, never just a catalog lookup.
	if not deck.hand.has(id) or deck.energy < cost:
		return false

	# Owner identity, not slot index, determines legality.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_count := 0
	var owner_position := 0
	for hero: Dictionary in heroes:
		if hero.get("id") == owner_id:
			owner_count += 1
			owner_position = int(hero.get("position", 0))
	if owner_count != 1:
		return false
	if owner_position == 0 or not from_positions.has(owner_position) \
			or party.is_downed(owner_position):
		return false

	# No selected target: target 0 only.
	if target_position != 0:
		return false

	# Preflight upper-bound guard for the authored +1 energy gain.
	if deck.combat_state.energy > CombatParty.MAX_INT - 1:
		return false

	# Committed phase: each operation is guaranteed by preflight.
	if is_overclock:
		if not party.apply_damage(owner_position, 3):
			return false
		deck.combat_state.energy += 1
		return deck.discard_played(id)
	else:
		if not deck.try_spend_energy(cost):
			return false
		deck.combat_state.energy += 1
		var draw_count: int = int(effects.get("draw"))
		deck.draw_extra(draw_count)
		return deck.discard_played(id)