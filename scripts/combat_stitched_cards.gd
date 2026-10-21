class_name CombatStitchedCards
extends RefCounted
## Scene-free atomic Rest composite. Supply the run-owned Rest service, never
## caller-authored half dictionaries. Share attacks with ordinary card plays so
## Tinker's turn latch and wearer-only patch latches have one combat authority.

var _attacks: CombatAttackCards
var _support := CombatSupportCards.new()


func _init(attacks: CombatAttackCards = null) -> void:
	_attacks = attacks if attacks != null else CombatAttackCards.new()


func play_stitched(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		run_cards: RunRestStitchCards, stitched_id: String,
		first_target: int = 0, second_target: int = 0) -> Dictionary:
	var failure := {"ok": false, "halves": []}
	if deck == null or party == null or enemies == null or run_cards == null:
		return failure
	if not deck.turn_active or not deck.hand.has(stitched_id):
		return failure
	if not party.is_valid() or not enemies.is_valid() or enemies.is_victorious():
		return failure
	var preview := run_cards.preview_play(stitched_id, party.get_heroes())
	if not preview.ok or deck.energy < preview.cost:
		return failure
	if not CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes()).ok:
		return failure
	if not enemies.can_apply_statuses({}):
		return failure

	# Construction with empty piles never draws RNG. Preserve the injected run
	# generator itself on publish; only its staged state advances on success.
	var rng := RandomNumberGenerator.new()
	rng.state = deck._rng.state
	var staged_deck := CombatDeck.new([], rng)
	staged_deck.draw_pile.assign(deck.draw_pile)
	staged_deck.hand.assign(deck.hand)
	staged_deck.discard_pile.assign(deck.discard_pile)
	staged_deck.combat_state.player_turn_active = true
	staged_deck.combat_state.energy = deck.energy
	var staged_party := CombatParty.new(party.get_heroes())
	staged_party._heroes = party.get_heroes()
	var staged_enemies := CombatEnemies.new(enemies.get_enemies())
	staged_enemies._enemies = enemies.get_enemies()
	var attacks := _attacks.stage_transaction()
	var results: Array[Dictionary] = []
	var targets := [first_target, second_target]
	for index in range(2):
		var half: Dictionary = preview.halves[index]
		var target: int = targets[index]
		var kind: String = half.target_kind
		if kind in ["self", "none", "enemy_all"] and target != 0:
			return failure
		if kind in ["enemy_single", "ally_single"] and not half.to_positions.is_empty() and not half.to_positions.has(target):
			return failure
		if kind in ["enemy_single", "enemy_all"]:
			var result := attacks.resolve_staged_half(staged_party, staged_enemies, half.id, target)
			if not result.ok:
				return failure
			results.append(result)
		else:
			var effect := "draw"
			var amount: int = half.effects.get("draw", 0)
			if half.effects.has("block"):
				effect = "self_block" if kind == "self" else "ally_block"
				amount = half.effects.block
			elif half.effects.has("heal"):
				effect = "ally_heal"
				amount = half.effects.heal
			var normalized := {"id": stitched_id, "owner_id": half.owner,
				"cost": 0, "from_positions": half.from_positions,
				"effect": effect, "amount": amount}
			if not _support.resolve_staged_half(staged_deck, staged_party, normalized, target):
				return failure
			results.append({"ok": true, "effect": effect, "amount": amount})
	staged_deck.try_spend_energy(preview.cost)
	staged_deck.discard_played(stitched_id)
	party._heroes = staged_party.get_heroes()
	enemies._enemies = staged_enemies.get_enemies()
	deck.draw_pile.assign(staged_deck.draw_pile)
	deck.hand.assign(staged_deck.hand)
	deck.discard_pile.assign(staged_deck.discard_pile)
	deck.combat_state.energy = staged_deck.energy
	deck._rng.state = rng.state
	_attacks.commit_transaction(attacks)
	return {"ok": true, "halves": results}
