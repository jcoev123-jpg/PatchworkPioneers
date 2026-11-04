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
    _test_stitched_leave_and_refusals()
    _test_stitched_invalid_open_and_detachment()
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
            and quote["calm_amount"] == 50 and quote["hero_ids"] == HERO_IDS
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
