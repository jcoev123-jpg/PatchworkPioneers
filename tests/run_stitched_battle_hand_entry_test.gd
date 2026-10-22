extends SceneTree
## Scene-free Rest -> seeded Fight -> combat resolver -> paid Shop regression.
const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const STITCH := "stitched_000001"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    _test_hydration()
    _test_two_target_play()
    _test_rejections()
    _test_paid_removal()
    for reason in failures:
        printerr(reason)
    print("run_stitched_battle_hand_entry_test: ",
        "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
    quit(0 if failures.is_empty() else 1)

func _check(valid: bool, label: String) -> void:
    checks += 1
    if not valid:
        failures.append(label)

func _rng(value: int = 1162026) -> RandomNumberGenerator:
    var result := RandomNumberGenerator.new()
    result.seed = value
    return result

func _definitions(path: String) -> Array:
    var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    _check(records is Array and not records.is_empty(), "authored roster " + path)
    if not records is Array:
        return []
    for record in records:
        var hp: Variant = record.get("max_hp")
        _check(typeof(hp) in [TYPE_FLOAT, TYPE_INT] and float(hp) == floor(float(hp)),
            "integral authored max_hp")
        record["max_hp"] = int(hp)
    return records

func _stitch(source: Array[String] = []) -> Dictionary:
    if source.is_empty():
        source = StarterCards.new().get_starting_deck()
        var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(
            "res://data/cards/starter_deck.json"))
        _check(source == authored, "ordered actual shared starter deck")
    var catalog := StarterCards.new()
    _check(source.has(PRICK) and source.has(POP)
        and catalog.get_definition(PRICK).owner == "seamstress"
        and catalog.get_definition(PRICK).effects == {"damage": 3, "bleed": 2}
        and catalog.get_definition(POP).owner == "tinker"
        and catalog.get_definition(POP).effects == {"damage": 5},
        "original cross-owner authored source cards")
    var rest := RunRestStitchCards.new(source, {}, 3)
    _check(rest.is_valid(), "valid original Rest source")
    if not rest.is_valid():
        return {}
    var made := rest.choose_stitch(source.find(PRICK), source.find(POP),
        rest.get_snapshot())
    _check(made.get("ok") == true, "real Rest choice succeeds")
    if not made.get("ok", false):
        return {}
    _check(made.stitched_id == STITCH and made.next_stitch_id == 2
        and made.remaining_scraps == 0 and made.descriptor.cost == 2
        and made.descriptor.half_ids == [PRICK, POP]
        and made.deck.count(STITCH) == 1
        and made.deck.count(PRICK) == source.count(PRICK) - 1
        and made.deck.count(POP) == source.count(POP) - 1
        and made.deck.size() == source.size() - 1,
        "Rest creates one cost-2 canonical ID, consuming originals")
    return made

