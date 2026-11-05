extends SceneTree
## Gold-only Unpicker visit contract: detached receipts, exact source matching,
## one successful decision, authentic stitched-ledger ownership and no RNG.

const NODE := "route-unpicker-3"
const STRIKE := "warden_strike"
const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const MEND := "seamstress_mend"
const BOMB := "tinker_scrap_bomb"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
    _test_frayed_debt_removal()
    _test_authored_open_and_quotes()
    _test_first_copy_and_replay()
    _test_fresh_visit_identity()
    _test_real_stitched_and_survivors()
    _test_insufficient_gold_and_leave()
    _test_stale_and_forged_inputs()
    _test_invalid_open()
    _test_stitched_calm()
    _test_stitched_resolve_recovery()
    _test_stitched_leave_and_refusals()
    _test_stitched_invalid_open_and_detachment()
    _test_stitched_quote_actionability()
    _test_stitched_unpick_spare()
    if failures.is_empty():
        print("run_unpicker_visit_test: PASS (", checks, " checks)")
    else:
        for failure in failures:
            printerr(failure)
        print("run_unpicker_visit_test: FAIL (", failures.size(), " failures)")
    quit(0 if failures.is_empty() else 1)


func _test_frayed_debt_removal() -> void:
    var curse := MpwFrayedDebt.CARD_ID
    _check(MpwFrayedDebt.new().get_definition(curse).get("removable") == true, "authored curse is removable")
    var fixture := _two_composites()
    if fixture.is_empty():
        return
    var deck: Array = fixture["deck"].duplicate()
    deck.append(curse)
    deck.append(curse)
    var original := deck.duplicate()
    var registry: Dictionary = fixture["descriptors"].duplicate(true)
    for prior in [0, 1, 2]:
        var price: int = RunShopCardRemoval.BASE_PRICE + RunShopCardRemoval.PRICE_STEP * prior
        var visit := _make_visit(deck, price + 50, prior, registry, fixture["cursor"])
        _check(visit.is_valid(), "curse and mixed ledger open real Unpicker")
        var source := visit.read_state()
        var stale := source.duplicate(true)
        stale["gold"] += 1
        _reject(visit, curse, source["visit_id"], NODE, stale, "stale curse removal")
        var poor := _make_visit(deck, price - 1, prior, registry, fixture["cursor"])
        _check(poor.is_valid(), "poor curse visit valid before payment refusal")
        var poor_source := poor.read_state()
        _reject(poor, curse, poor_source["visit_id"], NODE, poor_source, "poor curse removal")
        seed(354)
        var next_draw := randi()
        seed(354)
        var paid := _remove(visit, curse, source)
        var expected := deck.duplicate()
        expected.remove_at(expected.find(curse))
        _check(paid.get("ok") == true and paid.get("deck") == expected
                and paid.get("deck", []).count(curse) == 1 and paid.get("removed_card_id") == curse,
                "real paid helper removes exactly one canonical curse")
        _check(paid.get("charged_gold") == price and paid.get("gold") == 50
                and paid.get("prior_removals") == prior + 1 and visit.is_consumed(), "canonical progressive debit and one-use receipt")
        _check(paid.get("descriptors") == registry and paid.get("next_stitch_id") == fixture["cursor"]
                and RunRestStitchCards.new(paid["deck"], registry, 0, fixture["cursor"]).is_valid(),
                "curse removal preserves composites and allocator")
        _reject(visit, curse, source["visit_id"], NODE, source, "replayed curse removal")
        var replay := _make_visit(deck, price + 50, prior, registry, fixture["cursor"])
        _same_stable_receipt(_remove(replay, curse, replay.read_state()), paid,
                "same-input independent-instance curse replay")
        _check(randi() == next_draw, "identical removal receipt replay consumes no randomness")
        _check(deck == original and registry == fixture["descriptors"], "curse removal leaves caller containers intact")


func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)


func _deck() -> Array[String]:
    var deck := StarterCards.new().get_starting_deck()
    deck.append("button_golem_pop_button")
    deck.append("button_golem_pop_button")
    deck.append("rag_duelist_velvet_feint_plus")
    _check(deck.size() >= 15 and deck.count(STRIKE) == 2
            and deck.count(PRICK) == 2 and deck.count(POP) == 2
            and deck.count("button_golem_pop_button") == 2
            and deck.count("rag_duelist_velvet_feint_plus") == 1,
            "authored real three-owner starter deck, duplicate new v3 cards, and genuine v3 plus")
    return deck


func _make_visit(deck: Variant, gold: Variant = 175, prior: Variant = 0,
        descriptors: Variant = {}, cursor: Variant = 1, node: Variant = NODE) -> RunUnpickerVisit:
    return RunUnpickerVisit.new(node, deck, gold, prior, descriptors, cursor)


func _remove(visit: RunUnpickerVisit, card: Variant, snapshot: Dictionary) -> Dictionary:
    return visit.remove_card(card, snapshot["visit_id"], snapshot["node_id"], snapshot)


func _leave(visit: RunUnpickerVisit, snapshot: Dictionary) -> Dictionary:
    return visit.leave(snapshot["visit_id"], snapshot["node_id"], snapshot)


func _reject(visit: RunUnpickerVisit, card: Variant, visit_id: Variant,
        node_id: Variant, snapshot: Variant, label: String, is_leave: bool = false) -> void:
    var before := visit.read_state()
    var used := visit.is_consumed()
    var result: Dictionary
    if is_leave:
        result = visit.leave(visit_id, node_id, snapshot)
    else:
        result = visit.remove_card(card, visit_id, node_id, snapshot)
    _check(result.get("ok", true) == false, label + ": rejected")
    _check(visit.read_state() == before and visit.is_consumed() == used,
            label + ": whole ledger, receipt and retry right identical")
    for key in ["deck", "gold", "prior_removals", "descriptors", "next_stitch_id", "receipt"]:
        _check(result.get(key) == before[key], label + ": unchanged returned " + key)
    _check(result.get("action") == "" and result.get("charged_gold") == 0,
            label + ": no phantom action or payment")


## Two receipts from independent instances with the same ledger differ only in
## the fresh visit identity and its embedded source snapshot; every stable
## economic field must still replay exactly.
func _same_stable_receipt(actual: Dictionary, expected: Dictionary, label: String) -> void:
    _check(actual.get("visit_id") != expected.get("visit_id")
            and not str(actual.get("visit_id", "")).is_empty()
            and not str(expected.get("visit_id", "")).is_empty(),
            label + ": independent instances expose distinct fresh visit identities")
    for key in expected:
        if key == "visit_id" or key == "source_snapshot":
            continue
        _check(actual.get(key) == expected[key],
                label + ": stable field " + str(key) + " replays exactly")


func _test_authored_open_and_quotes() -> void:
    var deck := _deck()
    for prior in [0, 1, 2]:
        var visit := _make_visit(deck, 500, prior)
        var source := visit.read_state()
        var quote := visit.quote()
        _check(visit.is_valid() and not visit.is_consumed(), "valid open prior %d" % prior)
        _check(quote["ok"] and quote["choices"] == ["remove_card", "leave"]
                and quote["price"] == 75 + 25 * prior, "only removal and Leave, exact quote %d" % prior)
        _check(source["deck"] == deck and source["gold"] == 500
                and source["prior_removals"] == prior and source["descriptors"] == {}
                and source["next_stitch_id"] == 1, "detached full opening ledger %d" % prior)
        _check(source["node_id"] == NODE and source["visit_id"] == quote["visit_id"]
                and not source["receipt"].is_empty(), "node/visit/receipt available to future owner")
        var paid := _remove(visit, STRIKE, source)
        _check(paid["ok"] and paid["charged_gold"] == 75 + 25 * prior
                and paid["gold"] == 500 - 75 - 25 * prior
                and paid["prior_removals"] == prior + 1, "exact single debit for quote %d" % prior)
        _check(visit.quote()["choices"].is_empty(), "consumed visit has no further choices")


