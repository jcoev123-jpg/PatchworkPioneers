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
		# Stage the optional combat-scoped P6 COAT authority with the other
		# detached models. Without a valid bound helper the projection stays
		# exactly as unpatched as the real transaction would behave.
		_stage_borrowed_button(current_transaction, live_party, staged_party,
			staged_transaction)

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


## Detached P6 staging: one cloned CombatBorrowedButton and one staged healing
## service bound to the staged party and this transaction's authentic run
## wardrobe/torn receipts. The clone keeps a spent once-per-combat latch and its
## accepted receipt identities, so the preview cannot award a second time, and
## the real notifier is never told about a preview. An absent, unbound, stale or
## foreign helper leaves the old unpatched projection in place, exactly like the
## committed transaction's own precondition.
func _stage_borrowed_button(current: CombatStitchedCards, live_party: CombatParty,
		staged_party: CombatParty, staged_transaction: CombatStitchedCards) -> void:
	var source: CombatSeamstressPoolHeals = current._button_heals
	if source == null or source._borrowed_button == null:
		return
	if source._button_party != null and source._button_party != live_party \
			and not source._pending_new_party:
		return
	var support: CombatSupportCards = current._support
	if support._wardrobe == null or support._torn == null:
		return
	if source._wardrobe != support._wardrobe or source._torn != support._torn:
		return
	if not source.is_patch_binding_valid():
		return
	# A helper still bound to this combat carries its latch; an unspent one or a
	# genuine new combat after a rebind starts a fresh, still-armed notifier.
	var carries_latch: bool = source._button_party == live_party
	var staged_button: CombatBorrowedButton = null
	if carries_latch:
		staged_button = source._borrowed_button.stage_for_party(staged_party)
	else:
		staged_button = CombatBorrowedButton.new()
		if not staged_button.bind_combat(staged_party, support._wardrobe, support._torn):
			staged_button = null
	if staged_button == null:
		return
	var staged_heals := CombatSeamstressPoolHeals.new()
	if not staged_heals.bind_patch_wardrobe(support._wardrobe, support._torn,
			support._wardrobe_snapshot, support._torn_snapshot):
		return
	staged_heals._borrowed_button = staged_button
	staged_heals._button_party = staged_party
	staged_heals._heal_receipt_number = source._heal_receipt_number if carries_latch else 0
	staged_heals._pending_new_party = false
	staged_transaction.bind_borrowed_button(staged_heals)
