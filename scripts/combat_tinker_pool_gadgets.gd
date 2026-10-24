class_name CombatTinkerPoolGadgets
extends RefCounted
## Resolves Tinker's two nonattack utility pool cards (Spare Parts and Sight Glass)
## against the shared CombatDeck, CombatParty and CombatEnemies. Does not own
## definitions or duplicate state; callers supply seeded instances.
##
## An optional explicit wearer bind projects the M05 ARM/HEAD Block patches onto
## Spare Parts and the HEAD Exposed patch onto Sight Glass only. It is
## authenticated against the genuine run wardrobe and torn ledger, snapshots
## them, and fails closed once either authority moves.

var _binding_attempted: bool = false
var _binding_valid: bool = false
var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}
var _patch_rules: CombatPatchAttackRules = null
var _head_rules: CombatM05HeadPatchRules = null


func _init() -> void:
	pass


## Authenticates and snapshots a genuine wardrobe and torn ledger for the
## wearer-only Block projection. A failed bind clears any previous binding and
## stays explicit, so a later resolution rejects instead of granting vanilla.
func bind_patch_wardrobe(wardrobe: Variant, torn: Variant,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	_binding_attempted = true
	_binding_valid = false
	_wardrobe = null
	_torn = null
	_wardrobe_snapshot = {}
	_torn_snapshot = {}
	_patch_rules = null
	_head_rules = null

	if not (wardrobe is RunPatchWardrobe) or not (torn is RunTornMending):
		return false
	if not wardrobe.is_valid() or not torn.is_valid():
		return false

	var snap: Dictionary = wardrobe.get_snapshot()
	var torn_state: Dictionary = torn.read_state()

	if expected_wardrobe != null:
		if typeof(expected_wardrobe) != TYPE_DICTIONARY or expected_wardrobe != snap:
			return false
	if expected_torn != null:
		if typeof(expected_torn) != TYPE_DICTIONARY or expected_torn != torn_state:
			return false

	var rules := CombatPatchAttackRules.new()
	if not rules.bind_wardrobe(wardrobe, torn):
		return false

	var head_rules := CombatM05HeadPatchRules.new()
	if not head_rules.bind_wardrobe(wardrobe, torn):
		return false

	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_snapshot = snap.duplicate(true)
	_torn_snapshot = torn_state.duplicate(true)
	_patch_rules = rules
	_head_rules = head_rules
	_binding_valid = true
	return true


## True when no bind was requested, or when the bound authorities are still the
## exact ledgers that were authenticated.
func is_patch_binding_valid() -> bool:
	if not _binding_attempted:
		return true
	if not _binding_valid or _wardrobe == null or _torn == null:
		return false
	if not _wardrobe.is_valid() or not _torn.is_valid():
		return false
	if _wardrobe.get_snapshot() != _wardrobe_snapshot:
		return false
	if _torn.read_state() != _torn_snapshot:
		return false
	if _patch_rules == null or not _patch_rules.is_valid():
		return false
	if _head_rules == null or not _head_rules.read_projection().get("ok", false):
		return false
	return true


func get_patches() -> CombatPatchAttackRules:
	return _patch_rules


func get_head_patches() -> CombatM05HeadPatchRules:
	return _head_rules


func get_wardrobe() -> RunPatchWardrobe:
	return _wardrobe


func get_torn() -> RunTornMending:
	return _torn


## Spare Parts family: cost 0, target_kind self, from positions 2 or 3.
## Effects: {block: N, draw: 1}. Grants Block to the actual current Tinker,
## draws one using CombatDeck.draw_extra (even if no card is available),
## then discards one held copy. Does not consume first-attack bonus.
##
## A bound wearer adds only +2 per active Tinker-worn Hemguard Cuff ARM and/or
## Reinforced Browband HEAD to the authored positive Block; Sight Glass and
## every other card gain no Block from this projection.
##
## Returns {ok: true, block: int, drawn: int} on success,
## {ok: false} on rejection (no state changes).
## Rejects any nonzero target_position (Spare Parts has target_kind self).
func resolve_spare_parts(deck: CombatDeck, party: CombatParty,
		card_id: String, target_position: int = 0) -> Dictionary:
	## Reject any nonzero target_position (Spare Parts has target_kind self).
	if target_position != 0:
		return _failure()
	## A stale or failed explicit bind never silently grants an unpatched cast.
	if _binding_attempted and not is_patch_binding_valid():
		return _failure()
	if deck == null or party == null or not deck.turn_active or not party.is_valid():
		return _failure()
	if not deck.hand.has(card_id) or deck.energy < 0:
		return _failure()

	var definition: Dictionary = TinkerPoolCards.new().get_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id \
			or definition.get("owner") != "tinker":
		return _failure()

	var cost: Variant = definition.get("cost")
	var from_value: Variant = definition.get("from_positions")
	var kind_value: Variant = definition.get("target_kind")
	var effects_value: Variant = definition.get("effects")
	if not cost is int or cost != 0 \
			or not from_value is Array \
			or not kind_value is String or kind_value != "self" \
			or not effects_value is Dictionary:
		return _failure()

	var effects: Dictionary = effects_value
	var block_amt: Variant = effects.get("block")
	var draw_amt: Variant = effects.get("draw")
	if not block_amt is int or block_amt <= 0 \
			or not draw_amt is int or draw_amt != 1:
		return _failure()

	## Wearer-only projection: only a living Tinker's own worn ARM/HEAD Block
	## patches count, and only onto this card's authored positive Block.
	var bonus: int = 0
	if _binding_attempted:
		if _patch_rules != null:
			var arm_bonus: int = _patch_rules.card_block_bonus("tinker", card_id)
			if arm_bonus < 0:
				return _failure()
			bonus += arm_bonus
		if _head_rules != null:
			var head_bonus: int = _head_rules.get_bonus("tinker", card_id, "block")
			if head_bonus < 0:
				return _failure()
			bonus += head_bonus
		if bonus < 0 or bonus > CombatParty.MAX_INT:
			return _failure()
	var granted_block: int = block_amt
	if bonus > 0:
		if granted_block > CombatParty.MAX_INT - bonus:
			return _failure()
		granted_block += bonus

	## Find the Tinker hero in an allowed from_position.
	var owner_position: int = 0
	for hero in party.get_heroes():
		if hero.get("id") == "tinker":
			var pos: Variant = hero.get("position")
			if pos is int and from_value.has(pos) and not party.is_downed(pos):
				owner_position = pos
				break
	if owner_position == 0:
		return _failure()

	## Cap Block before any party/deck mutation.
	var current_block: int = party.get_hero(owner_position)["block"]
	if granted_block > CombatParty.MAX_INT - current_block:
		return _failure()
	if not party.gain_block(owner_position, granted_block):
		return _failure()

	## Draw before discarding so the just-played zero-cost card cannot
	## be drawn from discard during its own resolution.
	var drawn: int = deck.draw_extra(draw_amt)

	## Spend energy (zero) and discard exactly one held copy.
	if not deck.try_spend_energy(cost):
		return _failure()
	if not deck.discard_played(card_id):
		return _failure()

	return {"ok": true, "block": granted_block, "drawn": drawn}


## Sight Glass family: cost 1, target_kind enemy_single, from positions 2 or 3.
## Effects: {exposed: 2, draw: 1}. Applies the authored Exposed plus any
## wearer-only HEAD projection to one chosen LIVING enemy at a to_position,
## draws one, discards one held copy, spends 1 energy.
## Does NOT consume first-attack bonus (not an attack). Stacks on pre-existing
## Exposed. Slain enemies remain in slots but cannot be targeted.
##
## A bound wearer adds only +1 per active Tinker-worn Button Glass Visor HEAD to
## this card's authored positive Exposed; the same computed amount is used for
## the status-capacity preflight and the returned exposed_applied field.
##
## Returns {ok: true, exposed_applied: int, drawn: int, target: int} on success,
## {ok: false} on rejection (no state changes).
func resolve_sight_glass(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int) -> Dictionary:
	## A stale or failed explicit bind never silently grants an unpatched cast.
	if _binding_attempted and not is_patch_binding_valid():
		return _failure()
	if deck == null or party == null or enemies == null \
			or not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return _failure()
	if not deck.hand.has(card_id):
		return _failure()

	var definition: Dictionary = TinkerPoolCards.new().get_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id \
			or definition.get("owner") != "tinker":
		return _failure()

	var cost: Variant = definition.get("cost")
	var from_value: Variant = definition.get("from_positions")
	var kind_value: Variant = definition.get("target_kind")
	var to_value: Variant = definition.get("to_positions")
	var effects_value: Variant = definition.get("effects")
	if not cost is int or cost != 1 \
			or not from_value is Array \
			or not kind_value is String or kind_value != "enemy_single" \
			or not to_value is Array or to_value.is_empty() \
			or not effects_value is Dictionary:
		return _failure()

	var effects: Dictionary = effects_value
	var exposed_amt: Variant = effects.get("exposed")
	var draw_amt: Variant = effects.get("draw")
	if not exposed_amt is int or exposed_amt != 2 \
			or not draw_amt is int or draw_amt != 1:
		return _failure()

	## Wearer-only projection: only a living Tinker's own worn HEAD patch that
	## names this exact card's positive Exposed counts, and it is added once.
	var bonus: int = 0
	if _binding_attempted and _head_rules != null:
		bonus = _head_rules.get_bonus("tinker", card_id, "exposed")
		if bonus < 0 or bonus > CombatEnemies.MAX_INT - exposed_amt:
			return _failure()
	var applied_exposed: int = exposed_amt + bonus

	## Validate target position is in to_positions and enemy is living.
	if not target_position is int or not to_value.has(target_position):
		return _failure()
	if enemies.is_slain(target_position):
		return _failure()

	## Find the Tinker hero in an allowed from_position.
	var owner_position: int = 0
	for hero in party.get_heroes():
		if hero.get("id") == "tinker":
			var pos: Variant = hero.get("position")
			if pos is int and from_value.has(pos) and not party.is_downed(pos):
				owner_position = pos
				break
	if owner_position == 0:
		return _failure()

	## Validate status capacity before any mutation, using the computed amount.
	if not enemies.can_apply_statuses({target_position: {"exposed": applied_exposed}}):
		return _failure()

	## Spend energy first, then apply effects.
	if not deck.try_spend_energy(cost):
		return _failure()

	## Apply Exposed (stacks on existing).
	enemies.apply_statuses({target_position: {"exposed": applied_exposed}})

	## Draw one card.
	var drawn: int = deck.draw_extra(draw_amt)

	## Discard exactly one held copy.
	if not deck.discard_played(card_id):
		return _failure()

	return {"ok": true, "exposed_applied": applied_exposed, "drawn": drawn, "target": target_position}


func _failure() -> Dictionary:
	return {"ok": false}