func _test_first_copy_and_replay() -> void:
    var deck := _deck()
    var before := deck.duplicate()
    var first := _make_visit(deck, 150)
    var source := first.read_state()
    var local_rng := RandomNumberGenerator.new()
    local_rng.seed = 4317
    var local_before := local_rng.state
    seed(4317)
    var global_next := randi()
    seed(4317)
    var receipt := _remove(first, STRIKE, source)
    _check(receipt["ok"] and receipt["action"] == "remove_card"
            and receipt["removed_card_id"] == STRIKE, "owned card removal receipt")
    var expected := deck.duplicate()
    expected.remove_at(expected.find(STRIKE))
    _check(receipt["deck"] == expected and receipt["deck"].count(STRIKE) == 1
            and receipt["deck"].size() == before.size() - 1, "first copy only, survivors in order")
    _check(receipt["gold"] == 75 and receipt["prior_removals"] == 1
            and receipt["next_stitch_id"] == 1 and receipt["descriptors"] == {},
            "gold-only price/count and no stitching side effects")
    _check(receipt["source_snapshot"] == source and receipt["source_receipt"] == source["receipt"]
            and receipt["receipt"] != receipt["source_receipt"],
            "exact pre-commit proof accompanies changed authoritative ledger")
    _check(first.read_state()["deck"] == expected and first.is_consumed(),
            "service holds accepted result and locks visit")
    _reject(first, PRICK, source["visit_id"], NODE, source, "repeated callback")
    _reject(first, null, source["visit_id"], NODE, source, "repeated Leave", true)
    var replay := _make_visit(deck, 150)
    _same_stable_receipt(_remove(replay, STRIKE, replay.read_state()), receipt,
            "same-input separate instance replays the stable economic receipt")
    var detached: Dictionary = receipt["source_snapshot"]
    detached["deck"].clear()
    var returned: Array = receipt["deck"]
    returned.clear()
    _check(first.read_state()["deck"] == expected and source["deck"] == before and deck == before,
            "caller, source snapshot and internal state do not alias returned receipt")
    _check(local_rng.state == local_before and randi() == global_next,
            "valid, refused, and replayed decisions consume no local/global RNG")


## AC1: independently opened visits with an identical node, deck, descriptors,
## gold, prior removal count and cursor own distinct fresh identities, so an
## intent captured on the first can never authorize the second, and the second
## still completes with its own authenticated request.
func _test_fresh_visit_identity() -> void:
    var cases: Array = [{"deck": _deck(), "descriptors": {}, "cursor": 1}]
    var fixture := _two_composites()
    if not fixture.is_empty():
        cases.append({"deck": fixture["deck"], "descriptors": fixture["descriptors"],
                "cursor": fixture["cursor"]})
    for ledger in cases:
        var first := _make_visit(ledger["deck"], 175, 0, ledger["descriptors"], ledger["cursor"])
        var second := _make_visit(ledger["deck"], 175, 0, ledger["descriptors"], ledger["cursor"])
        _check(first.is_valid() and second.is_valid() and not first.is_consumed()
                and not second.is_consumed(), "independent same-ledger visits both open")
        var first_source := first.read_state()
        var second_source := second.read_state()
        _check(not first_source["visit_id"].is_empty() and not second_source["visit_id"].is_empty()
                and first_source["visit_id"] != second_source["visit_id"],
                "independent same-ledger visits expose distinct nonempty visit_ids")
        _check(second.quote()["visit_id"] == second_source["visit_id"]
                and second.quote()["ok"],
                "each visit quotes only its own fresh identity")
        _check(first_source["receipt"] == second_source["receipt"]
                and first_source["price"] == second_source["price"]
                and first_source["price"] == 75,
                "identical ledger keeps one stable economic receipt and quote")
        seed(9713)
        var next_draw := randi()
        seed(9713)
        _reject(second, STRIKE, first_source["visit_id"], NODE, first_source,
                "first visit's remove intent on second visit")
        _reject(second, null, first_source["visit_id"], NODE, first_source,
                "first visit's Leave intent on second visit", true)
        _check(randi() == next_draw,
                "cross-visit stale refusals consume no global RNG")
        var second_paid := _remove(second, STRIKE, second_source)
        _check(second_paid.get("ok") == true and second_paid.get("charged_gold") == 75
                and second_paid.get("prior_removals") == 1 and second.is_consumed(),
                "fresh authenticated removal completes on the second visit")
        _check(first.read_state() == first_source and not first.is_consumed(),
                "second visit's completion leaves the first visit fully unchanged")
        var first_paid := _remove(first, STRIKE, first_source)
        _check(first_paid.get("ok") == true and first_paid.get("charged_gold") == 75
                and first.is_consumed(),
                "first visit still completes with its own fresh identity")


func _two_composites() -> Dictionary:
    var base := _deck()
    var first := RunRestStitchCards.new(base, {}, 3, 1)
    _check(first.is_valid(), "authentic first Sewing Circle visit")
    if not first.is_valid():
        return {}
    var one := first.choose_stitch(base.find(PRICK), base.find(POP), first.get_snapshot())
    _check(one.get("ok") == true, "cross-owner first stitch succeeds")
    if not one.get("ok"):
        return {}
    var second := RunRestStitchCards.new(one["deck"], one["descriptors"], 3, one["next_stitch_id"])
    _check(second.is_valid(), "second stitched ledger authentic")
    if not second.is_valid():
        return {}
    var two := second.choose_stitch(one["deck"].find(MEND), one["deck"].find(BOMB),
            second.get_snapshot())
    _check(two.get("ok") == true, "cross-owner second stitch succeeds")
    if not two.get("ok"):
        return {}
    return {"deck": two["deck"], "descriptors": two["descriptors"],
            "cursor": two["next_stitch_id"], "one": one["stitched_id"],
            "two": two["stitched_id"]}


func _test_real_stitched_and_survivors() -> void:
    var fixture := _two_composites()
    _check(not fixture.is_empty(), "genuine two-composite fixture ready")
    if fixture.is_empty():
        return
    var deck: Array = fixture["deck"]
    var descriptors: Dictionary = fixture["descriptors"]
    _check(fixture["cursor"] == 3 and descriptors.size() == 2
            and deck.count(fixture["one"]) == 1 and deck.count(fixture["two"]) == 1,
            "two authentically owned composites and monotonic cursor")
    var visit := _make_visit(deck, 200, 0, descriptors, fixture["cursor"])
    _check(visit.is_valid(), "Unpicker accepts genuine two-composite ledger")
    var before := visit.read_state()
    var paid := _remove(visit, fixture["one"], before)
    var expected: Array = deck.duplicate()
    expected.remove_at(expected.find(fixture["one"]))
    _check(paid["ok"] and paid["charged_gold"] == 75 and paid["gold"] == 125
            and paid["prior_removals"] == 1, "composite costs 75 gold, increments once")
    _check(paid["deck"] == expected and paid["deck"].count(fixture["two"]) == 1
            and paid["deck"].count(STRIKE) == 2, "only chosen composite entry removed")
    _check(not paid["descriptors"].has(fixture["one"])
            and paid["descriptors"].size() == 1
            and paid["descriptors"][fixture["two"]] == descriptors[fixture["two"]]
            and paid["next_stitch_id"] == 3,
            "only owned descriptor retired, surviving composite preserved, cursor not reused")
    _check(RunRestStitchCards.new(paid["deck"], paid["descriptors"], 0, 3).is_valid(),
            "after composite removal ledger remains legally stitchable")
    var later := _make_visit(paid["deck"], paid["gold"], paid["prior_removals"],
            paid["descriptors"], paid["next_stitch_id"])
    _check(later.is_valid(), "new Unpicker accepts persisted stitched ledger")
    var later_source := later.read_state()
    var ordinary := _remove(later, STRIKE, later_source)
    _check(ordinary["ok"] and ordinary["charged_gold"] == 100
            and ordinary["gold"] == 25 and ordinary["prior_removals"] == 2
            and ordinary["deck"].count(STRIKE) == 1
            and ordinary["descriptors"] == paid["descriptors"]
            and ordinary["next_stitch_id"] == 3,
            "later ordinary card removes first copy and leaves other descriptor untouched")
    _check(deck == fixture["deck"] and descriptors == fixture["descriptors"],
            "both caller-owned stitched inputs remain unchanged")
    var modified: Dictionary = paid["descriptors"]
    modified[fixture["two"]]["first_half"]["effects"]["heal"] = 999
    _check(visit.read_state()["descriptors"][fixture["two"]] == descriptors[fixture["two"]],
            "nested descriptor receipt detached from service and caller")


