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
    _test_authored_open_and_quotes()
    _test_first_copy_and_replay()
    _test_real_stitched_and_survivors()
    _test_insufficient_gold_and_leave()
    _test_stale_and_forged_inputs()
    _test_invalid_open()
    if failures.is_empty():
        print("run_unpicker_visit_test: PASS (", checks, " checks)")
    else:
        for failure in failures:
            printerr(failure)
        print("run_unpicker_visit_test: FAIL (", failures.size(), " failures)")
    quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)


func _deck() -> Array[String]:
    var deck := StarterCards.new().get_starting_deck()
    _check(deck.size() >= 12 and deck.count(STRIKE) == 2
            and deck.count(PRICK) == 2 and deck.count(POP) == 2,
            "authored real three-owner starter deck and duplicate copies")
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
    _check(_remove(replay, STRIKE, replay.read_state()) == receipt,
            "same-input separate instance replays exact complete receipt")
    var detached: Dictionary = receipt["source_snapshot"]
    detached["deck"].clear()
    var returned: Array = receipt["deck"]
    returned.clear()
    _check(first.read_state()["deck"] == expected and source["deck"] == before and deck == before,
            "caller, source snapshot and internal state do not alias returned receipt")
    _check(local_rng.state == local_before and randi() == global_next,
            "valid, refused, and replayed decisions consume no local/global RNG")


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
