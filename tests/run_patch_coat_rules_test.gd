extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
    _test_catalog_and_all_wearers()
    _test_battle_tear_mend_and_rest()
    _test_rest_transfer_swap_and_replacement()
    _test_invalid_transactions_and_projection()
    _test_rng_and_detachment()
    if failures.is_empty():
        print("run_patch_coat_rules_test: PASS (", checks, " checks)")
    else:
        for failure in failures:
            printerr(failure)
        print("run_patch_coat_rules_test: FAIL (", failures.size(), " failures)")
    quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)


func _json(path: String) -> Variant:
    var source := FileAccess.get_file_as_string(path)
    _check(not source.is_empty(), path + " is readable")
    return JSON.parse_string(source)


func _fixture(scraps: int = 3, include_coat: bool = true) -> Dictionary:
    var definitions: Variant = _json("res://data/heroes/starter_party.json")
    var authored: Variant = _json("res://data/patches/m04_coat_patches.json")
    var slots: Variant = _json("res://data/patches/initial_patch_slots.json")
    if typeof(definitions) != TYPE_ARRAY or typeof(authored) != TYPE_ARRAY \
            or typeof(slots) != TYPE_ARRAY:
        _check(false, "authored fixture collections are arrays")
        return {}
    var names := {"warden": 40, "seamstress": 30, "tinker": 26}
    _check(definitions.size() == 3, "the starter roster contains three actors")
    if definitions.size() != 3:
        return {}
    for i in range(3):
        var entry: Dictionary = definitions[i]
        _check(names.has(entry.get("id")) and entry.get("max_hp") == names.get(entry.get("id")),
            "starter hero named identity and HP verified at position " + str(i + 1))
    var present := {}
    for slot_record in slots:
        if typeof(slot_record) == TYPE_DICTIONARY:
            present[slot_record.get("id")] = slot_record.get("slot")
    _check(present.get("stitched_badge") == "HEAD" and present.get("spare_spool") == "ARM",
        "original two catalog entries remain named and correctly slotted")
    _check(authored.size() == 1 and authored[0] is Dictionary
        and authored[0].get("id") == "quilted_coat"
        and authored[0].get("slot") == "COAT"
        and authored[0].get("max_hp_bonus") == 6
        and authored[0].size() == 3, "standalone authored Quilted Coat is exactly COAT +6")
    if authored.size() != 1 or not authored[0] is Dictionary:
        return {}
    var party_defs: Array = definitions.duplicate(true)
    for entry in party_defs:
        entry["max_hp"] = int(entry["max_hp"])
    var party := CombatParty.new(party_defs)
    _check(party.is_valid(), "real CombatParty accepts authored three heroes")
    if not party.is_valid():
        return {}
    var heroes: Array = party.get_heroes()
    for i in range(3):
        heroes[i]["statuses"] = {"bleed": i, "weak": 0, "exposed": 0}
    var torn := RunTornMending.new(heroes)
    var patch_defs: Array = []
    for entry in slots:
        patch_defs.append({"id": entry["id"], "slot": entry["slot"]})
    # Project the authored three-field rule down to wardrobe's strict
    # two-field identity/slot-only constructor, without changing its schema.
    patch_defs.append({"id": authored[0]["id"], "slot": authored[0]["slot"]})
    patch_defs.append({"id": "coat_extra", "slot": "COAT"})
    var owned := ["coat_extra", "stitched_badge", "spare_spool"]
    if include_coat:
        owned.append("quilted_coat")
    var wardrobe := RunPatchWardrobe.new(heroes, owned, patch_defs, scraps,
        117, ["warden_strike", "seamstress_prick"], 920151)
    _check(torn.is_valid() and wardrobe.is_valid(),
        "actual torn/mend and wardrobe services initialize with two-field definitions")
    if not torn.is_valid() or not wardrobe.is_valid():
        return {}
    _check(wardrobe.get_snapshot().definitions.get("quilted_coat") == "COAT"
        and not wardrobe.get_snapshot().definitions.has("max_hp_bonus"),
        "bonus field does not leak into RunPatchWardrobe definitions")
    return {"party": party, "torn": torn, "wardrobe": wardrobe, "coats": authored,
        "owned": owned, "definitions": patch_defs}