func _test_insufficient_gold_and_leave() -> void:
    var deck := _deck()
    var poor := _make_visit(deck, 0)
    var before := poor.read_state()
    _check(poor.is_valid() and poor.quote()["price"] == 75, "zero gold still exposes honest quote")
    _reject(poor, STRIKE, before["visit_id"], NODE, before, "insufficient gold")
    var left := _leave(poor, before)
    _check(left["ok"] and left["action"] == "leave" and left["charged_gold"] == 0
            and left["deck"] == before["deck"] and left["descriptors"] == before["descriptors"]
            and left["gold"] == 0 and left["prior_removals"] == 0
            and left["next_stitch_id"] == before["next_stitch_id"]
            and left["receipt"] == before["receipt"] and poor.is_consumed(),
            "after insufficient removal Leave consumes once, with exact no-spend ledger")
    _reject(poor, STRIKE, before["visit_id"], NODE, before, "post-Leave replay")
    var funded := _make_visit(deck, 75)
    _check(_remove(funded, STRIKE, funded.read_state())["ok"],
            "funded new source after insufficient visit is removable (no carried penalty)")


func _test_stale_and_forged_inputs() -> void:
    var deck := _deck()
    var visit := _make_visit(deck, 200)
    var snap := visit.read_state()
    _reject(visit, STRIKE, "wrong-visit", NODE, snap, "wrong visit ID")
    _reject(visit, STRIKE, snap["visit_id"], "other-node", snap, "wrong node ID")
    _reject(visit, STRIKE, snap["visit_id"], NODE, {}, "omitted source snapshot")
    _reject(visit, STRIKE, snap["visit_id"], NODE, null, "null source snapshot")
    for field in ["deck", "gold", "prior_removals", "descriptors", "next_stitch_id",
            "receipt", "node_id", "visit_id", "consumed", "price"]:
        var stale := snap.duplicate(true)
        if field == "deck":
            stale[field][0] = "seamstress_prick"
        elif field == "descriptors":
            stale[field]["fake"] = {}
        elif field == "consumed":
            stale[field] = true
        elif field == "gold" or field == "prior_removals" or field == "next_stitch_id" or field == "price":
            stale[field] += 1
        else:
            stale[field] = "wrong"
        _reject(visit, STRIKE, snap["visit_id"], NODE, stale, "stale " + field)
    for card in ["", " ", "missing_card", "stitched_000001", null, 12, " " + STRIKE]:
        _reject(visit, card, snap["visit_id"], NODE, snap, "absent/forged card: " + str(card))
    _reject(visit, STRIKE, snap["visit_id"], "other-node", snap, "stale Leave node", true)
    _reject(visit, STRIKE, "wrong-visit", NODE, snap, "stale Leave visit", true)
    _reject(visit, STRIKE, snap["visit_id"], NODE, {}, "stale Leave snapshot", true)
    _check(_remove(visit, STRIKE, snap)["ok"], "valid removal retry succeeds after all rejections")


