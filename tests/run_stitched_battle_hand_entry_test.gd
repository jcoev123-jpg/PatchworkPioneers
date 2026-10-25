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
    _test_optional_path_admission()
    _test_optional_path_rejections()
    _test_trio_path_admission()
    _test_trio_path_rejections()
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

## A real unchanged run deck and a real Rest-stitched run both admit one
## selected Path card, without changing the authoritative permanent ledger.
func _path_receipt(path_id: String) -> Dictionary:
    var choice := RunWardenPathChoice.new()
    _check(choice.is_valid() and not choice.is_claimed(),
        path_id + " choice source is genuine")
    var selected := choice.choose(path_id)
    _check(selected.get("ok") == true and choice.is_claimed(),
        path_id + " selected exactly once")
    return selected

func _starting_ledger() -> Dictionary:
    var original := StarterCards.new().get_starting_deck()
    var ledger := RunRestStitchCards.new(original, {}, 6, 1)
    _check(ledger.is_valid(), "unmodified twelve-card ledger is genuinely valid")
    if not ledger.is_valid():
        return {}
    return ledger.get_snapshot()

func _counts(ids: Array) -> Dictionary:
    var result := {}
    for card_id in ids:
        result[card_id] = int(result.get(card_id, 0)) + 1
    return result

func _admit_path(ledger: Dictionary, rng: RandomNumberGenerator,
        path_receipt: Variant) -> Dictionary:
    return RunStitchedBattleHandEntry.new().admit_next_fight(
        ledger.deck, ledger.descriptors, ledger.remaining_scraps,
        ledger.next_stitch_id, ledger.receipt, rng, path_receipt)