func _admit(ledger: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    return RunStitchedBattleHandEntry.new().admit_next_fight(
        ledger.deck, ledger.descriptors, ledger.remaining_scraps,
        ledger.next_stitch_id, ledger.receipt, rng)

func _all(deck: CombatDeck) -> Array[String]:
    var combined: Array[String] = []
    combined.append_array(deck.draw_pile)
    combined.append_array(deck.hand)
    combined.append_array(deck.discard_pile)
    return combined

func _test_hydration() -> void:
    var receipt := _stitch()
    if receipt.is_empty():
        return
    var original := receipt.duplicate(true)
    var rng_a := _rng()
    var rng_b := _rng()
    var before_rng := rng_a.state
    var a := _admit(receipt, rng_a)
    var b := _admit(receipt, rng_b)
    _check(a.get("ok") == true and b.get("ok") == true,
        "two fresh seeded admissions with authentic receipt")
    if not a.get("ok", false) or not b.get("ok", false):
        return
    var deck_a: CombatDeck = a.combat_deck
    var deck_b: CombatDeck = b.combat_deck
    _check(deck_a != deck_b and a.run_cards != b.run_cards
        and a.snapshot == b.snapshot
        and a.snapshot == { "deck": receipt.deck, "descriptors": receipt.descriptors,
            "remaining_scraps": receipt.remaining_scraps,
            "next_stitch_id": receipt.next_stitch_id, "receipt": receipt.receipt },
        "fresh real decks and isolated complete authoritative snapshots")
    _check(not deck_a.turn_active and deck_a.energy == 0
        and deck_a.hand.is_empty() and deck_a.draw_pile.count(STITCH) == 1
        and deck_a.draw_pile.size() == receipt.deck.size(),
        "admission only shuffles; no turn, draw or effects")
    _check(deck_a.draw_pile == deck_b.draw_pile
        and rng_a.state == rng_b.state and rng_a.state != before_rng,
        "same seed makes identical ordered shuffled deck and RNG")
    _check(deck_a.start_turn() and deck_b.start_turn()
        and deck_a.energy == 3 and deck_b.energy == 3
        and deck_a.hand.size() == 5 and deck_a.hand == deck_b.hand
        and deck_a.draw_pile == deck_b.draw_pile
        and rng_a.state == rng_b.state,
        "deterministic first hand draws five and grants three energy")
    _check(_all(deck_a).count(STITCH) == 1
        and _all(deck_a).count(PRICK) == receipt.deck.count(PRICK)
        and _all(deck_a).count(POP) == receipt.deck.count(POP),
        "opening preserves only canonical owned card multiset")
    a.snapshot.descriptors[STITCH].first_half.effects.damage = 999
    a.snapshot.deck.clear()
    _check(a.run_cards.get_snapshot() == b.snapshot and receipt == original,
        "success snapshot mutations never corrupt owned ledger or inputs")

func _test_two_target_play() -> void:
    # Six real originals become five on Rest; the first draw must hold the
    # whole card without manual hand surgery or synthetic halves.
    var originals: Array[String] = [PRICK, POP, "warden_strike",
        "warden_brace", "tinker_tune_up", "seamstress_mend"]
    var receipt := _stitch(originals)
    if receipt.is_empty():
        return
    var entered := _admit(receipt, _rng(419))
    _check(entered.get("ok") == true, "five-card stitched deck admitted")
    if not entered.get("ok", false):
        return
    var deck: CombatDeck = entered.combat_deck
    var party := CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
    var enemies := CombatEnemies.new(_definitions("res://data/enemies/starter_enemies.json"))
    _check(party.is_valid() and enemies.is_valid()
        and party.get_hero(1).id == "warden" and party.get_hero(1).hp == 40
        and party.get_hero(2).id == "seamstress" and party.get_hero(2).hp == 30
        and party.get_hero(3).id == "tinker" and party.get_hero(3).hp == 26
        and enemies.get_enemy(1).hp == 12 and enemies.get_enemy(2).hp == 12,
        "real living owners at legal positions and two distinct living enemies")
    _check(deck.start_turn() and deck.hand.size() == 5
        and deck.hand.count(STITCH) == 1 and deck.energy == 3,
        "genuine five-card opening actually holds the composite")
    var heroes_before := party.get_heroes()
    var ledger_before: Dictionary = entered.run_cards.get_snapshot()
    var attacks := CombatAttackCards.new()
    var result := CombatStitchedCards.new(attacks).play_stitched(
        deck, party, enemies, entered.run_cards, STITCH, 1, 2)
    var expected := [
        {"ok": true, "hits": [{"position": 1, "damage": 3,
            "block_absorbed": 0, "hp_loss": 3, "statuses": {"bleed": 3}}]},
        {"ok": true, "hits": [{"position": 2, "damage": 8,
            "block_absorbed": 0, "hp_loss": 8, "statuses": {}}]},
    ]
    _check(result == {"ok": true, "halves": expected},
        "ordered real combat effects 3 damage + Bleed 3 and then 8 damage")
    _check(deck.energy == 1 and not deck.hand.has(STITCH)
        and deck.hand.size() == 4 and deck.discard_pile == [STITCH]
        and _all(deck).count(STITCH) == 1,
        "exact one two-energy cost and single whole-composite discard")
    _check(enemies.get_enemy(1).hp == 9
        and enemies.get_enemy(1).statuses == {"bleed": 3}
        and enemies.get_enemy(2).hp == 4
        and enemies.get_enemy(2).get("statuses", {}) == {}
        and attacks._tinker._consumed,
        "separate living targets, Seamstress passive and Tinker first-attack latch")
    _check(party.get_heroes() == heroes_before
        and entered.run_cards.get_snapshot() == ledger_before,
        "combat does not mutate hero roster or committed Rest ledger")


func _reject(candidate: Dictionary, receipt: Variant, reason: String) -> void:
    var before := candidate.duplicate(true)
    var rng := _rng(339)
    var rng_before := rng.state
    var result := RunStitchedBattleHandEntry.new().admit_next_fight(
        candidate.deck, candidate.descriptors, candidate.remaining_scraps,
        candidate.next_stitch_id, receipt, rng)
    _check(result == {"ok": false}, reason + " rejected without deck")
    _check(candidate == before and rng.state == rng_before,
        reason + " leaves entire candidate and run RNG untouched")

func _test_rejections() -> void:
    var issued := _stitch()
    if issued.is_empty():
        return
    _reject(issued, "stale-receipt", "stale receipt")
    _reject(issued, null, "missing receipt")
    _reject(issued, {"receipt": issued.receipt}, "invalid receipt type")
    var forged := issued.duplicate(true)
    forged.descriptors[STITCH].first_half.effects.bleed = 999
    _reject(forged, issued.receipt, "forged nested descriptor")
    var unowned := issued.duplicate(true)
    unowned.deck.append("stitched_999999")
    _reject(unowned, issued.receipt, "unowned composite ID")
    var duplicate := issued.duplicate(true)
    duplicate.deck.append(STITCH)
    _reject(duplicate, issued.receipt, "duplicate stitched ID")
    var missing := issued.duplicate(true)
    missing.descriptors.erase(STITCH)
    _reject(missing, issued.receipt, "missing registry entry")
    var orphan := issued.duplicate(true)
    orphan.deck.erase(STITCH)
    _reject(orphan, issued.receipt, "orphan descriptor registry")
    var currency := issued.duplicate(true)
    currency.remaining_scraps = -1
    _reject(currency, issued.receipt, "negative scraps")
    var serial := issued.duplicate(true)
    serial.next_stitch_id = 1
    _reject(serial, issued.receipt, "reused serial cursor")
    var stale := issued.duplicate(true)
    stale.deck[stale.deck.find("warden_strike")] = "warden_brace"
    _reject(stale, issued.receipt, "stale run deck with old receipt")
    var valid := _admit(issued, _rng(339))
    _check(valid.get("ok") == true and valid.snapshot.receipt == issued.receipt
        and valid.combat_deck.draw_pile.count(STITCH) == 1,
        "authentic replay succeeds after every rejected candidate")

func _test_paid_removal() -> void:
    var issued := _stitch()
    if issued.is_empty():
        return
    var before := issued.duplicate(true)
    var removed := RunShopCardRemoval.try_remove_with_stitch_ledger(
        issued.deck, issued.descriptors, issued.next_stitch_id, 75, 0, STITCH)
    var expected: Array = issued.deck.duplicate()
    expected.erase(STITCH)
    _check(removed.get("ok") == true and removed.price == 75
        and removed.gold == 0 and removed.prior_removals == 1
        and removed.deck == expected and removed.descriptors == {}
        and removed.next_stitch_id == 2,
        "real 75-gold Shop removal retires full card and registry, not cursor")
    if not removed.get("ok", false):
        return
    _check(issued == before and expected.count(STITCH) == 0
        and removed.deck.count(PRICK) == issued.deck.count(PRICK)
        and removed.deck.count(POP) == issued.deck.count(POP),
        "no run input drift or resurrected original halves on removal")
    var next_run := RunRestStitchCards.new(removed.deck, removed.descriptors,
        issued.remaining_scraps, removed.next_stitch_id)
    _check(next_run.is_valid(), "post-Shop ledger is canonical and retains serial")
    if not next_run.is_valid():
        return
    var next_receipt := next_run.get_snapshot()
    _check(next_receipt.receipt != issued.receipt and next_receipt.next_stitch_id == 2,
        "paid Shop retirement changes receipt without reusing serial")
    _reject(next_receipt, issued.receipt, "obsolete pre-Shop receipt")
    var rng := _rng(440)
    var admitted := _admit(next_receipt, rng)
    _check(admitted.get("ok") == true, "post-Shop ledger enters later battle")
    if not admitted.get("ok", false):
        return
    var deck: CombatDeck = admitted.combat_deck
    _check(deck.start_turn() and deck.energy == 3 and deck.hand.size() == 5
        and _all(deck).size() == expected.size() and not _all(deck).has(STITCH)
        and admitted.snapshot.descriptors == {}
        and admitted.snapshot.next_stitch_id == 2,
        "seeded later hand never revives retired composite or registry")
    var later_rest := RunRestStitchCards.new(next_receipt.deck,
        next_receipt.descriptors, 3, next_receipt.next_stitch_id)
    var subsequent := later_rest.choose_stitch(next_receipt.deck.find(PRICK),
        next_receipt.deck.find(POP), later_rest.get_snapshot())
    _check(subsequent.get("ok") == true
        and subsequent.stitched_id == "stitched_000002"
        and subsequent.next_stitch_id == 3,
        "fresh Rest after paid removal allocates next serial, not removed serial")
