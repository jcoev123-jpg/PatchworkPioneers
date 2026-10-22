class_name RunStitchedBattleHandEntry
extends RefCounted
## Scene-free admission of a committed run deck to the next Fight.
## Rest remains the authority for IDs, complete descriptors and the cursor;
## the caller's receipt must match its reconstructed canonical ledger.
## Invalid admission never draws from (or reseeds) the supplied run RNG.

## A successful result owns a fresh shuffled CombatDeck, a detached snapshot,
## and the validated RunRestStitchCards authority required by
## CombatStitchedCards.play_stitched(). It does NOT start a turn or play cards.
func admit_next_fight(deck_ids: Variant, descriptors: Variant,
        remaining_scraps: Variant, next_stitch_id: Variant,
        expected_receipt: Variant, run_rng: RandomNumberGenerator) -> Dictionary:
    var failure := {"ok": false}
    if run_rng == null or typeof(expected_receipt) != TYPE_STRING or expected_receipt.is_empty():
        return failure

    # The constructor copies inputs, enforces canonical authored half
    # definitions, exactly one owned copy of each descriptor, and ID serials.
    var run_cards := RunRestStitchCards.new(
        deck_ids, descriptors, remaining_scraps, next_stitch_id)
    if not run_cards.is_valid():
        return failure
    var snapshot := run_cards.get_snapshot()
    if snapshot["receipt"] != expected_receipt:
        return failure

    # Keep the canonical ordering, never the unvalidated caller's array.
    # CombatDeck's Fisher-Yates shuffle uses only this injected generator.
    var card_ids: Array[String] = []
    card_ids.assign(snapshot["deck"])
    var combat_deck := CombatDeck.new(card_ids, run_rng)
    return {
        "ok": true,
        "combat_deck": combat_deck,
        "run_cards": run_cards,
        "snapshot": snapshot.duplicate(true),
    }
