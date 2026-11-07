extends SceneTree
## S10: source-keyed, accepted Walk consequences are witnessed on the real mounted screen.
var failures: Array[String] = []
var checks := 0
var coverage: Dictionary = {}
const AREA := {"pin_nest": "walls", "borrowed_shape": "walls",
    "biting_bundle": "floorboards", "pattern_scraps": "walls", "sewn_threshold": "walls"}

func _initialize() -> void:
    _run.call_deferred()

func check(ok: bool, note: String) -> void:
    checks += 1
    if not ok:
        failures.append(note)

func _party(equipped: bool = true) -> Array:
    var config: Dictionary = StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
    var heroes: Array = config.heroes.duplicate(true)
    var head := "seamstress_mending_knot_hat"
    var arm := "seamstress_thread_prick_needle"
    if not equipped:
        for id in StitchedWalkCurios.parts():
            var part: Dictionary = StitchedWalkCurios.parts()[id]
            if part.slot == "head" and not id in ["seamstress_mending_knot_hat", "seamstress_scarlet_knot_hat"]:
                head = id
            if part.slot == "arms" and not id in ["seamstress_thread_prick_needle",
                    "seamstress_needle_rain_needle", "needle_wasp_stinger",
                    "sewing_machine_colossus_needle_arm", "rag_duelist_arms_needle_prick"]:
                arm = id
    for index in heroes.size():
        heroes[index].merge({"rank": index + 1, "hp": int(heroes[index].max_hp) - 8,
            "lost": false, "fray": 0}, true)
    heroes[0].parts.head = {"id": head, "tier": 1, "torn": false}
    heroes[0].parts.arms = {"id": arm, "tier": 1, "torn": false}
    return heroes

func _start(seed_number: int, area: String, equipped: bool = true) -> StitchedWalkRules:
    var heroes := _party(equipped)
    var pockets := {}
    for hero in heroes:
        pockets[hero.id] = ["pins", "dye"] if hero == heroes[0] else []
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_number
    return StitchedWalkRules.start(rng, area, heroes, pockets)

func _act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
    var input := {"kind": kind, "actor": walk.snapshot().viewpoint}
    input.merge(extra, true)
    return walk.act(input, walk.snapshot())

func _find_curio(walk: StitchedWalkRules, id: String) -> Dictionary:
    for curio in walk.snapshot().curios:
        if curio.id == id:
            return curio
    return {}

func _approach_rules(walk: StitchedWalkRules, curio: Dictionary) -> void:
    while walk.snapshot().step < curio.step:
        check(_act(walk, "forward").ok, "seed schedule remains traversable")

## A bounded, reproducible seed search through REAL scheduled instances and rule receipts.
## Returns which sequential pin pull witnessed the requested result.
func _witness(id: String, desired: String) -> Dictionary:
    for seed_number in 256:
        var walk := _start(seed_number, AREA[id])
        if walk == null:
            continue
        var curio := _find_curio(walk, id)
        if curio.is_empty():
            continue
        _approach_rules(walk, curio)
        if id == "borrowed_shape":
            var inspected := _act(walk, "curio", {"target": curio.instance, "choice": "inspect"})
            if not inspected.ok or inspected.events.is_empty():
                continue
            var truth: bool = inspected.events[0].get("mimic", false)
            if desired == ("inspect_true" if truth else "inspect_false"):
                return {"seed": seed_number, "pull": 0}
            if desired.begins_with("inspect_"):
                continue
        var choice: String = {"pin_nest": "pull", "borrowed_shape": "take",
            "biting_bundle": "reach", "pattern_scraps": "read", "sewn_threshold": "unpick"}[id]
        for pull in (4 if id == "pin_nest" else 1):
            var before := walk.snapshot()
            var result := _act(walk, "curio", {"target": curio.instance, "choice": choice})
            if not result.ok:
                break
            for index in range(before.pending.size(), result.snapshot.pending.size()):
                var effect: Dictionary = result.snapshot.pending[index]
                if effect.get("source") != curio.instance:
                    continue
                var label: String = str(effect.kind)
                if label == "curio_loot":
                    label = str(effect.effects.kind)
                if label == desired:
                    return {"seed": seed_number, "pull": pull}
            if walk.curio_choices(curio.instance).is_empty():
                break
    return {}