func _test_invalid_open() -> void:
    var deck := _deck()
    var invalid_ledgers: Array = [
        {"node": "", "deck": deck, "gold": 100, "prior": 0, "registry": {}, "cursor": 1},
        {"node": " " + NODE, "deck": deck, "gold": 100, "prior": 0, "registry": {}, "cursor": 1},
        {"node": " ", "deck": deck, "gold": 100, "prior": 0, "registry": {}, "cursor": 1},
        {"node": null, "deck": deck, "gold": 100, "prior": 0, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": [], "gold": 100, "prior": 0, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": ["unknown_card"], "gold": 100, "prior": 0, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": [STRIKE, 2], "gold": 100, "prior": 0, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": deck, "gold": -1, "prior": 0, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": deck, "gold": "100", "prior": 0, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": deck, "gold": 100, "prior": -1, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": deck, "gold": 100, "prior": "0", "registry": {}, "cursor": 1},
        {"node": NODE, "deck": deck, "gold": 100, "prior": 9223372036854775807, "registry": {}, "cursor": 1},
        {"node": NODE, "deck": deck, "gold": 100, "prior": 0, "registry": {}, "cursor": 0},
        {"node": NODE, "deck": deck, "gold": 100, "prior": 0, "registry": {}, "cursor": "1"},
        {"node": NODE, "deck": deck, "gold": 100, "prior": 0, "registry": {"stitched_000001": {}}, "cursor": 2},
    ]
    for entry in invalid_ledgers:
        var visit := _make_visit(entry["deck"], entry["gold"], entry["prior"], entry["registry"],
                entry["cursor"], entry["node"])
        var before := visit.read_state()
        _check(not visit.is_valid() and not visit.is_consumed()
                and not visit.quote()["ok"] and visit.quote()["choices"] == [],
                "invalid opening rejects malformed node/ledger: " + str(entry))
        _reject(visit, STRIKE, before["visit_id"], before["node_id"], before,
                "invalid-open removal " + str(entry["node"]))
        _reject(visit, STRIKE, before["visit_id"], before["node_id"], before,
                "invalid-open Leave " + str(entry["node"]), true)


# ------------------------------------------------------------------ Stitched calm

const HERO_IDS := ["warden", "seamstress", "tinker", "lantern_monk"]


## Four distinct ranked heroes with full nested data; only "fray" is the calmed field.
func _s_heroes(frays: Array) -> Array:
    var heroes: Array = []
    for i in 4:
        heroes.append({
            "id": HERO_IDS[i], "position": i + 1, "fray": frays[i],
            "hp": 20 + i, "max_hp": 30 + i, "flags": {"torn": i == 2, "marks": [i, "stitch"]},
            "parts": [{"id": "part_%d" % i, "slot": "arm", "state": {"worn": true, "uses": [1, 2]}}],
        })
    return heroes


func _s_open(heroes: Variant, gold: Variant = 100, price: Variant = 75,
        node: Variant = NODE) -> RunUnpickerVisit:
    return RunUnpickerVisit.open_stitched(node, heroes, gold, price)


func _s_calm(visit: RunUnpickerVisit, hero: Variant, snapshot: Dictionary) -> Dictionary:
    return visit.calm_hero(hero, snapshot["visit_id"], snapshot["node_id"], snapshot)


func _s_reject(visit: RunUnpickerVisit, hero: Variant, visit_id: Variant, node_id: Variant,
        snapshot: Variant, label: String, mode: String = "calm") -> void:
    var before := visit.read_state()
    var used := visit.is_consumed()
    var result: Dictionary
    if mode == "leave":
        result = visit.leave(visit_id, node_id, snapshot)
    elif mode == "remove":
        result = visit.remove_card(hero, visit_id, node_id, snapshot)
    else:
        result = visit.calm_hero(hero, visit_id, node_id, snapshot)
    _check(result.get("ok", true) == false, label + ": rejected")
    _check(visit.read_state() == before and visit.is_consumed() == used,
            label + ": whole ledger, heroes, wallet and retry right identical")
    for key in ["heroes", "gold", "price", "receipt", "visit_id", "node_id"]:
        _check(result.get(key) == before.get(key), label + ": unchanged returned " + key)
    _check(result.get("action") == "" and result.get("charged_gold") == 0
            and result.get("calmed_hero_id") == "",
            label + ": no phantom action, payment or calmed hero")


func _test_stitched_calm() -> void:
    var frays := [70, 20, 200, 0]
    var heroes := _s_heroes(frays)
    var original := heroes.duplicate(true)
    var visit := _s_open(heroes)
    _check(visit.is_valid() and not visit.is_consumed(), "stitched four-hero visit opens")
    var source := visit.read_state()
    var quote := visit.quote()
    _check(quote["ok"] and quote["choices"] == ["calm_hero", "leave"] and quote["price"] == 75
            and quote["calm_amount"] == 50 and quote["hero_ids"] == ["warden", "seamstress", "tinker"]
            and not quote["hero_ids"].has("lantern_monk")
            and quote["visit_id"] == source["visit_id"] and quote["node_id"] == NODE,
            "quote discloses the authorized caller price and exactly calm_hero + leave")
    _check(source["mode"] == "stitched" and source["heroes"] == original and source["gold"] == 100
            and source["price"] == 75 and source["node_id"] == NODE
            and not source["receipt"].is_empty() and not source["visit_id"].is_empty(),
            "read_state discloses node, visit, heroes, wallet and price")
    # A different quoted price is charged exactly: the price is external input.
    var other := _s_open(_s_heroes(frays), 100, 40)
    _check(other.is_valid() and other.quote()["price"] == 40
            and _s_calm(other, "warden", other.read_state())["charged_gold"] == 40
            and other.read_state()["gold"] == 60, "any positive affordable quote is charged exactly")
    var expected_fray := {"warden": 20, "seamstress": 0, "tinker": 150}
    for target in expected_fray:
        var fresh := _s_open(_s_heroes(frays))
        var snap := fresh.read_state()
        seed(8821)
        var next_draw := randi()
        seed(8821)
        var paid := _s_calm(fresh, target, snap)
        _check(paid["ok"] == true and paid["action"] == "calm_hero" and paid["calmed_hero_id"] == target
                and paid["fray_after"] == expected_fray[target]
                and paid["fray_before"] == frays[HERO_IDS.find(target)],
                "calm " + target + " by 50 clamped at zero")
        _check(paid["charged_gold"] == 75 and paid["gold"] == 25 and fresh.is_consumed()
                and paid["consumed"] == true, "exact 75 debit once and visit consumed: " + target)
        var expected_heroes := _s_heroes(frays)
        expected_heroes[HERO_IDS.find(target)]["fray"] = expected_fray[target]
        _check(paid["heroes"] == expected_heroes and paid["heroes"].size() == 4,
                "only " + target + " FRAY changed; every other hero and field preserved")
        _check(paid["node_id"] == NODE and paid["visit_id"] == snap["visit_id"]
                and paid["source_snapshot"] == snap and paid["source_receipt"] == snap["receipt"]
                and paid["receipt"] != paid["source_receipt"],
                "receipt bound to node/visit with pre-commit source proof: " + target)
        _check(fresh.quote()["choices"].is_empty() and not fresh.quote()["ok"],
                "consumed stitched visit offers nothing")
        _s_reject(fresh, target, snap["visit_id"], NODE, snap, "replayed calm " + target)
        _s_reject(fresh, null, snap["visit_id"], NODE, snap, "post-calm Leave " + target, "leave")
        _check(randi() == next_draw, "stitched calm and refusals draw no global RNG")
    # A hero with no FRAY cannot be charged for nothing and the visit stays open.
    var zero := _s_open(_s_heroes(frays))
    var zero_source := zero.read_state()
    _s_reject(zero, "lantern_monk", zero_source["visit_id"], NODE, zero_source,
            "calm hero already at zero FRAY")
    _check(_s_calm(zero, "warden", zero_source)["ok"] == true,
            "visit stays open after zero-FRAY refusal")
    _check(heroes == original, "caller hero input unchanged")


## Hero array from the unchanged _s_heroes helper with the Warden's native resolve set.
## A null resolve leaves the key absent, as older callers' hero dictionaries do.
func _s_resolve_heroes(fray: int, resolve: Variant) -> Array:
    var heroes := _s_heroes([fray, 0, 0, 0])
    if resolve != null:
        heroes[0]["resolve"] = resolve
    return heroes


func _test_stitched_resolve_recovery() -> void:
    # Main case (AC1): FRAY 70 + frantic, paid 75 of 100 -> FRAY 20, resolve cleared.
    var main_heroes := _s_resolve_heroes(70, "frantic")
    var main_original := main_heroes.duplicate(true)
    var main_visit := _s_open(main_heroes)
    var main_source := main_visit.read_state()
    seed(6137)
    var next_draw := randi()
    seed(6137)
    var main_paid := _s_calm(main_visit, "warden", main_source)
    var main_expected := _s_resolve_heroes(70, "frantic")
    main_expected[0]["fray"] = 20
    main_expected[0]["resolve"] = ""
    _check(main_paid["ok"] == true and main_paid["fray_before"] == 70 and main_paid["fray_after"] == 20
            and main_paid["calmed_hero_id"] == "warden", "AC1 frantic Warden calmed 70 -> 20")
    _check(main_paid["heroes"] == main_expected and main_paid["heroes"][0]["resolve"] == "",
            "AC1 only the paid hero's resolve cleared; roster otherwise exactly unchanged")
    _check(main_visit.read_state()["heroes"] == main_expected,
            "AC1 read_state exposes the cleared resolve")
    _check(main_paid["charged_gold"] == 75 and main_paid["gold"] == 25 and main_visit.is_consumed()
            and main_paid["consumed"] == true and main_visit.read_state()["gold"] == 25,
            "AC1 exactly one 75 debit (100 -> 25) and visit consumed")
    _check(main_paid["source_snapshot"] == main_source and main_paid["source_receipt"] == main_source["receipt"]
            and main_paid["receipt"] != main_paid["source_receipt"]
            and main_paid["visit_id"] == main_source["visit_id"] and main_paid["node_id"] == NODE
            and main_source["heroes"] == main_original and main_heroes == main_original,
            "AC1 receipt/source-snapshot provenance and caller detachment")
    _s_reject(main_visit, "warden", main_source["visit_id"], NODE, main_source, "replayed resolve calm")
    _check(randi() == next_draw, "resolve recovery and replay draw no global RNG")

    # AC2 table: every Unravelled trait clears strictly below 50, keeps at 50 and above.
    for unravel in StitchedS1BEffects.RESOLVE_TRAITS:
        for row in [[99, 49, ""], [100, 50, unravel], [130, 80, unravel]]:
            var heroes := _s_resolve_heroes(row[0], unravel)
            var visit := _s_open(heroes)
            var paid := _s_calm(visit, "warden", visit.read_state())
            var label: String = "%s %d -> %d" % [unravel, row[0], row[1]]
            var expected := _s_resolve_heroes(row[0], unravel)
            expected[0]["fray"] = row[1]
            expected[0]["resolve"] = row[2]
            _check(paid["ok"] == true and paid["fray_after"] == row[1] and paid["heroes"] == expected
                    and paid["heroes"][0]["resolve"] == row[2] and paid["charged_gold"] == 75
                    and paid["gold"] == 25, "resolve table " + label)

    # Contrasting resolve fixtures at 99 -> 49 stay untouched.
    for keep in ["steadfast", ""]:
        var kept := _s_resolve_heroes(99, keep)
        var kept_visit := _s_open(kept)
        var kept_paid := _s_calm(kept_visit, "warden", kept_visit.read_state())
        var kept_expected := _s_resolve_heroes(99, keep)
        kept_expected[0]["fray"] = 49
        _check(kept_paid["ok"] == true and kept_paid["heroes"] == kept_expected
                and kept_paid["heroes"][0]["resolve"] == keep,
                "resolve '" + keep + "' untouched after calm to 49")
    var bare := _s_resolve_heroes(99, null)
    var bare_visit := _s_open(bare)
    var bare_paid := _s_calm(bare_visit, "warden", bare_visit.read_state())
    var bare_expected := _s_resolve_heroes(99, null)
    bare_expected[0]["fray"] = 49
    _check(bare_paid["ok"] == true and not bare_paid["heroes"][0].has("resolve")
            and bare_paid["heroes"] == bare_expected, "missing resolve key is not invented")

    # Refusals never clear resolve or charge, and Leave stays free afterwards.
    var guard_heroes := _s_resolve_heroes(99, "hollow")
    var guard_visit := _s_open(guard_heroes)
    var guard := guard_visit.read_state()
    var stale := guard.duplicate(true)
    stale["gold"] += 1
    _s_reject(guard_visit, "warden", guard["visit_id"], NODE, stale, "stale snapshot keeps resolve")
    _s_reject(guard_visit, "warden", guard["visit_id"], "other-node", guard, "wrong node keeps resolve")
    _check(guard_visit.read_state()["heroes"][0]["resolve"] == "hollow"
            and guard_visit.read_state()["gold"] == 100, "refused calls leave hollow and gold intact")
    var poor := _s_open(_s_resolve_heroes(99, "hollow"), 74)
    var poor_source := poor.read_state()
    _check(poor.quote()["choices"] == ["leave"], "unaffordable quote offers only Leave")
    _s_reject(poor, "warden", poor_source["visit_id"], NODE, poor_source, "unfunded calm keeps resolve")
    var left := poor.leave(poor_source["visit_id"], NODE, poor_source)
    _check(left["ok"] == true and left["action"] == "leave" and left["charged_gold"] == 0
            and left["gold"] == 74 and left["heroes"][0]["resolve"] == "hollow"
            and left["heroes"][0]["fray"] == 99 and poor.is_consumed(),
            "Leave after refusal is free and keeps resolve")
    var zero_heroes := _s_resolve_heroes(0, "bitter")
    var zero := _s_open(zero_heroes)
    var zero_source := zero.read_state()
    _s_reject(zero, "warden", zero_source["visit_id"], NODE, zero_source, "zero-FRAY calm keeps resolve")


func _test_stitched_leave_and_refusals() -> void:
    var frays := [70, 20, 200, 0]
    var visit := _s_open(_s_heroes(frays))
    var snap := visit.read_state()
    # Cross-mode actions are refused in both directions.
    _s_reject(visit, STRIKE, snap["visit_id"], NODE, snap, "remove_card on stitched visit", "remove")
    var legacy := _make_visit(_deck(), 200)
    var legacy_snap := legacy.read_state()
    _check(not legacy_snap.has("mode") and not legacy_snap.has("heroes")
            and legacy.quote()["choices"] == ["remove_card", "leave"],
            "legacy visit shape carries no Stitched fields")
    var legacy_before := legacy.read_state()
    var cross := legacy.calm_hero("warden", legacy_snap["visit_id"], NODE, legacy_snap)
    _check(cross.get("ok") == false and legacy.read_state() == legacy_before
            and not legacy.is_consumed(), "calm_hero on legacy visit refused and changes nothing")
    _check(_remove(legacy, STRIKE, legacy_snap)["ok"], "legacy visit still removes after cross-mode refusal")
    # Wrong identity, node and snapshots.
    _s_reject(visit, "warden", "wrong-visit", NODE, snap, "wrong visit ID")
    _s_reject(visit, "warden", snap["visit_id"], "other-node", snap, "wrong node ID")
    _s_reject(visit, "warden", snap["visit_id"], NODE, {}, "omitted snapshot")
    _s_reject(visit, "warden", snap["visit_id"], NODE, null, "null snapshot")
    for field in ["heroes", "gold", "price", "receipt", "node_id", "visit_id", "consumed", "mode"]:
        var stale := snap.duplicate(true)
        if field == "heroes":
            stale["heroes"][0]["fray"] += 1
        elif field == "gold" or field == "price":
            stale[field] += 1
        elif field == "consumed":
            stale[field] = true
        else:
            stale[field] = "wrong"
        _s_reject(visit, "warden", snap["visit_id"], NODE, stale, "stale " + field)
        _s_reject(visit, "warden", snap["visit_id"], NODE, stale, "stale Leave " + field, "leave")
    _s_reject(visit, "warden", snap["visit_id"], "other-node", snap, "stale Leave node", "leave")
    _s_reject(visit, "warden", "wrong-visit", NODE, snap, "stale Leave visit", "leave")
    for target in ["", " ", "missing_hero", null, 12, " warden", "Warden"]:
        _s_reject(visit, target, snap["visit_id"], NODE, snap, "invalid target: " + str(target))
    # Independent visits never authorize each other.
    var twin := _s_open(_s_heroes(frays))
    var twin_snap := twin.read_state()
    _check(twin_snap["visit_id"] != snap["visit_id"] and twin_snap["receipt"] == snap["receipt"],
            "same-input stitched visits share the economic receipt but not the visit identity")
    _s_reject(twin, "warden", snap["visit_id"], NODE, snap, "other visit's intent")
    # Unaffordable quote: refused, visit stays open for Leave.
    var poor := _s_open(_s_heroes(frays), 74, 75)
    var poor_snap := poor.read_state()
    _check(poor.is_valid() and poor.quote()["ok"] and poor.quote()["price"] == 75,
            "unaffordable quote is still disclosed")
    _s_reject(poor, "warden", poor_snap["visit_id"], NODE, poor_snap, "unaffordable calm")
    var left := poor.leave(poor_snap["visit_id"], NODE, poor_snap)
    _check(left["ok"] == true and left["action"] == "leave" and left["charged_gold"] == 0
            and left["gold"] == 74 and left["heroes"] == _s_heroes(frays) and poor.is_consumed(),
            "Leave after refused calm spends nothing and keeps all four heroes")
    _s_reject(poor, "warden", poor_snap["visit_id"], NODE, poor_snap, "calm after Leave")
    _s_reject(poor, null, poor_snap["visit_id"], NODE, poor_snap, "repeated Leave", "leave")
    # Plain Leave on an affordable visit, after every refusal above.
    var left_ok := visit.leave(snap["visit_id"], NODE, snap)
    _check(left_ok["ok"] == true and left_ok["gold"] == 100 and left_ok["charged_gold"] == 0
            and left_ok["heroes"] == _s_heroes(frays) and left_ok["source_snapshot"] == snap
            and visit.is_consumed() and visit.quote()["choices"].is_empty(),
            "Leave consumes once, spends nothing and preserves all four heroes")
    # Exact-price boundary and retry after every refusal.
    var exact := _s_open(_s_heroes(frays), 75, 75)
    var exact_snap := exact.read_state()
    var exact_paid := _s_calm(exact, "seamstress", exact_snap)
    _check(exact_paid["ok"] == true and exact_paid["gold"] == 0 and exact_paid["charged_gold"] == 75,
            "exactly affordable quote spends the wallet to zero")


func _test_stitched_invalid_open_and_detachment() -> void:
    var frays := [70, 20, 200, 0]
    var bad_cases: Array = []
    var three := _s_heroes(frays)
    three.pop_back()
    bad_cases.append({"label": "three heroes", "heroes": three})
    var five := _s_heroes(frays)
    five.append(five[0].duplicate(true))
    bad_cases.append({"label": "five heroes", "heroes": five})
    bad_cases.append({"label": "null heroes", "heroes": null})
    bad_cases.append({"label": "dictionary heroes", "heroes": {}})
    var dup_id := _s_heroes(frays)
    dup_id[1]["id"] = "warden"
    bad_cases.append({"label": "repeated id", "heroes": dup_id})
    for blank in ["", " ", " warden", 5, null]:
        var bad_id := _s_heroes(frays)
        bad_id[0]["id"] = blank
        bad_cases.append({"label": "bad id " + str(blank), "heroes": bad_id})
    var not_dict := _s_heroes(frays)
    not_dict[2] = "tinker"
    bad_cases.append({"label": "hero not a dictionary", "heroes": not_dict})
    var dup_pos := _s_heroes(frays)
    dup_pos[3]["position"] = 1
    bad_cases.append({"label": "repeated rank", "heroes": dup_pos})
    for rank in [0, 5, -1, 1.0, "2"]:
        var bad_rank := _s_heroes(frays)
        bad_rank[1]["position"] = rank
        bad_cases.append({"label": "bad rank " + str(rank), "heroes": bad_rank})
    for fray in [-1, 201, 20.5, 20.0, "20", null]:
        var bad_fray := _s_heroes(frays)
        bad_fray[1]["fray"] = fray
        bad_cases.append({"label": "bad fray " + str(fray), "heroes": bad_fray})
    var no_fray := _s_heroes(frays)
    no_fray[0].erase("fray")
    bad_cases.append({"label": "missing fray", "heroes": no_fray})
    for entry in bad_cases:
        var bad := _s_open(entry["heroes"])
        _check(not bad.is_valid() and not bad.is_consumed() and not bad.quote()["ok"]
                and bad.quote()["choices"] == [], "invalid roster fails closed: " + entry["label"])
        var bad_state := bad.read_state()
        _check(bad.calm_hero("warden", bad_state["visit_id"], bad_state["node_id"], bad_state)["ok"] == false
                and bad.leave(bad_state["visit_id"], bad_state["node_id"], bad_state)["ok"] == false
                and not bad.is_consumed(), "invalid roster cannot calm or Leave: " + entry["label"])
    var wallet_price_cases: Array = [
        {"label": "negative gold", "gold": -1, "price": 75},
        {"label": "string gold", "gold": "100", "price": 75},
        {"label": "float gold", "gold": 100.0, "price": 75},
        {"label": "null gold", "gold": null, "price": 75},
        {"label": "zero price", "gold": 100, "price": 0},
        {"label": "negative price", "gold": 100, "price": -5},
        {"label": "fractional price", "gold": 100, "price": 75.5},
        {"label": "integral float price", "gold": 100, "price": 75.0},
        {"label": "string price", "gold": 100, "price": "75"},
        {"label": "null price", "gold": 100, "price": null},
    ]
    for entry in wallet_price_cases:
        _check(not _s_open(_s_heroes(frays), entry["gold"], entry["price"]).is_valid(),
                "invalid wallet or quote fails closed: " + entry["label"])
    for node in ["", " ", " " + NODE, NODE + " ", null, 7]:
        _check(not _s_open(_s_heroes(frays), 100, 75, node).is_valid(),
                "invalid node fails closed: " + str(node))
    _check(_s_open(_s_heroes(frays), 0, 75).is_valid() and _s_open(_s_heroes(frays), 100, 1).is_valid(),
            "zero wallet and one-gold quote are legal openings")
    # Detachment of caller input, state, quote and receipt, and no RNG draw.
    var local_rng := RandomNumberGenerator.new()
    local_rng.seed = 6113
    var local_before := local_rng.state
    seed(6113)
    var global_next := randi()
    seed(6113)
    var heroes := _s_heroes(frays)
    var visit := _s_open(heroes)
    heroes[0]["fray"] = 199
    heroes[0]["parts"][0]["state"]["uses"].clear()
    heroes.clear()
    _check(visit.read_state()["heroes"] == _s_heroes(frays),
            "caller mutation after open does not reach the service")
    var snap := visit.read_state()
    snap["heroes"][1]["flags"]["marks"].clear()
    snap["heroes"].clear()
    _check(visit.read_state()["heroes"] == _s_heroes(frays), "read_state nested heroes are detached")
    var fresh_snap := visit.read_state()
    var paid := _s_calm(visit, "warden", fresh_snap)
    _check(paid["ok"] == true, "detachment fixture calm succeeds")
    paid["heroes"][0]["parts"][0]["state"]["uses"].clear()
    paid["heroes"][2]["flags"].clear()
    paid["source_snapshot"]["heroes"].clear()
    var expected := _s_heroes(frays)
    expected[0]["fray"] = 20
    _check(visit.read_state()["heroes"] == expected and fresh_snap["heroes"] == _s_heroes(frays),
            "returned receipt nested heroes do not alias service or source snapshot")
    _check(local_rng.state == local_before and randi() == global_next,
            "Stitched open, refusals, calm and Leave consume no local/global RNG")
    var legacy := _make_visit(_deck(), 175)
    _check(legacy.is_valid() and legacy.quote()["choices"] == ["remove_card", "leave"]
            and legacy.quote()["price"] == 75, "legacy constructor is unaffected by Stitched mode")


## Quote lists only heroes the paid calm can help, and only to a party that can pay.
func _test_stitched_quote_actionability() -> void:
    var frays := [70, 20, 200, 0]
    var local_rng := RandomNumberGenerator.new()
    local_rng.seed = 7741
    var local_before := local_rng.state
    seed(7741)
    var global_next := randi()
    seed(7741)
    # Affordable: nonzero-FRAY heroes only, in held rank order; every listed ID is calmable.
    var visit := _s_open(_s_heroes(frays), 75, 75)
    var source := visit.read_state()
    var quote := visit.quote()
    _check(quote["ok"] and quote["hero_ids"] == ["warden", "seamstress", "tinker"]
            and quote["choices"] == ["calm_hero", "leave"] and quote["price"] == 75
            and quote["calm_amount"] == 50 and quote["visit_id"] == source["visit_id"]
            and quote["node_id"] == NODE, "exact 75/75 quotes the three frayed heroes")
    _check(visit.read_state() == source and not visit.is_consumed()
            and visit.quote() == quote, "quoting is read-only and repeatable")
    var returned: Array = quote["hero_ids"]
    returned.clear()
    _check(visit.quote()["hero_ids"] == ["warden", "seamstress", "tinker"],
            "returned hero_ids are detached from the service")
    for id in visit.quote()["hero_ids"]:
        var probe := _s_open(_s_heroes(frays), 75, 75)
        _check(_s_calm(probe, id, probe.read_state())["ok"] == true,
                "every quoted hero is actually calmable: " + str(id))
    # One gold short: Leave only, price and open identity preserved.
    var poor := _s_open(_s_heroes(frays), 74, 75)
    var poor_source := poor.read_state()
    var poor_quote := poor.quote()
    _check(poor_quote["ok"] and poor_quote["hero_ids"] == [] and poor_quote["choices"] == ["leave"]
            and poor_quote["price"] == 75 and poor_quote["calm_amount"] == 50
            and poor_quote["visit_id"] == poor_source["visit_id"] and poor_quote["node_id"] == NODE,
            "74 gold against 75 advertises only Leave and no heroes")
    var left := poor.leave(poor_source["visit_id"], NODE, poor_source)
    _check(left["ok"] == true and left["action"] == "leave" and left["charged_gold"] == 0
            and left["gold"] == 74 and poor.is_consumed() and poor.quote()["choices"] == []
            and poor.quote()["hero_ids"] == [] and not poor.quote()["ok"],
            "Leave stays free and accepted on an unaffordable quote")
    # No hero with FRAY: affordable but Leave only.
    var calm := _s_open(_s_heroes([0, 0, 0, 0]), 500, 75)
    var calm_source := calm.read_state()
    var calm_quote := calm.quote()
    _check(calm_quote["ok"] and calm_quote["hero_ids"] == [] and calm_quote["choices"] == ["leave"]
            and calm_quote["price"] == 75, "all-zero FRAY party advertises only Leave")
    var calm_left := calm.leave(calm_source["visit_id"], NODE, calm_source)
    _check(calm_left["ok"] == true and calm_left["charged_gold"] == 0 and calm_left["gold"] == 500
            and calm_left["heroes"] == _s_heroes([0, 0, 0, 0]) and calm.is_consumed(),
            "Leave on an all-zero FRAY party is accepted and free")
    # A single hero at 1 FRAY is enough, at rank position 3.
    var one := _s_open(_s_heroes([0, 0, 1, 0]), 75, 75)
    var one_quote := one.quote()
    _check(one_quote["hero_ids"] == ["tinker"] and one_quote["choices"] == ["calm_hero", "leave"],
            "1 FRAY hero is quoted with calm_hero and Leave")
    var one_paid := _s_calm(one, "tinker", one.read_state())
    _check(one_paid["ok"] == true and one_paid["fray_before"] == 1 and one_paid["fray_after"] == 0
            and one_paid["charged_gold"] == 75, "1 FRAY hero calms to zero for the quoted price")
    # A consumed or invalid visit still has empty choices and IDs.
    var done := _s_open(_s_heroes(frays), 75, 75)
    _s_calm(done, "warden", done.read_state())
    var done_quote := done.quote()
    _check(not done_quote["ok"] and done_quote["choices"] == [] and done_quote["hero_ids"] == [],
            "consumed visit quotes nothing")
    var bad_quote := _s_open(_s_heroes(frays), 75, 0).quote()
    _check(not bad_quote["ok"] and bad_quote["choices"] == []
            and (not bad_quote.has("hero_ids") or bad_quote["hero_ids"].is_empty()),
            "invalid visit quotes nothing and names no heroes")
    _check(local_rng.state == local_before and randi() == global_next,
            "quote, calm and Leave draw no local/global RNG")


# ------------------------------------------------------- Stitched spare unpicking

const ARMS_ID := "warden_arms_shield_catch"
const LEGS_ID := "warden_legs_rim_toss"
const E_FRAYS := [70, 20, 200, 0]


func _e_spares() -> Array:
    return [
        {"id": ARMS_ID, "slot": "arms", "tier": 1, "torn": false},
        {"id": LEGS_ID, "slot": "legs", "tier": 2, "torn": true},
    ]


func _e_open(satchel: Variant, scraps: Variant = 1, scrap_yield: Variant = 2,
        gold: Variant = 100, frays: Array = E_FRAYS) -> RunUnpickerVisit:
    return RunUnpickerVisit.open_stitched(NODE, _s_heroes(frays), gold, 75, satchel, scraps, scrap_yield)


func _e_unpick(visit: RunUnpickerVisit, index: Variant, snapshot: Dictionary) -> Dictionary:
    return visit.unpick_spare(index, snapshot["visit_id"], snapshot["node_id"], snapshot)


## One refused action of any kind: nothing in the visit, either balance or the
## satchel may change, and the visit stays exactly as open as it was.
func _e_reject(visit: RunUnpickerVisit, action: String, arg: Variant, visit_id: Variant,
        node_id: Variant, snapshot: Variant, label: String) -> void:
    var before := visit.read_state()
    var used := visit.is_consumed()
    var result: Dictionary
    if action == "unpick":
        result = visit.unpick_spare(arg, visit_id, node_id, snapshot)
    elif action == "calm":
        result = visit.calm_hero(arg, visit_id, node_id, snapshot)
    else:
        result = visit.leave(visit_id, node_id, snapshot)
    _check(result.get("ok", true) == false, label + ": rejected")
    _check(visit.read_state() == before and visit.is_consumed() == used,
            label + ": whole visit state identical")
    for key in ["heroes", "gold", "satchel", "scraps", "scrap_yield", "receipt"]:
        _check(result.get(key) == before.get(key), label + ": unchanged returned " + key)
    _check(result.get("action") == "" and result.get("charged_gold") == 0
            and result.get("credited_scraps", 0) == 0, label + ": no phantom action or credit")


func _test_stitched_unpick_spare() -> void:
    var spares := _e_spares()
    var original := _e_spares()
    var heroes := _s_heroes(E_FRAYS)
    var visit := RunUnpickerVisit.open_stitched(NODE, heroes, 100, 75, spares, 1, 2)
    _check(visit.is_valid() and not visit.is_consumed(), "expanded visit opens with two spares")
    var source := visit.read_state()
    var quote := visit.quote()
    _check(quote["ok"] and quote["choices"] == ["calm_hero", "unpick_spare", "leave"]
            and quote["spare_indices"] == [0, 1] and quote["scrap_yield"] == 2
            and quote["scraps"] == 1 and quote["price"] == 75
            and quote["visit_id"] == source["visit_id"] and quote["node_id"] == NODE
            and quote["spares"][0] == {"index": 0, "id": ARMS_ID, "slot": "arms", "tier": 1, "torn": false}
            and quote["spares"][1] == {"index": 1, "id": LEGS_ID, "slot": "legs", "tier": 2, "torn": true},
            "quote exposes calm, unpick, Leave, selectable spares and the quoted yield")
    _check(source["satchel"] == original and source["scraps"] == 1 and source["scrap_yield"] == 2
            and source["gold"] == 100 and not source["receipt"].is_empty(),
            "read_state carries satchel, scraps, yield and receipt")
    var plain := _s_open(_s_heroes(E_FRAYS), 100, 75)
    _check(plain.read_state()["receipt"] != source["receipt"],
            "receipt binds the satchel, scraps and yield")
    var other_yield := _e_open(_e_spares(), 1, 3)
    _check(other_yield.read_state()["receipt"] != source["receipt"],
            "receipt binds the quoted yield")
    spares[0]["tier"] = 3
    spares.clear()
    heroes[0]["fray"] = 1
    var returned_spares: Array = quote["spares"]
    returned_spares.clear()
    var returned_state := visit.read_state()
    returned_state["satchel"].clear()
    _check(visit.read_state() == source and visit.quote()["spare_indices"] == [0, 1],
            "caller, quote and read_state copies are detached")

    seed(5521)
    var next_draw := randi()
    seed(5521)
    var local_rng := RandomNumberGenerator.new()
    local_rng.seed = 5521
    var local_before := local_rng.state
    var paid := _e_unpick(visit, 0, source)
    _check(paid["ok"] == true and paid["action"] == "unpick_spare"
            and paid["removed_part"] == original[0] and paid["credited_scraps"] == 2
            and paid["scraps_before"] == 1 and paid["scraps_after"] == 3 and paid["scraps"] == 3,
            "index 0 unpicked into exactly the quoted 2 scraps (1 -> 3)")
    _check(paid["satchel"] == [original[1]] and paid["gold"] == 100 and paid["charged_gold"] == 0
            and paid["heroes"] == source["heroes"] and paid["node_id"] == NODE
            and paid["price"] == 75 and paid["scrap_yield"] == 2,
            "one spare gone; gold, every hero field and the quote unchanged")
    _check(paid["visit_id"] == source["visit_id"] and paid["source_snapshot"] == source
            and paid["source_receipt"] == source["receipt"] and paid["receipt"] != paid["source_receipt"]
            and paid["consumed"] == true and visit.is_consumed(),
            "source proof and new state returned; visit consumed once")
    _check(visit.quote()["choices"] == [] and not visit.quote()["ok"]
            and visit.quote()["spare_indices"] == [], "consumed visit offers nothing")
    _e_reject(visit, "unpick", 1, source["visit_id"], NODE, source, "replayed unpick")
    _e_reject(visit, "unpick", 0, source["visit_id"], NODE, source, "replayed unpick index 0")
    _e_reject(visit, "calm", "warden", source["visit_id"], NODE, source, "calm after unpick")
    _e_reject(visit, "leave", null, source["visit_id"], NODE, source, "Leave after unpick")
    _check(randi() == next_draw and local_rng.state == local_before,
            "unpick and refusals draw no local/global RNG")
    paid["satchel"].clear()
    paid["removed_part"]["tier"] = 3
    paid["source_snapshot"]["satchel"].clear()
    _check(visit.read_state()["satchel"] == [original[1]] and source["satchel"] == original
            and heroes.size() == 4, "returned receipt is detached from the service and source")

    # Index selects an instance even when IDs repeat; the survivor is the other one.
    var dup := [{"id": ARMS_ID, "slot": "arms", "tier": 1, "torn": false},
            {"id": ARMS_ID, "slot": "arms", "tier": 3, "torn": true}]
    var dup_visit := _e_open(dup, 0, 2)
    var dup_source := dup_visit.read_state()
    var dup_paid := _e_unpick(dup_visit, 1, dup_source)
    _check(dup_paid["ok"] and dup_paid["removed_part"]["tier"] == 3
            and dup_paid["satchel"] == [dup[0]] and dup_paid["scraps"] == 2,
            "index 1 removes only that duplicate-ID instance")
    var second := _e_open(_e_spares())
    var second_source := second.read_state()
    _check(second_source["visit_id"] != source["visit_id"]
            and second_source["receipt"] == source["receipt"],
            "same inputs: shared receipt but instance-bound visit ID")
    _e_reject(second, "unpick", 0, source["visit_id"], NODE, source, "other visit's intent")
    var second_paid := _e_unpick(second, 1, second_source)
    _check(second_paid["ok"] and second_paid["satchel"] == [original[0]] and second_paid["scraps"] == 3,
            "index 1 leaves the first spare")

    # Rejection table: every refusal changes nothing and Leave stays possible.
    var guarded := _e_open(_e_spares())
    var snap := guarded.read_state()
    var vid: String = snap["visit_id"]
    _e_reject(guarded, "unpick", 0, "wrong-visit", NODE, snap, "swapped visit ID")
    _e_reject(guarded, "unpick", 0, vid, "other-node", snap, "wrong node")
    _e_reject(guarded, "unpick", 0, vid, NODE, {}, "omitted snapshot")
    _e_reject(guarded, "unpick", 0, vid, NODE, null, "null snapshot")
    _e_reject(guarded, "unpick", 0, null, NODE, snap, "null visit ID")
    for field in ["scrap_yield", "scraps", "gold", "satchel", "receipt", "heroes"]:
        var forged := snap.duplicate(true)
        if field == "satchel":
            forged["satchel"][0]["tier"] = 3
        elif field == "receipt":
            forged["receipt"] = "forged"
        elif field == "heroes":
            forged["heroes"][0]["fray"] += 1
        else:
            forged[field] += 1
        _e_reject(guarded, "unpick", 0, vid, NODE, forged, "forged " + field)
    var swapped := snap.duplicate(true)
    swapped["satchel"][0]["id"] = LEGS_ID
    _e_reject(guarded, "unpick", 0, vid, NODE, swapped, "changed spare ID")
    for index in [-1, 2, 5, "0", 0.0, null, true, [0]]:
        _e_reject(guarded, "unpick", index, vid, NODE, snap, "invalid index " + str(index))
    _e_reject(guarded, "leave", null, vid, "other-node", snap, "Leave wrong node")
    var closed := _e_unpick(guarded, 1, snap)
    _check(closed["ok"] and closed["satchel"] == [original[0]] and closed["scraps"] == 3,
            "valid unpick succeeds after every refusal")

    # Invalid or partial opt-in inputs fail closed with no actionable choices.
    var bad_cases: Array = []
    var seven: Array = []
    for i in 7:
        seven.append({"id": ARMS_ID, "slot": "arms", "tier": 1, "torn": false})
    bad_cases.append(["seven spares", seven, 1, 2])
    bad_cases.append(["dictionary satchel", {}, 1, 2])
    bad_cases.append(["string satchel", "none", 1, 2])
    for scraps_bad in [-1, "1", 1.0, true]:
        bad_cases.append(["bad scraps " + str(scraps_bad), _e_spares(), scraps_bad, 2])
    for yield_bad in [0, -3, "2", 2.0, false]:
        bad_cases.append(["bad yield " + str(yield_bad), _e_spares(), 1, yield_bad])
    bad_cases.append(["scrap overflow", _e_spares(), 9223372036854775807, 1])
    bad_cases.append(["partial: satchel only", _e_spares(), null, null])
    bad_cases.append(["partial: satchel and scraps", _e_spares(), 1, null])
    bad_cases.append(["partial: scraps and yield", null, 1, 2])
    bad_cases.append(["partial: yield only", null, null, 2])
    bad_cases.append(["partial: scraps only", null, 1, null])
    var bad_spare_edits: Array = [
        ["spare missing torn", func(s): s.erase("torn")],
        ["spare extra key", func(s): s["extra"] = 1],
        ["slot outside four", func(s): s["slot"] = "hand"],
        ["slot not a string", func(s): s["slot"] = 2],
        ["tier zero", func(s): s["tier"] = 0],
        ["tier four", func(s): s["tier"] = 4],
        ["tier string", func(s): s["tier"] = "1"],
        ["tier float", func(s): s["tier"] = 1.0],
        ["torn string", func(s): s["torn"] = "no"],
        ["torn null", func(s): s["torn"] = null],
        ["empty id", func(s): s["id"] = ""],
        ["padded id", func(s): s["id"] = " " + ARMS_ID],
        ["numeric id", func(s): s["id"] = 5],
    ]
    for edit in bad_spare_edits:
        var spare_list := _e_spares()
        edit[1].call(spare_list[0])
        bad_cases.append([edit[0], spare_list, 1, 2])
    var not_dict := _e_spares()
    not_dict[1] = "arms"
    bad_cases.append(["spare not a dictionary", not_dict, 1, 2])
    for entry in bad_cases:
        var bad := _e_open(entry[1], entry[2], entry[3])
        var bad_state := bad.read_state()
        _check(not bad.is_valid() and not bad.is_consumed() and not bad.quote()["ok"]
                and bad.quote()["choices"] == [], "invalid expanded open fails closed: " + entry[0])
        _check(bad.unpick_spare(0, bad_state["visit_id"], NODE, bad_state).get("ok") == false
                and bad.calm_hero("warden", bad_state["visit_id"], NODE, bad_state).get("ok") == false
                and bad.leave(bad_state["visit_id"], NODE, bad_state).get("ok") == false
                and not bad.is_consumed(), "invalid expanded open cannot act: " + entry[0])
    var full := []
    for i in 6:
        full.append({"id": ARMS_ID, "slot": "arms", "tier": 1, "torn": false})
    _check(_e_open(full).is_valid() and _e_open([]).is_valid()
            and _e_open(_e_spares(), 0, 1).is_valid(), "six spares, empty satchel and zero scraps are legal")

    # Empty satchel: no unpick choice, unpick refused, Leave still works.
    var empty := _e_open([])
    var empty_source := empty.read_state()
    var empty_quote := empty.quote()
    _check(empty_quote["choices"] == ["calm_hero", "leave"] and empty_quote["spare_indices"] == []
            and empty_quote["spares"] == [], "empty satchel offers no unpick choice")
    _e_reject(empty, "unpick", 0, empty_source["visit_id"], NODE, empty_source, "unpick empty satchel")
    var empty_left := empty.leave(empty_source["visit_id"], NODE, empty_source)
    _check(empty_left["ok"] and empty_left["scraps"] == 1 and empty_left["satchel"] == [],
            "Leave works after refusal on an empty satchel")

    # Calm in the expanded visit changes only gold and one hero's FRAY by 50.
    var calm_visit := _e_open(_e_spares())
    var calm_source := calm_visit.read_state()
    var calmed := _s_calm(calm_visit, "warden", calm_source)
    var expected_heroes := _s_heroes(E_FRAYS)
    expected_heroes[0]["fray"] = 20
    _check(calmed["ok"] and calmed["action"] == "calm_hero" and calmed["gold"] == 25
            and calmed["charged_gold"] == 75 and calmed["heroes"] == expected_heroes
            and calmed["satchel"] == original and calmed["scraps"] == 1
            and calmed["scrap_yield"] == 2 and calmed["credited_scraps"] == 0
            and calmed["removed_part"] == {} and calm_visit.is_consumed(),
            "expanded calm charges only gold and calms only that hero; satchel and scraps unchanged")
    _e_reject(calm_visit, "unpick", 0, calm_source["visit_id"], NODE, calm_source, "unpick after calm")
    _e_reject(calm_visit, "calm", "seamstress", calm_source["visit_id"], NODE, calm_source,
            "second calm")
    # A party that cannot afford the gold quote can still unpick: no gold needed.
    var poor := _e_open(_e_spares(), 1, 2, 10)
    _check(poor.quote()["choices"] == ["unpick_spare", "leave"], "unaffordable calm leaves unpick and Leave")
    var poor_source := poor.read_state()
    _e_reject(poor, "calm", "warden", poor_source["visit_id"], NODE, poor_source, "unaffordable calm")
    var poor_paid := _e_unpick(poor, 0, poor_source)
    _check(poor_paid["ok"] and poor_paid["gold"] == 10 and poor_paid["scraps"] == 3,
            "unpick spends no gold")

    # Leave changes neither balance, hero nor spare.
    var leave_visit := _e_open(_e_spares())
    var leave_source := leave_visit.read_state()
    var left := leave_visit.leave(leave_source["visit_id"], NODE, leave_source)
    _check(left["ok"] and left["action"] == "leave" and left["gold"] == 100 and left["scraps"] == 1
            and left["satchel"] == original and left["heroes"] == _s_heroes(E_FRAYS)
            and left["charged_gold"] == 0 and left["credited_scraps"] == 0 and leave_visit.is_consumed(),
            "Leave spends nothing and keeps gold, scraps, spares and heroes")
    _e_reject(leave_visit, "unpick", 0, leave_source["visit_id"], NODE, leave_source, "unpick after Leave")
    _e_reject(leave_visit, "calm", "warden", leave_source["visit_id"], NODE, leave_source,
            "calm after Leave")

    # The original four-argument visit and the legacy constructor stay identical.
    var four := _s_open(_s_heroes(E_FRAYS), 100, 75)
    var four_state := four.read_state()
    _check(four.quote()["choices"] == ["calm_hero", "leave"] and not four_state.has("satchel")
            and not four_state.has("scraps") and not four.quote().has("spares"),
            "four-argument Stitched visit keeps its exact quote and state shape")
    var four_null := RunUnpickerVisit.open_stitched(NODE, _s_heroes(E_FRAYS), 100, 75, null, null, null)
    _check(four_null.is_valid() and four_null.read_state()["receipt"] == four_state["receipt"],
            "all-omitted optional inputs match the four-argument visit")
    var four_result := _e_unpick(four, 0, four_state)
    _check(four_result.get("ok") == false and four.read_state() == four_state and not four.is_consumed(),
            "four-argument visit refuses unpick and stays open")
    var legacy := _make_visit(_deck(), 175)
    var legacy_state := legacy.read_state()
    var legacy_result := legacy.unpick_spare(0, legacy_state["visit_id"], NODE, legacy_state)
    _check(legacy_result.get("ok") == false and legacy.read_state() == legacy_state
            and legacy.quote()["choices"] == ["remove_card", "leave"] and not legacy.is_consumed(),
            "legacy constructor refuses unpick and keeps card removal")
    var cross := _e_open(_e_spares())
    var cross_source := cross.read_state()
    _e_reject(cross, "calm", "warden", "wrong", NODE, cross_source, "calm with wrong ID")
    var removal := cross.remove_card(STRIKE, cross_source["visit_id"], NODE, cross_source)
    _check(removal.get("ok") == false and cross.read_state() == cross_source,
            "no cross-mode card removal on an expanded visit")
