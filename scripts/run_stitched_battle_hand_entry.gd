class_name RunStitchedBattleHandEntry
extends RefCounted
## Scene-free admission of a committed run deck to the next Fight.
## Rest remains the authority for IDs, complete descriptors and the cursor;
## the caller's receipt must match its reconstructed canonical ledger.
## Invalid admission never draws from (or reseeds) the supplied run RNG.

const PATH_CARD_IDS: Array[String] = [
    "warden_bulwark_brace", "warden_lance_pin",
    "seamstress_leech_stitch", "seamstress_fray",
    "tinker_scope", "tinker_wind_up",
]

## A successful result owns a fresh shuffled CombatDeck, a detached snapshot,
## and the validated RunRestStitchCards authority required by
## CombatStitchedCards.play_stitched(). It does NOT start a turn or play cards.
## An optional Warden-only or complete three-hero claim augments only the
## battle deck, never the permanent Rest ledger.
func admit_next_fight(deck_ids: Variant, descriptors: Variant,
        remaining_scraps: Variant, next_stitch_id: Variant,
        expected_receipt: Variant, run_rng: RandomNumberGenerator,
        path_receipt: Variant = null) -> Dictionary:
    var failure := {"ok": false}
    if run_rng == null or typeof(expected_receipt) != TYPE_STRING or expected_receipt.is_empty():
        return failure

    # Recreate the complete authored claim before any shuffle or RNG use.
    # A partial or malformed trio cannot fall back to a Warden-only claim.
    var chosen: Dictionary = {}
    var chosen_trio: Dictionary = {}
    if path_receipt != null:
        if typeof(path_receipt) == TYPE_DICTIONARY and (path_receipt.has("paths") or path_receipt.has("deck")):
            chosen_trio = RunHeroPathLoadout.authenticate_receipt(path_receipt)
            if not chosen_trio.get("ok", false):
                return failure
        else:
            chosen = RunWardenPathChoice.authenticate_receipt(path_receipt)
            if not chosen.get("ok", false):
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

    # Neither Path card belongs in a permanent run/Rest ledger, regardless of
    # selection. Explicitly check both IDs rather than just the chosen one.
    for path_card_id in PATH_CARD_IDS:
        if snapshot["deck"].has(path_card_id):
            return failure

    # Keep canonical run ordering. Only the ephemeral combat deck gains the
    # selected card; Rest's snapshot, descriptors and receipt stay identical.
    # CombatDeck's Fisher-Yates shuffle uses only the injected generator.
    var card_ids: Array[String] = []
    card_ids.assign(snapshot["deck"])
    if not chosen.is_empty():
        card_ids.append(chosen["card_id"])
    if not chosen_trio.is_empty():
        card_ids.append_array(chosen_trio["card_ids"])
    var combat_deck := CombatDeck.new(card_ids, run_rng)
    var result := {
        "ok": true,
        "combat_deck": combat_deck,
        "run_cards": run_cards,
        "snapshot": snapshot.duplicate(true),
    }
    if not chosen.is_empty():
        result["battle_only_warden_path"] = chosen.duplicate(true)
    if not chosen_trio.is_empty():
        result["battle_only_hero_paths"] = chosen_trio.duplicate(true)
    return result