func _mount(seed_number: int, id: String, equipped: bool = true) -> StitchedWalkScreen:
    var rules := _start(seed_number, AREA[id], equipped)
    if rules == null:
        check(false, "real rule fixture starts")
        return null
    var screen := StitchedWalkScreen.new()
    check(screen._load_art(), "walk art and curio catalog load")
    screen.walk = rules
    screen.expected = rules.snapshot()
    root.add_child(screen)
    await process_frame
    screen.set_reduced_motion(true)
    var curio := _find_curio(rules, id)
    check(not curio.is_empty(), "selected seed actually schedules " + id)
    if curio.is_empty():
        screen.free()
        return null
    while screen.expected.step < curio.step:
        var count := screen.receipts.size()
        screen.forward_button.pressed.emit()
        check(screen.receipts.size() == count + 1 and screen.receipts.back().ok,
            "real WALK ON reaches scheduled instance")
    check(screen.current_curio().get("instance") == curio.instance
        and screen.event_panel.visible and screen.stage.figure_nodes.has("curio"),
        "actual mounted first-person curio, no injected current event")
    return screen

func _choose(screen: StitchedWalkScreen, choice: String) -> Dictionary:
    var previous := screen.walk.snapshot()
    var count := screen.receipts.size()
    var event: Button = null
    for button in screen.event_buttons:
        if button.text == StitchedWalkScreen.CHOICE_CAPTIONS[choice]:
            event = button
            break
    check(event != null and event.is_visible_in_tree() and not event.disabled,
        "only visible legal %s choice can be clicked" % choice)
    if event == null:
        return {}
    event.grab_focus()
    check(screen.walk.snapshot() == previous and screen.receipts.size() == count,
        "focus does not spend RNG, WHIRR or receipts")
    event.pressed.emit()
    check(screen.receipts.size() == count + 1 and screen.receipts.back().ok,
        "one enabled event click yields exactly one accepted receipt")
    if screen.receipts.size() != count + 1:
        return {}
    var result: Dictionary = screen.receipts.back()
    var current := screen.walk.snapshot()
    check(current == result.snapshot and screen.expected == current and current.rng == screen.walk._rng.state,
        "accepted click matches authoritative complete snapshot and RNG")
    var acted := ""
    for curio in previous.curios:
        if curio.step == previous.step and not curio.get("resolved", false):
            acted = str(curio.instance)
            break
    check(not acted.is_empty(), "accepted action had a real active source")
    var source_event := false
    for e in result.events:
        if e.get("kind") == "curio_choice" and e.get("source") == acted and e.get("choice") == choice:
            source_event = true
    check(source_event, "accepted receipt names acted source and choice")
    var line: String = screen.feedback.text
    check(not line.is_empty() and not line.contains("You chose to") and not line.contains("_"),
        "mounted recap is readable, source-specific, not raw IDs or old generic choice")
    check(screen.feedback.get_theme_font_size("font_size") >= 18
        and screen.feedback.max_lines_visible == 2
        and screen.feedback.tooltip_text == line and screen.feedback.size.y >= 50,
        "two-line bone-ink result keeps full hover disclosure at readable size")
    check(screen.feedback.position.y >= screen.event_panel.position.y + screen.event_panel.size.y
        and screen.feedback.position.y + screen.feedback.size.y < screen.forward_button.position.y
        and screen.feedback.position.x + screen.feedback.size.x < screen.pocket_buttons[0].position.x,
        "1280x720 consequence stays between event and WALK ON, clear of pockets")
    for index in range(previous.pending.size(), current.pending.size()):
        var effect: Dictionary = current.pending[index]
        if effect.get("source") != acted:
            continue
        var detail: Dictionary = effect.get("effects", {})
        coverage[str(effect.kind)] = true
        match str(effect.kind):
            "curio_loot":
                coverage[str(detail.get("kind"))] = true
                check(line.contains(str(int(detail.get("amount", 0)))) and line.contains("after the Walk")
                    and line.count("Queued for after the Walk") == 1,
                    "exactly one new deferred reward, never earlier pulls: " + line)
                check(previous.pockets == current.pockets and previous.dolls == current.dolls,
                    "queued reward leaves actual carried pockets and dolls unchanged")
            "curio_fray":
                var victim := str(effect.target)
                var old_fray := 0
                var new_fray := 0
                for doll in previous.dolls:
                    if doll.id == victim: old_fray = doll.fray
                for doll in current.dolls:
                    if doll.id == victim: new_fray = doll.fray
                check(new_fray - old_fray == int(detail.amount) and detail.already_applied
                    and line.contains("+%d Fray" % int(detail.amount)), "already-applied Fray shown once")
            "curio_trap":
                check(detail.status == "bleed" and line.contains("Bleed %d" % int(detail.amount)),
                    "Bleed is a queued trap, distinct from loot")
            "curio_part":
                check(line.contains("tier-1") and not line.contains(str(detail.id)),
                    "actual selected tier-I part is legible without raw part ID")
            "secret_room":
                check(line.contains("hidden chamber"), "actual secret marker gets a floor clue")
            "side_room":
                check(line.contains("side room"), "actual side room gets its own outcome")
            "curio_fight":
                check(line.contains("next fight"), "actual selected next-fight foe is described")
    var held := screen.feedback.text
    var stable := screen.walk.snapshot()
    var stable_count := screen.receipts.size()
    screen.refresh()
    check(screen.feedback.text == held and screen.walk.snapshot() == stable
        and screen.receipts.size() == stable_count, "refresh keeps one recap, no new receipt or roll")
    return result

