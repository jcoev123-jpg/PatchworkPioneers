class_name CombatSupportCards
extends RefCounted
## Resolves caller-supplied support definitions against the authoritative shared
## CombatDeck and CombatParty. Does not own card definitions or duplicate state.

var _patches: CombatShopPatchRules = null
var _arm_patches: CombatPatchAttackRules = null
var _wardrobe: RunPatchWardrobe
var _torn: RunTornMending
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}


## An attempted binding remains explicit even on failure. Run ledgers must stay
## at the authenticated combat-start snapshot until a fresh binding is supplied.
func bind_patch_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	_patches = CombatShopPatchRules.new()
	_arm_patches = CombatPatchAttackRules.new()
	_wardrobe = wardrobe
	_torn = torn
	if not _patches.bind_wardrobe(wardrobe, torn, expected_wardrobe, expected_torn):
		return false
	if not _arm_patches.bind_wardrobe(wardrobe, torn):
		return false
	_wardrobe_snapshot = wardrobe.get_snapshot()
	_torn_snapshot = torn.read_state()
	return true


func is_patch_binding_valid() -> bool:
	if _patches == null and _arm_patches == null:
		return true
	if _patches == null or not _patches.is_valid():
		return false
	if _arm_patches == null or not _arm_patches.is_valid():
		return false
	return CombatShopPatchRules.new().bind_wardrobe(
		_wardrobe, _torn, _wardrobe_snapshot, _torn_snapshot) and CombatPatchAttackRules.new().bind_wardrobe(
		_wardrobe, _torn)


func play_support(deck: CombatDeck, party: CombatParty, definition: Dictionary, target_position: int = 0, cost_discount: int = 0) -> bool:
	return _play_support(deck, party, definition, target_position, true, "", cost_discount)


## Only for a detached transaction: all ordinary validation/effects, but the
## enclosing composite owns its single charge/discard after both halves resolve.
func resolve_staged_half(deck: CombatDeck, party: CombatParty,
		definition: Dictionary, target_position: int = 0, authored_half_id: String = "") -> bool:
	return _play_support(deck, party, definition, target_position, false, authored_half_id)


func _play_support(deck: CombatDeck, party: CombatParty, definition: Dictionary,
		target_position: int, consume_card: bool, authored_half_id: String = "",
		cost_discount: int = 0) -> bool:
	if deck == null or party == null or not deck.turn_active or not party.is_valid():
		return false
	if not is_patch_binding_valid():
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
	# The one authored Clockwork point only ever reduces a PRINTED cost of two or
	# more, and only a real consumed play may charge the reduced amount.
	if cost_discount < 0 or cost_discount > 1 \
			or (cost_discount > 0 and (cost < 2 or not consume_card)):
		return false
	var effective_cost: int = cost - cost_discount
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
	if not deck.hand.has(card_id) or deck.energy < effective_cost:
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

	# Authenticate the complete normalized healing and block contracts before adding a
	# catalog-owned bonus. A preinflated amount or spoofed owner is rejected.
	if _patches != null:
		var authored_id: String = card_id if consume_card else authored_half_id
		var authored := StarterCards.new().get_definition(authored_id)
		if effect == "ally_heal" or authored.get("effects", {}).has("heal"):
			if effect != "ally_heal" or not CombatShopPatchRules._has_positive_authored_heal(authored, owner_id, authored_id):
				return false
			if amount != authored.effects.heal or from_positions != authored.from_positions:
				return false
			if cost != (authored.cost if consume_card else 0) or authored.target_kind != "ally_single":
				return false
			if not authored.to_positions.is_empty() and not authored.to_positions.has(recipient):
				return false
			amount += _patches.healing_card_bonus(owner_id, authored_id)

		var is_block: bool = (effect == "self_block" or effect == "ally_block")
		if is_block or authored.get("effects", {}).has("block"):
			if not is_block or not _has_positive_authored_block(authored, owner_id, authored_id):
				return false
			if amount != authored.effects.block or from_positions != authored.from_positions:
				return false
			var expected_target := "self" if effect == "self_block" else "ally_single"
			if cost != (authored.cost if consume_card else 0) or authored.target_kind != expected_target:
				return false
			if not authored.to_positions.is_empty() and not authored.to_positions.has(recipient):
				return false
			if _arm_patches != null:
				amount += _arm_patches.card_block_bonus(owner_id, authored_id)
			var current_block: int = party.get_hero(recipient)["block"]
			if amount > CombatParty.MAX_INT - current_block:
				return false

	# After prevalidation all following operations are guaranteed by the
	# existing deck/party APIs to succeed; charge exactly once.
	if consume_card and not deck.try_spend_energy(effective_cost):
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


static func _has_positive_authored_block(definition: Variant, hero_id: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(hero_id) != TYPE_STRING or typeof(card_id) != TYPE_STRING:
		return false
	if definition.get("id") != card_id or definition.get("owner") != hero_id:
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return false
	var block: Variant = effects.get("block")
	return typeof(block) == TYPE_INT and block > 0