func _sew(w: RunPatchWardrobe, patch: String, wearer: String, op: String) -> Dictionary:
    return w.sew(patch, wearer, "COAT", op, w.get_snapshot())


func _project(f: Dictionary, caps: Array, label: String) -> void:
    var torn: RunTornMending = f.torn
    var w: RunPatchWardrobe = f.wardrobe
    var before_t := torn.read_state()
    var before_w := w.get_snapshot()
    var result := RunPatchCoatRules.project_health(before_t, w, f.coats)
    _check(result.get("ok") == true and result.get("heroes") is Array
        and result["heroes"].size() == 3, label + ": three detached heroes projected")
    if result.get("ok") != true or result["heroes"].size() != 3:
        return
    for i in range(3):
        var expected: Dictionary = before_t.heroes[i].duplicate(true)
        expected["max_hp"] = caps[i]
        _check(result.heroes[i] == expected,
            label + ": only derived cap changed for " + before_t.heroes[i]["id"])
    _check(torn.read_state() == before_t and w.get_snapshot() == before_w,
        label + ": preview cannot modify either service's full snapshot")
    _check(RunPatchCoatRules.project_health(torn.read_state(), w, f.coats) == result,
        label + ": repeated preview is exact, non-stacking and deterministic")


func _refresh(f: Dictionary, scraps: int) -> void:
    var w: RunPatchWardrobe = f.wardrobe
    var old := w.get_snapshot()
    _check(w.refresh_run_context(f.torn.read_state().heroes, old.owned, scraps,
        old.gold, old.cards, old), "run owner refreshes real wardrobe roster and purse")
    _check(w.get_snapshot().seed == old.seed and w.get_snapshot().gold == old.gold
        and w.get_snapshot().cards == old.cards and w.get_snapshot().worn == old.worn,
        "refresh does not change worn IDs, seed, cards or gold")


func _reject(w: RunPatchWardrobe, label: String, call: Callable) -> void:
    var prior := w.get_snapshot()
    var result: Dictionary = call.call()
    _check(result == {"ok": false, "state": prior},
        label + " is rejected with no receipt")
    _check(w.get_snapshot() == prior, label + " leaves the complete ledger intact")


func _test_catalog_and_all_wearers() -> void:
    var f := _fixture()
    if f.is_empty():
        return
    var w: RunPatchWardrobe = f.wardrobe
    _check(RunPatchCoatRules.new().has_method("project_health"),
        "public coat projection method is present")
    _project(f, [40, 30, 26], "pristine unworn")
    _check(_sew(w, "quilted_coat", "warden", "sew_w").get("ok") == true,
        "free owned COAT sew onto Warden is committed")
    _check(w.get_snapshot().scraps == 3 and w.project_active(f.torn.read_state()).active.warden == ["quilted_coat"],
        "genuine wardrobe slot and active wearing established without spending scraps")
    _project(f, [46, 30, 26], "Warden wears coat")
    _check(w.start_rest("first_rest", w.get_snapshot()).get("ok") == true, "legal Rest opened")
    _check(w.re_sew("quilted_coat", "warden", "seamstress", "first_rest",
        "move_s", w.get_snapshot()).get("ok") == true, "real move Warden to Seamstress")
    _project(f, [40, 36, 26], "Seamstress wears coat")
    _check(w.re_sew("quilted_coat", "seamstress", "tinker", "first_rest",
        "move_t", w.get_snapshot()).get("ok") == true, "real move Seamstress to Tinker")
    _project(f, [40, 30, 32], "Tinker wears coat")
    _check(w.get_snapshot().scraps == 1 and w.end_rest("first_rest",
        w.get_snapshot()).get("ok") == true, "two moves cost exactly two scraps and close Rest")