func _test_variants() -> void:
    for pair in [
        ["pin_nest", "curio_fray"], ["pin_nest", "curio_fight"],
        ["pin_nest", "scraps"], ["pin_nest", "gold"], ["pin_nest", "pocket_item"],
        ["biting_bundle", "curio_trap"], ["borrowed_shape", "inspect_true"],
        ["borrowed_shape", "inspect_false"], ["borrowed_shape", "curio_part"],
        ["borrowed_shape", "curio_fight"], ["pattern_scraps", "secret_room"],
        ["sewn_threshold", "side_room"]]:
        var id: String = pair[0]
        var desired: String = pair[1]
        var find := _witness(id, desired)
        check(not find.is_empty(), "bounded genuine seed finds %s %s" % [id, desired])
        if find.is_empty():
            continue
        var screen: StitchedWalkScreen = await _mount(int(find.seed), id)
        if screen == null:
            continue
        if id == "borrowed_shape":
            var before_inspect := screen.walk.snapshot()
            var inspect := _choose(screen, "inspect")
            check(inspect.get("ok", false) and inspect.events[0].kind == "dummy_inspected",
                "real glass-eye inspect emits a truthful receipt")
            if desired.begins_with("inspect_"):
                check(screen.feedback.text.contains("mimic") and
                    (screen.feedback.text.contains("no mimic") == (desired == "inspect_false")),
                    "truth shown only after real inspection")
                coverage[desired] = true
                screen.free()
                continue
            check(screen.walk.snapshot().pending == before_inspect.pending,
                "inspection alone queues neither part nor fight")
        var choice: String = {"pin_nest": "pull", "borrowed_shape": "take", "biting_bundle": "reach",
            "pattern_scraps": "read", "sewn_threshold": "unpick"}[id]
        var old_button: Button = null
        for pull in (int(find.pull) + 1 if id == "pin_nest" else 1):
            var prior := screen.walk.snapshot()
            if id == "pin_nest" and pull == 0:
                for button in screen.event_buttons:
                    if button.text == StitchedWalkScreen.CHOICE_CAPTIONS.pull:
                        old_button = button
            var receipt := _choose(screen, choice)
            if receipt.is_empty():
                break
            if id == "pin_nest" and pull < int(find.pull):
                var all_new: Array = screen.expected.pending.slice(prior.pending.size())
                check(all_new.size() == 1 and screen.feedback.text.contains(str(int(all_new[0].effects.get("amount", 0)))) ==
                    (all_new[0].kind == "curio_fray" or all_new[0].kind == "curio_loot"),
                    "each pull only recounts its own new effect: " + screen.feedback.text + " / " + str(all_new))
            if id == "pin_nest" and old_button != null:
                var state := screen.walk.snapshot()
                var count := screen.receipts.size()
                old_button.pressed.emit()
                check(screen.walk.snapshot() == state and screen.receipts.size() == count,
                    "stale PULL button cannot double-spend, even with repeat still legal")
                old_button = null
        if id == "pin_nest":
            check(screen.feedback.text.contains("Fray") if desired == "curio_fray" else
                (screen.feedback.text.contains("next fight") if desired == "curio_fight" else
                screen.feedback.text.contains("after the Walk")),
                "final repeated PULL recap names only its selected outcome")
        screen.free()

func _test_leave_and_protection() -> void:
    var witness := _witness("biting_bundle", "curio_trap")
    check(not witness.is_empty(), "unprotected ragbag Bleed witness found")
    if witness.is_empty():
        return
    for mode in ["none", "pins", "dye", "leave"]:
        var screen: StitchedWalkScreen = await _mount(int(witness.seed), "biting_bundle")
        if screen == null: continue
        if mode in ["pins", "dye"]:
            screen.drawer_toggle.pressed.emit()
            var before_item := screen.walk.snapshot()
            screen.pocket_buttons[0 if mode == "pins" else 1].pressed.emit()
            screen.drawer_toggle.pressed.emit()
            check(screen.walk.snapshot().pending.size() == before_item.pending.size() + 1,
                "genuine pocket action queues protective descriptor")
        var prior := screen.walk.snapshot()
        _choose(screen, "leave" if mode == "leave" else "reach")
        var current := screen.walk.snapshot()
        if mode == "leave":
            check(current.pending == prior.pending and current.rng == prior.rng and
                screen.feedback.text.contains("Nothing is taken") and not screen.feedback.text.contains("Queued"),
                "LEAVE does not fabricate reward, trap or RNG")
        elif mode == "none":
            check(screen.feedback.text.contains("Bleed 2") and screen.feedback.text.contains("after the Walk"),
                "unprotected reach shows both actual trap and queued reward")
        else:
            check(current.pending.size() == prior.pending.size() + 1
                and current.pending.back().kind == "curio_loot"
                and not screen.feedback.text.contains("Bleed"),
                "one genuinely consumed pin/dye suppresses trap but does not add loot twice")
            check(current.pending[0].consumed if mode == "pins" else
                not current.pending[0].effects.skip_one_curio_trap,
                "earlier protective descriptor changed in place, not a second loot")
        screen.free()

