class_name CombatStarterSupportPlay
extends RefCounted
## Translates only the four authored starter support cards into the existing
## shared-hand CombatSupportCards service. This does not own combat state.

var _catalog := StarterCards.new()
var _support := CombatSupportCards.new()


func play_card(deck: CombatDeck, party: CombatParty, card_id: String, target_position: int = 0) -> bool:
	if deck == null or party == null:
		return false

	var owner_id := ""
	var target_kind := ""
	var effect_key := ""
	var effect := ""
	var amount := 0
	match card_id:
		"warden_brace":
			owner_id = "warden"
			target_kind = "self"
			effect_key = "block"
			effect = "self_block"
			amount = 7
		"seamstress_mend":
			owner_id = "seamstress"
			target_kind = "ally_single"
			effect_key = "heal"
			effect = "ally_heal"
			amount = 5
		"seamstress_stitch_up":
			owner_id = "seamstress"
			target_kind = "ally_single"
			effect_key = "block"
			effect = "ally_block"
			amount = 5
		"tinker_tune_up":
			owner_id = "tinker"
			target_kind = "none"
			effect_key = "draw"
			effect = "draw"
			amount = 1
		_:
			# Fail closed before looking at a hand, spending energy or drawing.
			return false

	var authored: Dictionary = _catalog.get_definition(card_id)
	var effects = authored.get("effects")
	var destinations = authored.get("to_positions")
	if authored.get("id") != card_id or authored.get("owner") != owner_id:
		return false
	if authored.get("target_kind") != target_kind:
		return false
	if not destinations is Array or not destinations.is_empty():
		return false
	# In particular, damage/status/mixed effects must never be smuggled
	# into a support play using a familiar support card ID.
	if not effects is Dictionary or effects.size() != 1:
		return false
	var authored_amount = effects.get(effect_key)
	if not authored_amount is int or authored_amount != amount:
		return false

	var normalized := {
		"id": authored["id"],
		"owner_id": authored["owner"],
		"cost": authored.get("cost"),
		"from_positions": authored.get("from_positions"),
		"effect": effect,
		"amount": authored_amount,
	}
	# One authoritative call: it validates hand/turn/energy/owner/target,
	# then applies the effect, charge and discard without duplicated rules.
	return _support.play_support(deck, party, normalized, target_position)