func _test_optional_path_admission() -> void:
    var original := _starting_ledger()
    var stitched := _stitch()
    if original.is_empty() or stitched.is_empty():
        return
    for path_id in ["bulwark", "vanguard"]:
        var path_receipt := _path_receipt(path_id)
        if path_receipt.get("ok") != true:
            continue
        var selected_id: String = path_receipt.card.id
        var foreign_id := "warden_lance_pin" if path_id == "bulwark" else "warden_bulwark_brace"
        for ledger in [original, stitched]:
            var before_ledger: Dictionary = ledger.duplicate(true)
            var authoritative := RunRestStitchCards.new(
                ledger.deck, ledger.descriptors, ledger.remaining_scraps, ledger.next_stitch_id)
            _check(authoritative.is_valid() and authoritative.get_snapshot().receipt == ledger.receipt,
                "real %s %s ledger is canonical" % [path_id, "stitched" if ledger == stitched else "base"])
            if not authoritative.is_valid():
                continue
            var seed_value := 7133 if ledger == original else 7134
            var rng_a := _rng(seed_value)
            var rng_b := _rng(seed_value)
            var rng_before := rng_a.state
            var a := _admit_path(ledger, rng_a, path_receipt)
            var b := _admit_path(ledger, rng_b, path_receipt)
            _check(a.get("ok") == true and b.get("ok") == true,
                path_id + " same seed admits two real decks")
            if a.get("ok") != true or b.get("ok") != true:
                continue
            var deck_a: CombatDeck = a.combat_deck
            var deck_b: CombatDeck = b.combat_deck
            var expected_counts := _counts(ledger.deck)
            expected_counts[selected_id] = 1
            _check(_counts(_all(deck_a)) == expected_counts
                and _all(deck_a).size() == ledger.deck.size() + 1
                and _all(deck_a).count(selected_id) == 1
                and _all(deck_a).count(foreign_id) == 0,
                path_id + " deck holds run multiset plus exactly its own Path card")
            _check(a.snapshot == authoritative.get_snapshot()
                and b.snapshot == authoritative.get_snapshot()
                and a.run_cards.get_snapshot() == authoritative.get_snapshot()
                and b.run_cards.get_snapshot() == authoritative.get_snapshot()
                and ledger == before_ledger
                and not a.snapshot.deck.has(selected_id)
                and not a.snapshot.descriptors.has(selected_id),
                path_id + " preserves authoritative receipt, descriptors and deck")
            _check(a.has("battle_only_warden_path")
                and a.battle_only_warden_path.path_id == path_id
                and a.battle_only_warden_path.card_id == selected_id
                and a.battle_only_warden_path.receipt == path_receipt,
                path_id + " result explicitly carries detached battle-only claim")
            a.battle_only_warden_path.receipt.card.effects["test_mutation"] = 55
            _check(path_receipt == b.battle_only_warden_path.receipt
                and b.run_cards.get_snapshot() == authoritative.get_snapshot(),
                path_id + " battle-only receipt is deeply detached")
            _check(not deck_a.turn_active and deck_a.energy == 0
                and deck_a.hand.is_empty() and deck_a.discard_pile.is_empty(),
                path_id + " admission does not start a turn")
            _check(deck_a.draw_pile == deck_b.draw_pile
                and rng_a.state == rng_b.state and rng_a.state != rng_before,
                path_id + " shuffles reproducibly with only injected RNG")
            _check(deck_a.start_turn() and deck_b.start_turn()
                and deck_a.hand.size() == 5 and deck_a.energy == 3
                and deck_a.hand == deck_b.hand and deck_a.draw_pile == deck_b.draw_pile
                and rng_a.state == rng_b.state,
                path_id + " opening draw five, energy three and remaining order match")

            # Keep both turns active. Find the card solely through legitimate
            # extra draws; never put a test card directly into the shared hand.
            var drawn := 0
            while not deck_a.hand.has(selected_id) and drawn < ledger.deck.size() + 1:
                var next_a := deck_a.draw_extra(1)
                var next_b := deck_b.draw_extra(1)
                _check(next_a == 1 and next_b == 1,
                    path_id + " additional draw advances each real deck by one")
                drawn += 1
            _check(deck_a.hand.has(selected_id) and deck_b.hand.has(selected_id)
                and deck_a.hand == deck_b.hand and deck_a.draw_pile == deck_b.draw_pile
                and rng_a.state == rng_b.state,
                path_id + " selected Path card is legitimately held on matching hands")
            if not deck_a.hand.has(selected_id):
                continue
            var party := CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
            var enemies := CombatEnemies.new(_definitions("res://data/enemies/starter_enemies.json"))
            var pinned := CombatPinned.new()
            _check(party.is_valid() and enemies.is_valid()
                and party.get_hero(1).id == "warden"
                and party.get_hero(1).hp == 40
                and party.get_hero(2).id == "seamstress"
                and party.get_hero(3).id == "tinker"
                and enemies.get_enemy(1).hp == 12
                and enemies.get_enemy(2).hp == 12,
                path_id + " living legal party and enemy fixture")
            if not party.is_valid() or not enemies.is_valid():
                continue
            var before_party := party.get_heroes()
            var before_enemies := enemies.get_enemies()
            var before_hand := deck_a.hand.duplicate()
            var before_draw := deck_a.draw_pile.duplicate()
            var before_discard := deck_a.discard_pile.duplicate()
            var before_play_rng := rng_a.state
            var target := 0
            if path_id == "vanguard":
                target = 1
                _check(enemies.gain_block(1, 2),
                    "Lance Pin target receives real 2 Block before hit")
            var played := CombatWardenPathCards.new().play(
                deck_a, party, enemies, selected_id, target, path_receipt, pinned)
            _check(played.get("ok") == true and played.get("energy_spent") == 1
                and played.get("discarded") == selected_id
                and deck_a.energy == 2
                and deck_a.hand.size() == before_hand.size() - 1
                and deck_a.hand.count(selected_id) == before_hand.count(selected_id) - 1
                and deck_a.discard_pile == before_discard + [selected_id]
                and deck_a.draw_pile == before_draw and rng_a.state == before_play_rng,
                path_id + " authentic held cast spends one energy/discard, no RNG")
            if path_id == "bulwark":
                _check(played.get("block_gained") == 9
                    and party.get_hero(1).block == 9
                    and party.get_hero(1).hp == 40
                    and party.get_hero(2) == before_party[1]
                    and party.get_hero(3) == before_party[2]
                    and enemies.get_enemies() == before_enemies
                    and pinned.pinner_for_enemy(1) == "",
                    "Bulwark Brace grants only current Warden 9 Block")
            else:
                _check(played.get("damage") == 6
                    and played.get("block_absorbed") == 2
                    and played.get("hp_loss") == 4
                    and enemies.get_enemy(1).hp == 8
                    and enemies.get_enemy(1).block == 0
                    and enemies.get_enemy(2) == before_enemies[1]
                    and party.get_heroes() == before_party
                    and played.get("pinned_applied") == true
                    and pinned.pinner_for_enemy(1) == "warden"
                    and pinned.bonus_for_attack(enemies, 1, "seamstress") == 5,
                    "Lance Pin resolves six damage through Block and leaves cross-owner Pinned")
            _check(_counts(_all(deck_a)) == expected_counts
                and a.run_cards.get_snapshot() == authoritative.get_snapshot()
                and a.snapshot == authoritative.get_snapshot()
                and ledger == before_ledger and path_receipt == b.battle_only_warden_path.receipt,
                path_id + " cast retains permanent deck and Rest ledger exactly")

