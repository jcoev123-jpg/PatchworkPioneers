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
## One COAT notifier per authentic combat binding; it never executes a card.
var _borrowed_button: CombatBorrowedButton = null
var _button_party: CombatParty = null
var _heal_receipt_number := 0
var _pending_new_party := false


## An attempted binding remains explicit even on failure. Run ledgers stay at the
## authenticated combat-start snapshot until a fresh binding is supplied.
func bind_patch_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	# Repeated authentication of the SAME combat ledgers cannot refill a spent
	# latch. Only a subsequent distinct CombatParty proves a new battle.
	var same_authorities: bool = _borrowed_button != null and _wardrobe == wardrobe \
		and _torn == torn and is_patch_binding_valid()
	var previous_button: CombatBorrowedButton = _borrowed_button if same_authorities else null
	var previous_party: CombatParty = _button_party if same_authorities else null
	var previous_number: int = _heal_receipt_number if same_authorities else 0
	_borrowed_button = null
	_button_party = null
	_heal_receipt_number = 0
	_pending_new_party = false
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
	_borrowed_button = previous_button if same_authorities else CombatBorrowedButton.new()
	_button_party = previous_party
	_heal_receipt_number = previous_number
	_pending_new_party = same_authorities and previous_party != null
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
	# Observe only recipients of the actual committed heal, never catalog forecasts.
	var observations: Array[Dictionary] = []
	if is_field_mend:
		for position in range(1, CombatParty.PARTY_SIZE + 1):
			if not party.is_downed(position):
				var before_hp: int = party.get_hero(position)["hp"]
				party.heal(position, applied_heal)
				observations.append({"position": position, "id": party.get_hero(position)["id"],
					"before": before_hp, "after": party.get_hero(position)["hp"]})
	else:
		var before_hp: int = party.get_hero(target_position)["hp"]
		party.heal(target_position, applied_heal)
		observations.append({"position": target_position, "id": party.get_hero(target_position)["id"],
			"before": before_hp, "after": party.get_hero(target_position)["hp"]})
		if is_darning:
			party.gain_block(target_position, applied_block)
	if not deck.discard_played(card_id):
		return false

	# Only one shared receipt sequence and one COAT latch serve both pool and
	# starter committed heals. Refusal to award never unwinds a legal pool play.
	_notify_borrowed_button(party, definition["owner"], observations, "seamstress_pool_heal")
	return true


## Called solely after CombatStarterSupportPlay has committed an authentic held
## Mend/Mend+ transaction. The mounted hand supplies the recipient's actual
## pre/post HP; this does not replay healing or charge the deck a second time.
func notify_committed_starter_mend(deck: CombatDeck, party: CombatParty,
		card_id: String, target_position: int, before_hp: int, after_hp: int,
		hand_before: int, discard_before: int, energy_before: int) -> Dictionary:
	if card_id not in ["seamstress_mend", "seamstress_mend_plus"] \
			or deck == null or not deck.turn_active or party == null or not party.is_valid() \
			or not is_patch_binding_valid() or _borrowed_button == null:
		return {"ok": false, "awarded": false, "reason": "invalid_commit"}
	# The mounted caller has just received a successful CombatStarterSupportPlay
	# return. Authenticate that a single exact held copy was spent and discarded
	# for its printed one energy before accepting an external heal observation.
	# A display preview, refused cast or stale hand callback cannot satisfy this.
	if hand_before < 1 or discard_before < 0 or energy_before < 1 \
			or deck.hand.count(card_id) != hand_before - 1 \
			or deck.discard_pile.size() != discard_before + 1 \
			or deck.discard_pile.back() != card_id or deck.energy != energy_before - 1:
		return {"ok": false, "awarded": false, "reason": "uncommitted_card"}
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return {"ok": false, "awarded": false, "reason": "invalid_recipient"}
	# The owner is the canonical card owner, never inferred from the recipient seat.
	var seamstress_position := 0
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") == "seamstress":
			seamstress_position = int(hero["position"])
			break
	if seamstress_position not in [2, 3] or party.is_downed(seamstress_position) \
			or party.is_downed(target_position):
		return {"ok": false, "awarded": false, "reason": "invalid_owner_or_recipient"}
	var recipient: Dictionary = party.get_hero(target_position)
	return _notify_borrowed_button(party, "seamstress", [{
		"position": target_position, "id": recipient["id"],
		"before": before_hp, "after": after_hp,
	}], "starter_mend")


## One deterministic counter, party identity, notifier and receipt ledger.
## Same-party wardrobe rebinds keep the spent latch; a new party after rebind
## gets an entirely new notifier. No caller can supply or choose a receipt ID.
func _notify_borrowed_button(party: CombatParty, owner_id: String,
		observations: Array[Dictionary], receipt_kind: String) -> Dictionary:
	if _borrowed_button == null:
		return {"ok": false, "awarded": false, "reason": "unbound"}
	if _pending_new_party:
		_pending_new_party = false
		if _button_party != null and _button_party != party:
			_borrowed_button = CombatBorrowedButton.new()
			_button_party = null
			_heal_receipt_number = 0
	_heal_receipt_number += 1
	if _button_party == null:
		_button_party = party
		_borrowed_button.bind_combat(party, _wardrobe, _torn)
	if _button_party != party:
		return {"ok": false, "awarded": false, "reason": "foreign_party"}
	var result: Dictionary = {"ok": false, "awarded": false, "reason": "no_observations"}
	for observation: Dictionary in observations:
		result = _borrowed_button.notify_committed_heal(
			"%s:%d:%d" % [receipt_kind, _heal_receipt_number, observation["position"]],
			owner_id, observation["id"], observation["before"], observation["after"])
	return result
