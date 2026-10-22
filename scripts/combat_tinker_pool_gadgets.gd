class_name CombatTinkerPoolGadgets
extends RefCounted
## Resolves Tinker's two nonattack utility pool cards (Spare Parts and Sight Glass)
## against the shared CombatDeck, CombatParty and CombatEnemies. Does not own
## definitions or duplicate state; callers supply seeded instances.


func _init() -> void:
	pass


## Spare Parts family: cost 0, target_kind self, from positions 2 or 3.
## Effects: {block: N, draw: 1}. Grants Block to the actual current Tinker,
## draws one using CombatDeck.draw_extra (even if no card is available),
## then discards one held copy. Does not consume first-attack bonus.
##
## Returns {ok: true, block: int, drawn: int} on success,
## {ok: false} on rejection (no state changes).
func resolve_spare_parts(deck: CombatDeck, party: CombatParty,
		card_id: String) -> Dictionary:
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

	## Validate Block capacity before any mutation.
	if not party.gain_block(owner_position, block_amt):
		return _failure()

	## Draw before discarding so the just-played zero-cost card cannot
	## be drawn from discard during its own resolution.
	var drawn: int = deck.draw_extra(draw_amt)

	## Spend energy (zero) and discard exactly one held copy.
	if not deck.try_spend_energy(cost):
		return _failure()
	if not deck.discard_played(card_id):
		return _failure()

	return {"ok": true, "block": block_amt, "drawn": drawn}


## Sight Glass family: cost 1, target_kind enemy_single, from positions 2 or 3.
## Effects: {exposed: 2, draw: 1}. Applies Exposed 2 to one chosen LIVING
## enemy at a to_position, draws one, discards one held copy, spends 1 energy.
## Does NOT consume first-attack bonus (not an attack). Stacks on pre-existing
## Exposed. Slain enemies remain in slots but cannot be targeted.
##
## Returns {ok: true, exposed_applied: int, drawn: int, target: int} on success,
## {ok: false} on rejection (no state changes).
func resolve_sight_glass(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int) -> Dictionary:
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

	## Validate status capacity before any mutation.
	if not enemies.can_apply_statuses({target_position: {"exposed": exposed_amt}}):
		return _failure()

	## Spend energy first, then apply effects.
	if not deck.try_spend_energy(cost):
		return _failure()

	## Apply Exposed (stacks on existing).
	enemies.apply_statuses({target_position: {"exposed": exposed_amt}})

	## Draw one card.
	var drawn: int = deck.draw_extra(draw_amt)

	## Discard exactly one held copy.
	if not deck.discard_played(card_id):
		return _failure()

	return {"ok": true, "exposed_applied": exposed_amt, "drawn": drawn, "target": target_position}


func _failure() -> Dictionary:
	return {"ok": false}