func _reject_path(candidate: Dictionary, rest_receipt: Variant,
        path_claim: Variant, reason: String) -> void:
    var before := candidate.duplicate(true)
    var path_before: Variant = path_claim.duplicate(true) if path_claim is Dictionary else path_claim
    var rng := _rng(9721)
    var before_rng := rng.state
    var result := RunStitchedBattleHandEntry.new().admit_next_fight(
        candidate.deck, candidate.descriptors, candidate.remaining_scraps,
        candidate.next_stitch_id, rest_receipt, rng, path_claim)
    _check(result == {"ok": false} and not result.has("combat_deck"),
        reason + " rejects without constructing a playable deck")
    _check(candidate == before and path_claim == path_before and rng.state == before_rng,
        reason + " leaves complete source ledgers, receipt and RNG unchanged")

func _test_optional_path_rejections() -> void:
    var ledger := _starting_ledger()
    if ledger.is_empty():
        return
    var bulwark := _path_receipt("bulwark")
    var vanguard := _path_receipt("vanguard")
    if bulwark.get("ok") != true or vanguard.get("ok") != true:
        return
    _reject_path(ledger, ledger.receipt, {}, "empty supplied Path receipt")
    _reject_path(ledger, ledger.receipt, [], "array supplied as Path receipt")
    _reject_path(ledger, ledger.receipt, 0, "integer supplied as Path receipt")
    _reject_path(ledger, ledger.receipt, false, "boolean supplied as Path receipt")
    var forged := bulwark.duplicate(true)
    forged["owner"] = "tinker"
    _reject_path(ledger, ledger.receipt, forged, "wrong Warden receipt owner")
    forged = bulwark.duplicate(true)
    forged["card"]["id"] = vanguard.card.id
    _reject_path(ledger, ledger.receipt, forged, "wrong selected card for Path")
    forged = bulwark.duplicate(true)
    forged["passive"]["starting_block"] = 16
    _reject_path(ledger, ledger.receipt, forged, "tampered replacement passive")
    forged = vanguard.duplicate(true)
    forged["starter_deck"].append("warden_lance_pin")
    _reject_path(ledger, ledger.receipt, forged, "forged extra Path copy in proposed deck")
    forged = bulwark.duplicate(true)
    forged["ok"] = 1
    _reject_path(ledger, ledger.receipt, forged, "bool versus int supplied claim")
    forged = bulwark.duplicate(true)
    forged.erase("display_name")
    _reject_path(ledger, ledger.receipt, forged, "missing receipt field")
    var twice := RunWardenPathChoice.new()
    _check(twice.choose("bulwark").get("ok") == true, "replay fixture claimed once")
    _reject_path(ledger, ledger.receipt, twice.choose("bulwark"),
        "unsuccessful duplicate choice receipt")
    _reject_path(ledger, "stale-receipt", bulwark, "authentic Path with stale Rest receipt")
    _reject_path(ledger, null, vanguard, "authentic Path with missing Rest receipt")
    var bad_ledger := ledger.duplicate(true)
    bad_ledger.deck.append("unknown_card")
    _reject_path(bad_ledger, bad_ledger.receipt, bulwark,
        "authentic Path with invalid Rest ledger")
    for card_id in ["warden_bulwark_brace", "warden_lance_pin"]:
        bad_ledger = ledger.duplicate(true)
        bad_ledger.deck.append(card_id)
        _reject_path(bad_ledger, bad_ledger.receipt, bulwark,
            "duplicate or foreign Path card already in persistent deck: " + card_id)
        _reject_path(bad_ledger, bad_ledger.receipt, vanguard,
            "foreign or duplicate Path card already in persistent deck: " + card_id)
    bad_ledger = ledger.duplicate(true)
    bad_ledger.deck.append("warden_bulwark_brace")
    bad_ledger.deck.append("warden_lance_pin")
    _reject_path(bad_ledger, bad_ledger.receipt, bulwark,
        "both Warden Path cards attempted in ledger")
    var no_rng := RunStitchedBattleHandEntry.new().admit_next_fight(
        ledger.deck, ledger.descriptors, ledger.remaining_scraps,
        ledger.next_stitch_id, ledger.receipt, null, bulwark)
    _check(no_rng == {"ok": false}, "null RNG rejects with authenticated Path receipt")
    _check(RunWardenPathChoice.authenticate_receipt(bulwark).get("ok") == true
        and _admit_path(ledger, _rng(9721), bulwark).get("ok") == true
        and _admit_path(ledger, _rng(9721), vanguard).get("ok") == true,
        "both authentic claims remain admissible after all failed preflights")