func _test_battle_tear_mend_and_rest() -> void:
    var f := _fixture(2)
    if f.is_empty():
        return
    var torn: RunTornMending = f.torn
    var w: RunPatchWardrobe = f.wardrobe
    _check(_sew(w, "quilted_coat", "warden", "before_tear").get("ok") == true,
        "Warden has genuinely sewn coat before battle")
    var starting: Array = torn.read_state().heroes
    var ending: Array = starting.duplicate(true)
    ending[0].hp = 0
    ending[0].block = 7
    ending[0].statuses.bleed = 3
    _check(torn.observe_battle_end("fight_a", starting, ending).get("ok") == true,
        "observed battle causes Warden first tear")
    _check(torn.read_state().heroes[0].hp == 0 and torn.read_state().heroes[0].max_hp == 37
        and torn.read_state().tear_counts.warden == 1,
        "tear applies actual -3 base max and HP zero with one recorded tear")
    var stale_before := w.get_snapshot()
    _check(not RunPatchCoatRules.project_health(torn.read_state(), w, f.coats).ok
        and w.get_snapshot() == stale_before,
        "projection fails closed while wardrobe still holds old base roster")
    _refresh(f, 2)
    _check(w.project_active(torn.read_state()).active.warden == []
        and w.get_snapshot().worn.warden.COAT == "quilted_coat",
        "existing wardrobe masks torn Warden while keeping patch sewn")
    _project(f, [37, 30, 26], "torn coat suppressed")
    var prior_t := torn.read_state()
    var bad_mend := torn.choose_mend("map_m", "m_bad", "warden", 1, 1,
        prior_t.heroes, true)
    _check(not bad_mend.ok and torn.read_state() == prior_t,
        "insufficient scrap mend cannot alter hero or claim receipt")
    var mend := torn.choose_mend("map_m", "m_good", "warden", 1, 2,
        torn.read_state().heroes, true)
    _check(mend.get("ok") == true and mend.get("remaining_scraps") == 0
        and mend.heroes[0].hp == 9 and mend.heroes[0].max_hp == 37,
        "real legal 2-scrap mend restores floor(37 / 4) = 9 HP, no coat heal")
    _refresh(f, mend.remaining_scraps)
    _check(w.project_active(torn.read_state()).active.warden == ["quilted_coat"]
        and w.get_snapshot().scraps == 0, "mend revives genuine active wearer without scrap underflow")
    _project(f, [43, 30, 26], "mend reactivates +6 without HP change")
    _check(torn.read_state().heroes[0].hp == 9
        and torn.read_state().tear_counts.warden == 1,
        "persistent base tear penalty survives equip and mend")

    var rest_f := _fixture(2)
    if rest_f.is_empty():
        return
    var rest_t: RunTornMending = rest_f.torn
    _check(_sew(rest_f.wardrobe, "quilted_coat", "warden", "rest_coat").ok,
        "Rest revival fixture has genuinely sewn coat")
    var battle: Array = rest_t.read_state().heroes
    var down: Array = battle.duplicate(true)
    down[0].hp = 0
    _check(rest_t.observe_battle_end("fight_rest", battle, down).ok,
        "Rest route witnesses separate genuine tear")
    _refresh(rest_f, 2)
    _project(rest_f, [37, 30, 26], "torn before Rest")
    _check(rest_t.apply_rest("rest_revival", rest_t.read_state().heroes, true).ok,
        "real Rest heal revives Warden independently from paid mend")
    _refresh(rest_f, 2)
    _check(rest_t.read_state().heroes[0].hp == 12, "Rest revival is separate 12 HP route")
    _project(rest_f, [43, 30, 26], "Rest revival activates +6")


