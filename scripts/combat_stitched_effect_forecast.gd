class_name CombatStitchedEffectForecast
extends RefCounted
## Read-only sequential outcome oracle. The only rules executor is the committed
## CombatStitchedCards transaction, run against entirely detached battle models.
## A failed later half discards the entire staged simulation.

var _targets := CombatStitchedTargetPreview.new()


func get_forecast(run_cards: Variant, expected_ledger: Variant, deck: Variant,
		party: Variant, enemies: Variant, stitched_id: Variant,
		first_target: Variant = 0, second_target: Variant = 0,
		current_transaction: Variant = null) -> Dictionary:
	var failure := _rejected()
	if typeof(first_target) != TYPE_INT or typeof(second_target) != TYPE_INT:
		return failure
	if current_transaction != null and not current_transaction is CombatStitchedCards:
		return failure
	var admission := _targets.get_preview(run_cards, expected_ledger, deck,
		party, enemies, stitched_id)
	if not admission.get("playable", false):
		return failure

	# A genuine, current Rest receipt and held composite were checked by the
	# target preview. Reconstruct the validated descriptor owner independently.
	var ledger: Dictionary = run_cards.get_snapshot()
	var staged_rest := RunRestStitchCards.new(ledger["deck"], ledger["descriptors"],
		ledger["remaining_scraps"], ledger["next_stitch_id"])
	if not staged_rest.is_valid() or staged_rest.get_snapshot() != ledger:
		return failure

	var live_deck: CombatDeck = deck
	var live_party: CombatParty = party
	var live_enemies: CombatEnemies = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = live_deck._rng.seed
	rng.state = live_deck._rng.state
	var staged_deck := CombatDeck.new([], rng)
	staged_deck.draw_pile.assign(live_deck.draw_pile)
	staged_deck.hand.assign(live_deck.hand)
	staged_deck.discard_pile.assign(live_deck.discard_pile)
	staged_deck.combat_state.player_turn_active = live_deck.turn_active
	staged_deck.combat_state.energy = live_deck.energy

	var heroes: Array[Dictionary] = live_party.get_heroes()
	var foes: Array[Dictionary] = live_enemies.get_enemies()
	var staged_party := CombatParty.new(heroes)
	staged_party._heroes = heroes.duplicate(true)
	var staged_enemies := CombatEnemies.new(foes)
	staged_enemies._enemies = foes.duplicate(true)

	# The supplied live transaction is the only optional passive/patch authority.
	# Staging retains first-Tinker and first-Button-Eye latches without consuming
	# them; rebind support at its ORIGINAL optimistic combat-start receipts.
	var staged_attacks := CombatAttackCards.new()
	if current_transaction != null:
		var current: CombatStitchedCards = current_transaction
		if current._attacks == null or not current._support.is_patch_binding_valid():
			return failure
		staged_attacks = current._attacks.stage_transaction()
	var staged_transaction := CombatStitchedCards.new(staged_attacks)
	if current_transaction != null:
		var support: CombatSupportCards = current_transaction._support
		if support._patches != null and not staged_transaction.bind_patch_wardrobe(
				support._wardrobe, support._torn,
				support._wardrobe_snapshot, support._torn_snapshot):
			return failure

	var result := staged_transaction.play_stitched(staged_deck, staged_party,
		staged_enemies, staged_rest, stitched_id, first_target, second_target)
	if not result.get("ok", false) or result.get("halves", []).size() != 2:
		return failure
	return {
		"playable": true,
		"stitched_id": stitched_id,
		"cost": admission["cost"],
		"halves": result["halves"].duplicate(true),
		"projected": {
			"draw_pile": staged_deck.draw_pile.duplicate(),
			"hand": staged_deck.hand.duplicate(),
			"discard_pile": staged_deck.discard_pile.duplicate(),
			"energy": staged_deck.energy,
			"turn_active": staged_deck.turn_active,
			"rng_seed": staged_deck._rng.seed,
			"rng_state": staged_deck._rng.state,
			"heroes": staged_party.get_heroes(),
			"enemies": staged_enemies.get_enemies(),
			"tinker_consumed": staged_attacks._tinker._consumed,
			"patch_latches": {} if staged_attacks._patches == null else staged_attacks._patches.latch_snapshot(),
		},
	}.duplicate(true)


func _rejected() -> Dictionary:
	return {"playable": false, "stitched_id": "", "cost": 0,
		"halves": [], "projected": {}}