func _trio_claim(warden: String, seamstress: String, tinker: String) -> Dictionary:
    var source := RunHeroPathLoadout.new()
    var claim := source.choose({
        "warden": warden, "seamstress": seamstress, "tinker": tinker})
    _check(claim.get("ok") == true and source.is_claimed()
        and RunHeroPathLoadout.authenticate_receipt(claim).get("ok") == true,
        "authentic trio prerequisite " + warden + "/" + seamstress + "/" + tinker)
    return claim


func _test_trio_path_admission() -> void:
    var base := _starting_ledger()
    var stitched := _stitch()
    if base.is_empty() or stitched.is_empty():
        return
    var combinations := 0
    for warden in ["bulwark", "vanguard"]:
        for seamstress in ["bloodline", "unpicker"]:
            for tinker in ["sharpshot", "clockwork"]:
                combinations += 1
                var claim := _trio_claim(warden, seamstress, tinker)
                if claim.get("ok") != true:
                    continue
                var selected := [claim.paths.warden.card.id,
                    claim.paths.seamstress.card.id, claim.paths.tinker.card.id]
                _check(selected.size() == 3 and selected[0] != selected[1]
                    and selected[1] != selected[2] and selected[0] != selected[2],
                    "three distinct selected card IDs")
                for ledger in [base, stitched]:
                    var before: Dictionary = ledger.duplicate(true)
                    var authority := RunRestStitchCards.new(ledger.deck,
                        ledger.descriptors, ledger.remaining_scraps, ledger.next_stitch_id)
                    _check(authority.is_valid() and authority.get_snapshot().receipt == ledger.receipt,
                        "trio uses current canonical Rest ledger")
                    if not authority.is_valid():
                        continue
                    var seed_value := 8900 + combinations * 2 + (1 if ledger == stitched else 0)
                    var rng := _rng(seed_value)
                    var oracle_rng := _rng(seed_value)
                    var expected_ids: Array[String] = []
                    expected_ids.assign(ledger.deck)
                    expected_ids.append_array(selected)
                    var oracle := CombatDeck.new(expected_ids, oracle_rng)
                    var entered := _admit_path(ledger, rng, claim)
                    _check(entered.get("ok") == true, "trio admits base or stitched ledger")
                    if entered.get("ok") != true:
                        continue
                    var battle: CombatDeck = entered.combat_deck
                    _check(_counts(_all(battle)) == _counts(expected_ids)
                        and _all(battle).size() == ledger.deck.size() + 3
                        and _all(battle).count(selected[0]) == 1
                        and _all(battle).count(selected[1]) == 1
                        and _all(battle).count(selected[2]) == 1,
                        "trio adds exactly one chosen card per hero and preserves every run card")
                    _check(battle.draw_pile == oracle.draw_pile and rng.state == oracle_rng.state
                        and battle.hand.is_empty() and battle.energy == 0
                        and not battle.turn_active,
                        "admission makes exactly one seeded CombatDeck shuffle, no turn")
                    _check(entered.snapshot == authority.get_snapshot()
                        and entered.run_cards.get_snapshot() == authority.get_snapshot()
                        and ledger == before
                        and entered.snapshot.deck == ledger.deck
                        and entered.snapshot.descriptors == ledger.descriptors
                        and entered.snapshot.remaining_scraps == ledger.remaining_scraps
                        and entered.snapshot.next_stitch_id == ledger.next_stitch_id,
                        "trio leaves complete permanent ledger and receipt unchanged")
                    _check(not entered.snapshot.deck.has(selected[0])
                        and not entered.snapshot.deck.has(selected[1])
                        and not entered.snapshot.deck.has(selected[2])
                        and entered.battle_only_hero_paths.card_ids == selected
                        and entered.battle_only_hero_paths.receipt == claim,
                        "battle-only claim is carried without Path cards in Rest")
                    entered.battle_only_hero_paths.receipt.paths.tinker.passive["forged"] = true
                    _check(claim == RunHeroPathLoadout.new().choose({
                        "warden": warden, "seamstress": seamstress, "tinker": tinker}),
                        "returned trio receipt is detached from caller")
                    _check(battle.start_turn() and oracle.start_turn()
                        and battle.hand.size() == 5 and battle.energy == 3
                        and battle.hand == oracle.hand
                        and battle.draw_pile == oracle.draw_pile
                        and rng.state == oracle_rng.state,
                        "trio draws five and gains three energy reproducibly")
    _check(combinations == 8, "all eight trio combinations admitted on both ledgers")