func _test_rest_transfer_swap_and_replacement() -> void:
    var f := _fixture(3)
    if f.is_empty():
        return
    var w: RunPatchWardrobe = f.wardrobe
    _check(_sew(w, "quilted_coat", "warden", "w_coat").ok
        and _sew(w, "coat_extra", "seamstress", "s_extra").ok,
        "two distinct COAT patches occupy Warden and Seamstress")
    var original := w.get_snapshot()
    var recovery := RunRestRecovery.new(f.torn.read_state().heroes)
    _check(not recovery.is_consumed(), "Rest choice genuinely unconsumed")
    _check(w.start_rest("rest_swap", w.get_snapshot()).ok, "confirmed Rest session opens")
    var moved := w.re_sew("quilted_coat", "warden", "tinker", "rest_swap",
        "to_tinker", w.get_snapshot())
    _check(moved.ok and moved.receipt.exchanged_id == ""
        and moved.receipt.scrap_delta == -1 and w.get_snapshot().scraps == 2,
        "empty COAT transfer costs exactly one scrap and leaves no exchanged ID")
    _project(f, [40, 30, 32], "empty-slot transfer Tinker")
    var swapped := w.re_sew("quilted_coat", "tinker", "seamstress", "rest_swap",
        "swap_s", w.get_snapshot())
    var after := w.get_snapshot()
    _check(swapped.ok and swapped.receipt.exchanged_id == "coat_extra"
        and after.worn.seamstress.COAT == "quilted_coat"
        and after.worn.tinker.COAT == "coat_extra" and after.scraps == 1,
        "occupied COAT exchange costs one scrap, preserving both patch IDs")
    _project(f, [40, 36, 26], "occupied-slot swap Seamstress")
    _check(not recovery.is_consumed() and after.gold == original.gold
        and after.seed == original.seed and after.cards == original.cards
        and after.heroes == original.heroes and after.owned == original.owned
        and after.worn.warden.HEAD == original.worn.warden.HEAD
        and after.worn.tinker.ARM == original.worn.tinker.ARM,
        "both re-sews leave Rest action, other slots, base heroes and run ledger unchanged")
    _check(w.end_rest("rest_swap", w.get_snapshot()).ok, "Rest session closes")

    var replacement := _fixture(0)
    if replacement.is_empty():
        return
    var w2: RunPatchWardrobe = replacement.wardrobe
    _check(_sew(w2, "quilted_coat", "warden", "sew_original").ok,
        "separate replacement fixture wears genuine Quilted Coat")
    _project(replacement, [46, 30, 26], "before destructive replacement")
    var old := w2.get_snapshot()
    var replaced := _sew(w2, "coat_extra", "warden", "replace_coat")
    _check(replaced.ok and replaced.receipt.displaced_id == "quilted_coat"
        and replaced.receipt.scrap_delta == 1 and w2.get_snapshot().scraps == 1
        and not w2.get_snapshot().owned.has("quilted_coat")
        and w2.get_snapshot().worn.warden.COAT == "coat_extra",
        "occupied sew destroys displaced coat and gives exactly one scrap")
    _check(w2.get_snapshot().gold == old.gold and w2.get_snapshot().seed == old.seed
        and w2.get_snapshot().cards == old.cards and w2.get_snapshot().heroes == old.heroes,
        "replacement does not touch hero base max, cards, gold or RNG seed")
    _project(replacement, [40, 30, 26], "replaced coat grants no bonus")


