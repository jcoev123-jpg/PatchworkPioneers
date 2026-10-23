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
const SELF_DAMAGE := 3
const ENERGY_GAIN := 1


func is_supported_card(card_id: Variant) -> bool:
	if not card_id is String:
		return false
	return SUPPORTED_IDS.has(card_id)


## Ordinary held-card play: the authored half plus this real hand copy's cost,
## discard and the shared run RNG.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> bool:
	if deck == null or party == null:
		return false
	var rule := _authored_rule(card_id)
	if rule.is_empty():
		return false
	if not deck.turn_active or not party.is_valid() or party.is_defeated():
		return false
	var owner_position := _owner_position(rule, party)
	if owner_position == 0:
		return false
	# No selected target: target 0 only.
	if target_position != 0:
		return false

	# Hand membership is the actual played copy, never just a catalog lookup.
	if not deck.hand.has(rule["id"]) or deck.energy < rule["cost"]:
		return false

	# Preflight upper-bound guard for the authored +1 energy gain.
	if deck.combat_state.energy > CombatParty.MAX_INT - ENERGY_GAIN:
		return false

	# Committed phase: each operation is guaranteed by preflight.
	var self_damage: int = int(rule["self_hp_loss"])
	if rule["is_overclock"]:
		if not party.apply_damage(owner_position, self_damage):
			return false
		deck.combat_state.energy += ENERGY_GAIN
		return deck.discard_played(rule["id"])
	if not deck.try_spend_energy(rule["cost"]):
		return false
	deck.combat_state.energy += ENERGY_GAIN
	deck.draw_extra(int(rule["draw"]))
	return deck.discard_played(rule["id"])


## Staged half for an enclosing composite's detached authorities. The printed
## half is not in that deck's hand and the enclosing transaction alone charges
## its capped cost and discards once, so only the authored effects are applied.
## Returns the exact outcome and never publishes anything on failure.
func resolve_staged_half(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> Dictionary:
	var failed := {"ok": false}
	if deck == null or party == null:
		return failed
	var rule := _authored_rule(card_id)
	if rule.is_empty():
		return failed
	if not deck.turn_active or not party.is_valid() or party.is_defeated():
		return failed
	var owner_position := _owner_position(rule, party)
	if owner_position == 0:
		return failed
	if target_position != 0:
		return failed
	if deck.combat_state.energy > CombatParty.MAX_INT - ENERGY_GAIN:
		return failed

	var self_damage: int = int(rule["self_hp_loss"])
	if rule["is_overclock"]:
		if not party.apply_damage(owner_position, self_damage):
			return failed
		deck.combat_state.energy += ENERGY_GAIN
		return {"ok": true, "effect": "gain_energy", "amount": ENERGY_GAIN,
			"self_hp_loss": self_damage}
	var draw_count: int = int(rule["draw"])
	deck.combat_state.energy += ENERGY_GAIN
	deck.draw_extra(draw_count)
	return {"ok": true, "effect": "gain_energy", "amount": ENERGY_GAIN,
		"draw": draw_count}


## Authentic catalog/owner/from-position/target contract shared by held plays
## and composite halves. Returns {} for any counterfeit or unsupported record.
func _authored_rule(card_id: Variant) -> Dictionary:
	if not card_id is String:
		return {}
	var id: String = card_id
	if not SUPPORTED_IDS.has(id):
		return {}
	var is_overclock: bool = OVERCLOCK_IDS.has(id)
	var definition: Dictionary = {}
	if is_overclock:
		definition = TinkerPoolCards.new().get_definition(id)
	else:
		definition = SeamstressPoolCards.new().get_definition(id)
	if definition.is_empty() or definition.get("id") != id:
		return {}

	var owner_id: String = definition.get("owner", "")
	var expected_owner: String = "tinker" if is_overclock else "seamstress"
	if owner_id != expected_owner:
		return {}

	var cost: Variant = definition.get("cost")
	var from_positions: Variant = definition.get("from_positions")
	var target_kind: Variant = definition.get("target_kind")
	var to_positions: Variant = definition.get("to_positions")
	var effects: Variant = definition.get("effects")
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY:
		return {}
	if not from_positions is Array or from_positions.is_empty():
		return {}
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return {}
	if target_kind != "self":
		return {}
	if not to_positions is Array or not to_positions.is_empty():
		return {}
	if not effects is Dictionary:
		return {}

	var draw_count := 0
	if is_overclock:
		if cost != 0:
			return {}
		if effects.size() != 2 or effects.get("gain_energy") != ENERGY_GAIN \
				or effects.get("self_hp_loss") != SELF_DAMAGE:
			return {}
	else:
		if cost != 1:
			return {}
		if effects.get("energy") != ENERGY_GAIN:
			return {}
		var draws: Variant = effects.get("draw")
		if not draws is int or (draws != 2 and draws != 3):
			return {}
		var is_plus: bool = id.ends_with("_plus")
		if is_plus and draws != 3:
			return {}
		if not is_plus and draws != 2:
			return {}
		draw_count = draws
	return {
		"id": id, "is_overclock": is_overclock, "owner": owner_id,
		"cost": cost, "from_positions": from_positions.duplicate(),
		"draw": draw_count, "self_hp_loss": SELF_DAMAGE if is_overclock else 0,
	}


## Owner identity, not slot index, determines legality.
func _owner_position(rule: Dictionary, party: CombatParty) -> int:
	var owner_id: String = rule["owner"]
	var owner_count := 0
	var owner_position := 0
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") == owner_id:
			owner_count += 1
			owner_position = int(hero.get("position", 0))
	if owner_count != 1:
		return 0
	var from_positions: Array = rule["from_positions"]
	if owner_position == 0 or not from_positions.has(owner_position) \
			or party.is_downed(owner_position):
		return 0
	return owner_position