func _test_disabled_and_rejected() -> void:
    for id in ["borrowed_shape", "sewn_threshold"]:
        var witness := _witness(id, "curio_part" if id == "borrowed_shape" else "side_room")
        check(not witness.is_empty(), "capability negative has genuine instance")
        if witness.is_empty(): continue
        var screen: StitchedWalkScreen = await _mount(int(witness.seed), id, false)
        if screen == null: continue
        var forbidden := "inspect" if id == "borrowed_shape" else "unpick"
        check(not forbidden in screen.walk.curio_choices(screen.current_curio().instance)
            and not screen.event_buttons.any(func(b): return b.text == StitchedWalkScreen.CHOICE_CAPTIONS[forbidden]),
            "disabled part-capability action never offered")
        var prior := screen.walk.snapshot()
        var receipt := screen.command("curio", {"target": screen.current_curio().instance, "choice": forbidden})
        check(not receipt.ok and receipt.events.is_empty() and screen.walk.snapshot() == prior
            and screen.feedback.text.contains("cannot be done"), "unavailable choice fails closed without successful recap")
        var forged := screen.walk.snapshot()
        forged.whirr += 5
        receipt = screen.command("curio", {"target": screen.current_curio().instance, "choice": "leave"}, forged)
        check(not receipt.ok and receipt.error == "stale_snapshot" and screen.walk.snapshot() == prior
            and screen.feedback.text.contains("stale snapshot"), "bad expected snapshot rejects with no success recap")
        screen.free()

func _app_mount() -> void:
    var app: Node = load("res://scenes/app.tscn").instantiate()
    app.run_seed = 42
    app.stitched_walks = true
    root.add_child(app)
    await process_frame
    app.start_button.pressed.emit()
    await process_frame
    check(app.stitched_run_buttons.size() > 0, "title opens real four-doll picker")
    if app.stitched_run_buttons.is_empty():
        app.free()
        return
    app.stitched_run_buttons[0].pressed.emit()
    await process_frame
    var session: StitchedRunSession = app.stitched_run_session
    check(session != null and session.phase == "map" and session.picks.size() == 4,
        "four-doll choice reaches authoritative map")
    if session == null:
        app.free()
        return
    var pick := -1
    for i in session.choices().size():
        if session.map.get_node(session.choices()[i]).type != "Boss":
            pick = i
            break
    check(pick >= 0, "genuine map ticket exists")
    if pick >= 0:
        app.stitched_run_buttons[pick].pressed.emit()
        await process_frame
        var screen: StitchedWalkScreen = app.stitched_run_walk
        check(screen != null and screen.host == session and screen.walk == session.walk,
            "real app route mounts the actual feedback-bearing Walk screen")
        if screen != null:
            var before := session.snapshot()
            var count := session.journal.size()
            screen.refresh()
            check(session.snapshot() == before and session.journal.size() == count,
                "host refresh does not modify saved play")
            screen.back_button.pressed.emit()
            check(session.journal.size() == count + 1 and session.journal.back().action == "walk"
                and session.is_consistent() and session.walk.snapshot() == screen.expected,
                "one app-mounted click forwards exactly one hosted walk_act receipt")
    app.free()

func _run() -> void:
    root.size = Vector2i(1280, 720)
    await _test_variants()
    await _test_leave_and_protection()
    await _test_disabled_and_rejected()
    await _app_mount()
    for required in ["curio_fray", "curio_fight", "curio_trap", "curio_part",
        "curio_loot", "scraps", "gold", "pocket_item", "secret_room", "side_room",
        "inspect_true", "inspect_false"]:
        check(coverage.has(required), "non-vacuous real mounted consequence: " + required)
    for error in failures:
        printerr(error)
    print("stitched_s10_curio_outcome_feedback_test: ", "PASS" if failures.is_empty() else "FAIL",
        " (", checks, " checks)")
    quit(0 if failures.is_empty() else 1)