func _test_invalid_transactions_and_projection() -> void:
    var f := _fixture(1)
    if f.is_empty():
        return
    var w: RunPatchWardrobe = f.wardrobe
    var t: RunTornMending = f.torn
    _reject(w, "wrong matching slot", func(): return w.sew(
        "quilted_coat", "warden", "HEAD", "wrong_slot", w.get_snapshot()))
    _reject(w, "unowned coat", func(): return w.sew(
        "not_owned", "warden", "COAT", "unowned", w.get_snapshot()))
    _check(_sew(w, "quilted_coat", "warden", "valid_sew").ok,
        "fresh legitimate sew still works following rejected slot and ownership")
    var stale := w.get_snapshot()
    _reject(w, "same patch cannot duplicate on another hero", func(): return w.sew(
        "quilted_coat", "seamstress", "COAT", "duplicate", w.get_snapshot()))
    _reject(w, "replayed sewing ID", func(): return w.sew(
        "coat_extra", "warden", "COAT", "valid_sew", w.get_snapshot()))
    _reject(w, "out-of-Rest re-sew", func(): return w.re_sew(
        "quilted_coat", "warden", "tinker", "rest_a", "move_valid", w.get_snapshot()))
    _check(w.start_rest("rest_a", w.get_snapshot()).ok, "valid Rest opens after rejection")
    _reject(w, "wrong Rest ID", func(): return w.re_sew(
        "quilted_coat", "warden", "tinker", "rest_bad", "move_valid", w.get_snapshot()))
    _reject(w, "re-sew with stale pre-Rest snapshot", func(): return w.re_sew(
        "quilted_coat", "warden", "tinker", "rest_a", "move_valid", stale))
    var forged := w.get_snapshot()
    forged.heroes[0].max_hp = 999
    _reject(w, "forged ledger snapshot", func(): return w.re_sew(
        "quilted_coat", "warden", "tinker", "rest_a", "move_valid", forged))
    _check(w.re_sew("quilted_coat", "warden", "tinker", "rest_a",
        "move_valid", w.get_snapshot()).ok,
        "fresh valid attempt succeeds after wrong rest and stale receipt")
    _reject(w, "replayed re-sew ID", func(): return w.re_sew(
        "quilted_coat", "tinker", "warden", "rest_a", "move_valid", w.get_snapshot()))
    _reject(w, "no scraps left", func(): return w.re_sew(
        "quilted_coat", "tinker", "warden", "rest_a", "insufficient", w.get_snapshot()))
    _project(f, [40, 30, 32], "rejected transactions leave Tinker coat active")
    var baseline_w := w.get_snapshot()
    var baseline_t := t.read_state()
    var forged_t: Dictionary = baseline_t.duplicate(true)
    forged_t.heroes[2].hp = 0
    _check(not RunPatchCoatRules.project_health(forged_t, w, f.coats).ok,
        "stale mismatched torn roster rejects without fabricating a bonus")
    forged_t = baseline_t.duplicate(true)
    forged_t.heroes[2].id = "foreign"
    _check(not RunPatchCoatRules.project_health(forged_t, w, f.coats).ok,
        "foreign wearer identity rejects")
    forged_t = baseline_t.duplicate(true)
    forged_t.tear_counts.tinker = 1
    _check(not RunPatchCoatRules.project_health(forged_t, w, f.coats).ok,
        "tear count and base maximum mismatch rejects")
    var bad_authored: Array = f.coats.duplicate(true)
    bad_authored[0].slot = "HEAD"
    _check(not RunPatchCoatRules.project_health(baseline_t, w, bad_authored).ok,
        "wrong authored coat slot rejects")
    bad_authored = f.coats.duplicate(true)
    bad_authored[0].max_hp_bonus = 6.5
    _check(not RunPatchCoatRules.project_health(baseline_t, w, bad_authored).ok,
        "fractional bonus drift rejects without truncation")
    bad_authored = f.coats.duplicate(true)
    bad_authored[0].max_hp_bonus = 99
    _check(not RunPatchCoatRules.project_health(baseline_t, w, bad_authored).ok,
        "fabricated coat amount rejects")
    _check(w.get_snapshot() == baseline_w and t.read_state() == baseline_t
        and f.coats[0].max_hp_bonus == 6,
        "all malformed projections leave services and authored catalog untouched")

    var no_coat := _fixture(2, false)
    if no_coat.is_empty():
        return
    _reject(no_coat.wardrobe, "coat definition does not imply ownership", func():
        return no_coat.wardrobe.sew("quilted_coat", "warden", "COAT",
            "unowned_quilt", no_coat.wardrobe.get_snapshot()))
    _project(no_coat, [40, 30, 26], "unowned/unsewn coat has no projected effect")
    _check(w.end_rest("rest_a", w.get_snapshot()).ok,
        "valid Rest end follows all failed operations")
    _reject(w, "closed Rest cannot re-sew", func(): return w.re_sew(
        "quilted_coat", "tinker", "warden", "rest_a", "after_end", w.get_snapshot()))


func _test_rng_and_detachment() -> void:
    seed(314159)
    var expected_draw := randi()
    seed(314159)
    var f := _fixture(2)
    if f.is_empty():
        return
    var w: RunPatchWardrobe = f.wardrobe
    var torn: RunTornMending = f.torn
    _check(_sew(w, "quilted_coat", "warden", "rng_sew").ok, "RNG fixture sews real coat")
    var before_w := w.get_snapshot()
    var before_t := torn.read_state()
    var before_author: Array = f.coats.duplicate(true)
    var a := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
    var b := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
    _check(a == b and a.ok and a.heroes[0].max_hp == 46,
        "identical repeated projections contain exactly +6 Warden max")
    a.heroes[0].max_hp = 999
    a.heroes[1].statuses.bleed = 999
    b.heroes[0].max_hp = 888
    _check(RunPatchCoatRules.project_health(torn.read_state(), w, f.coats).heroes[0].max_hp == 46
        and torn.read_state().heroes[1].statuses.bleed == 1
        and w.get_snapshot() == before_w and torn.read_state() == before_t
        and f.coats == before_author,
        "mutating detached nested return never corrupts services or input rules")
    _check(randi() == expected_draw,
        "neither fixture nor transactional previews consume global random draws")
