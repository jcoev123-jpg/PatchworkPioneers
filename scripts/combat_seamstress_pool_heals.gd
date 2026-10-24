class_name CombatSeamstressPoolHeals
extends RefCounted
## Scene-free resolution of the six D2-1 Seamstress pool healing cards.
## Definitions come only from SeamstressPoolCards; CombatDeck and CombatParty
## retain ownership of all authoritative state and the caller's seeded RNG.

const DARNING_IDS = ["seamstress_darning", "seamstress_darning_plus"]
const TEA_IDS = ["seamstress_thimble_tea", "seamstress_thimble_tea_plus"]
const FIELD_MEND_IDS = ["seamstress_field_mend", "seamstress_field_mend_plus"]

var _catalog := SeamstressPoolCards.new()
var _patches: CombatShopPatchRules = null
var _head_patches: CombatM05HeadPatchRules = null
var _arm_patches: CombatPatchAttackRules = null
var _wardrobe: RunPatchWardrobe
var _torn: RunTornMending
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}


## An attempted binding remains explicit even on failure. Run ledgers stay at the
## authenticated combat-start snapshot until a fresh binding is supplied.
func bind_patch_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	_patches = CombatShopPatchRules.new()
	_head_patches = CombatM05HeadPatchRules.new()
	_arm_patches = CombatPatchAttackRules.new()
	_wardrobe = wardrobe
	_torn = torn
	if not _patches.bind_wardrobe(wardrobe, torn, expected_wardrobe, expected_torn):
		return false
	if not _head_patches.bind_wardrobe(wardrobe, torn):
		return false
	if not _arm_patches.bind_wardrobe(wardrobe, torn):
		return false
	_wardrobe_snapshot = wardrobe.get_snapshot()
	_torn_snapshot = torn.read_state()
	return true


func is_patch_binding_valid() -> bool:
	if _patches == null and _head_patches == null and _arm_patches == null:
		return true
	if _patches == null or _head_patches == null or _arm_patches == null:
		return false
	if not _patches.is_valid() or not _arm_patches.is_valid() \
			or not _head_patches.read_projection().get("ok", false):
		return false
	return CombatShopPatchRules.new().bind_wardrobe(
		_wardrobe, _torn, _wardrobe_snapshot, _torn_snapshot)


func play_card(deck: CombatDeck, party: CombatParty, card_id: String,
		target_position: int = 0) -> bool:
	if deck == null or party == null or not deck.turn_active or not party.is_valid():
		return false
	if not is_patch_binding_valid():
		return false
	if card_id not in DARNING_IDS and card_id not in TEA_IDS and card_id not in FIELD_MEND_IDS:
		return false

	var definition: Dictionary = _catalog.get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "seamstress":
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
	if not to_positions is Array or not to_positions.is_empty() or not effects is Dictionary:
		return false

	var is_darning: bool = card_id in DARNING_IDS
	var is_field_mend: bool = card_id in FIELD_MEND_IDS
	if target_kind != ("party_all" if is_field_mend else "ally_single"):
		return false
	var heal_amount: Variant = effects.get("heal")
	var block_amount: Variant = effects.get("block", 0)
	if not heal_amount is int or heal_amount <= 0:
		return false
	if not block_amount is int or block_amount < 0:
		return false
	if is_darning:
		if block_amount == 0 or effects.size() != 2:
			return false
	elif effects.size() != 1:
		return false
	# The Spare Spool's authored bonus is read from the same authenticated projection
	# as starter support. It adds only HP healing, never Block.
	var applied_heal: int = heal_amount
	if _patches != null:
		applied_heal += _patches.healing_card_bonus(definition["owner"], card_id)

	var applied_block: int = block_amount
	if is_darning:
		if _head_patches != null:
			applied_block += _head_patches.get_bonus(definition["owner"], card_id, "block")
		if _arm_patches != null:
			applied_block += _arm_patches.card_block_bonus(definition["owner"], card_id)

	# Hand membership is the actual played copy, never just a catalog lookup.
	if not deck.hand.has(card_id) or deck.energy < cost:
		return false
	var owner_position: int = 0
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") == definition["owner"]:
			owner_position = int(hero["position"])
			break
	if owner_position == 0 or not from_positions.has(owner_position) or party.is_downed(owner_position):
		return false

	if is_field_mend:
		if target_position != 0:
			return false
	else:
		if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
			return false
		if party.is_downed(target_position):
			return false
		# Block must be preflighted before healing or spending; full HP is legal.
		if is_darning:
			var current_block: int = party.get_hero(target_position)["block"]
			if applied_block > CombatParty.MAX_INT - current_block:
				return false

	# All mutators below are guaranteed to succeed by the preflight checks.
	# They never draw, shuffle or consume the run RNG.
	if not deck.try_spend_energy(cost):
		return false
	if is_field_mend:
		for position in range(1, CombatParty.PARTY_SIZE + 1):
			if not party.is_downed(position):
				party.heal(position, applied_heal)
	else:
		party.heal(target_position, applied_heal)
		if is_darning:
			party.gain_block(target_position, applied_block)
	return deck.discard_played(card_id)