func _test_trio_path_rejections() -> void:
    var ledger := _starting_ledger()
    if ledger.is_empty():
        return
    var claim := _trio_claim("bulwark", "bloodline", "sharpshot")
    if claim.get("ok") != true:
        return
    var forged := claim.duplicate(true)
    forged.paths.warden.passive.starting_block = 16
    _reject_path(ledger, ledger.receipt, forged, "forged trio passive")
    forged = claim.duplicate(true)
    forged.paths.seamstress.card.effects.bleed = 9
    _reject_path(ledger, ledger.receipt, forged, "forged trio card")
    forged = claim.duplicate(true)
    forged.paths.tinker.card.owner = "warden"
    _reject_path(ledger, ledger.receipt, forged, "forged trio owner")
    forged = claim.duplicate(true)
    forged.deck[0] = "tinker_scope"
    _reject_path(ledger, ledger.receipt, forged, "forged trio base deck")
    forged = claim.duplicate(true)
    forged.paths.erase("seamstress")
    _reject_path(ledger, ledger.receipt, forged, "missing trio hero")
    forged = claim.duplicate(true)
    forged.paths["extra"] = forged.paths.warden.duplicate(true)
    _reject_path(ledger, ledger.receipt, forged, "extra trio hero")
    var source := RunHeroPathLoadout.new()
    _check(source.choose({"warden": "bulwark", "seamstress": "bloodline",
        "tinker": "sharpshot"}).get("ok") == true, "trio replay fixture claimed")
    _reject_path(ledger, ledger.receipt, source.choose({"warden": "bulwark",
        "seamstress": "bloodline", "tinker": "sharpshot"}), "replayed trio selection")
    _reject_path(ledger, "stale-receipt", claim, "trio with stale Rest receipt")
    for card_id in RunStitchedBattleHandEntry.PATH_CARD_IDS:
        var corrupted := ledger.duplicate(true)
        corrupted.deck.append(card_id)
        _reject_path(corrupted, corrupted.receipt, claim,
            "permanent ledger contains Path card " + card_id)
    _check(_admit_path(ledger, _rng(9700), claim).get("ok") == true,
        "authentic trio remains admissible after failed preflights")
