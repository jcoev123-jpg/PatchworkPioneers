extends SceneTree
## Mounted S13 cloth-only Reliquary: authored thread selection shares the maker control.

const SCENE := "res://scenes/stitched_part_inspector.tscn"
const WARDEN := "res://data/parts/warden_parts.json"
const EXAMPLES := {
    "warden_head_pot_helm_bonk": ["head", "crimson"],
    "warden_head_helmet_rattle": ["head", "bone"],
    "warden_arms_shield_catch": ["arms", "indigo"],
    "warden_arms_rivet_pummel": ["arms", "ash"],
}
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
    _run.call_deferred()


func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)


func _before(a: Dictionary, b: Dictionary) -> bool:
    var a_name := str(a["name"]).to_lower()
    var b_name := str(b["name"]).to_lower()
    return a_name < b_name or (a_name == b_name and str(a["id"]) < str(b["id"]))


func _expected(parts: Array, slot: String, tag: String) -> Array[String]:
    var matches: Array = []
    for part in parts:
        if str(part["slot"]) != slot:
            continue
        var id := str(part["id"])
        if tag == "all" or (tag.begins_with("thread:") and
                StitchedSewnPatches.thread_of(id) == tag.trim_prefix("thread:")) or (
                tag == str(part["owner"])):
            matches.append(part)
    matches.sort_custom(_before)
    var ids: Array[String] = []
    for part in matches:
        ids.append(str(part["id"]))
    return ids


func _preview(panel: StitchedPartInspector) -> TextureRect:
    return panel.get_node("DetailsPanel/PatchPreview") as TextureRect


func _border(panel: StitchedPartInspector) -> TextureRect:
    return panel.get_node("DetailsPanel/TierBorderPreview") as TextureRect


func _path(rect: TextureRect) -> String:
    return rect.texture.resource_path if rect.texture != null else ""


func _blank(panel: StitchedPartInspector) -> bool:
    return panel.selected_part_id.is_empty() and panel.selected_tier == 1 and (
        _preview(panel).texture == null and _border(panel).texture == null and
        not _preview(panel).visible and not _border(panel).visible and
        (panel.get_node("DetailsPanel/PartName") as Label).text == "No part selected" and
        (panel.get_node("DetailsPanel/PartText") as Label).text.is_empty() and
        (panel.get_node("DetailsPanel/PartMeta") as Label).text.find("THREAD:") < 0 and
        (panel.get_node("DetailsPanel/NumbersLine") as Label).text.is_empty() and
        (panel.get_node("DetailsPanel/AbilityLine") as Label).text.is_empty())


func _real_patch(panel: StitchedPartInspector, id: String, slot: String) -> bool:
    var meta := (panel.get_node("DetailsPanel/PartMeta") as Label).text
    return panel.selected_part_id == id and panel.selected_tier == 1 and (
        _path(_preview(panel)) == StitchedSewnPatches.icon_path(id, slot) and
        _preview(panel).visible and _path(_border(panel)).is_empty() and
        not _border(panel).visible and
        meta.contains("ID: " + id) and
        meta.contains("THREAD: " + StitchedSewnPatches.thread_of(id).to_upper()) and
        not meta.contains("KNOT") and
        (panel.get_node("DetailsPanel/StatLine") as Label).text.is_empty() and
        (panel.get_node("DetailsPanel/MovementLine") as Label).text.is_empty())


func _run() -> void:
    root.size = Vector2i(1280, 720)
    var catalog := StitchedParts.load_catalog(WARDEN)
    _check(bool(catalog.get("ok", false)), "actual authored Warden catalog validates")
    if not bool(catalog.get("ok", false)):
        _finish()
        return
    var source: Array = catalog["parts"]
    var by_id: Dictionary = catalog["by_id"]
    for id in EXAMPLES:
        var description: Array = EXAMPLES[id]
        _check(by_id.has(id), "real Warden catalog contains " + id)
        if by_id.has(id):
            _check(str(by_id[id]["slot"]) == description[0] and
                str(by_id[id]["owner"]) == "warden" and
                StitchedSewnPatches.thread_of(id) == description[1] and
                description[1] in StitchedSewnPatches.THREADS,
                "actual slot and S13 thread agree for " + id)
    var packed := load(SCENE) as PackedScene
    _check(packed != null, "shipped Reliquary scene loads")
    if packed == null or EXAMPLES.keys().any(func(id): return not by_id.has(id)):
        _finish()
        return

    var repeat_witness: Array = []
    for pass_index in range(2):
        var given := source.duplicate(true)
        if pass_index == 1:
            given.reverse()
        var pristine := given.duplicate(true)
        var panel := packed.instantiate() as StitchedPartInspector
        root.add_child(panel)
        await process_frame
        var dropdown := panel.get_node("CatalogPanel/OwnerFilter") as OptionButton
        var maker_label := panel.get_node("CatalogPanel/OwnerLabel") as Label
        var slot_head := panel.get_node("CatalogPanel/SlotHead") as Button
        var slot_arms := panel.get_node("CatalogPanel/SlotArms") as Button
        _check(dropdown != null and maker_label != null and
            slot_head != null and slot_arms != null, "mounted original controls exist")
        _check(dropdown.get_item_count() ==
            StitchedPartInspector.OWNERS.size() + StitchedSewnPatches.THREADS.size() and
            maker_label.text == "MAKER / THREAD" and
            dropdown.focus_mode == Control.FOCUS_ALL and
            dropdown.get_theme_stylebox("focus") != null and
            root.get_visible_rect().encloses(dropdown.get_global_rect()) and
            root.get_visible_rect().encloses(maker_label.get_global_rect()) and
            slot_head.focus_mode == Control.FOCUS_ALL and
            slot_arms.focus_mode == Control.FOCUS_ALL,
            "one themed and focusable Maker / Thread dropdown fits 1280x720")
        for index in range(StitchedPartInspector.OWNERS.size()):
            _check(dropdown.get_item_text(index) ==
                StitchedPartInspector.OWNER_LABELS[index] and
                dropdown.get_item_id(index) == index,
                "original maker name, index, and ID preserved: %d" % index)
        for thread_index in range(StitchedSewnPatches.THREADS.size()):
            var thread: String = StitchedSewnPatches.THREADS[thread_index]
            var dropdown_index := StitchedPartInspector.OWNERS.size() + thread_index
            _check(dropdown.get_item_text(dropdown_index) == thread.capitalize() + " thread"
                and dropdown.get_item_id(dropdown_index) == dropdown_index,
                "original dropdown appends real " + thread + " thread")
        seed(771391)
        var expected_rng := randi()
        seed(771391)
        _check(panel.present_parts(given) and not dropdown.disabled
            and panel.selected_owner == "all", "valid Warden input mounts at All")
        var full_head := panel.part_ids_in_slot("head")
        var full_arms := panel.part_ids_in_slot("arms")
        _check(full_head == _expected(source, "head", "all") and
            full_arms == _expected(source, "arms", "all"),
            "unfiltered full index is alphabetical and data-backed")
        var observed: Array = []
        for thread in StitchedSewnPatches.THREADS:
            var tag: String = "thread:" + thread
            var index := StitchedPartInspector.OWNERS.size() + StitchedSewnPatches.THREADS.find(thread)
            dropdown.select(index)
            dropdown.item_selected.emit(index)
            _check(panel.selected_owner == tag and dropdown.get_selected_id() == index,
                "actual item_selected signal switches to " + tag)
            for slot in StitchedPartInspector.SLOTS:
                _check(panel.select_slot(slot), "thread slot is selectable even when empty")
                var expected := _expected(source, slot, tag)
                var visible := panel.visible_part_ids_in_slot(slot)
                observed.append([tag, slot, visible.duplicate()])
                _check(visible == expected and
                    panel.part_ids_in_slot(slot) == _expected(source, slot, "all") and
                    (panel.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer).get_child_count()
                    == visible.size(),
                    "thread-filtered rows exactly match authored IDs in " + tag + "/" + slot)
                if expected.is_empty():
                    _check(_blank(panel) and not panel.select_tier(2),
                        "empty intersection clears art/details and cannot change finish")
                else:
                    _check(panel.selected_part_id in expected and
                        (panel.get_node("DetailsPanel/PartMeta") as Label).text.contains(
                            "THREAD: " + thread.to_upper()),
                        "selected part is an actual authored thread match in " + slot)
        if pass_index == 0:
            repeat_witness = observed.duplicate(true)
        else:
            _check(observed == repeat_witness,
                "reversing input leaves identical per-thread per-slot ordering")

        _check(panel.select_owner("warden") and panel.select_slot("head") and
            panel.visible_part_ids_in_slot("head") == _expected(source, "head", "warden") and
            panel.part_ids_in_slot("head") == full_head,
            "old Warden maker mode still works with unchanged full index")
        _check(panel.select_part("warden_head_pot_helm_bonk") and
            _real_patch(panel, "warden_head_pot_helm_bonk", "head"),
            "Warden's real crimson head cloth and plain art remain selectable")
        _check(panel.select_tier(2) and
            _path(_border(panel)) == StitchedSewnPatches.border_path(2) and
            _border(panel).visible and panel.select_tier(3) and
            _path(_border(panel)) == StitchedSewnPatches.border_path(3) and
            _border(panel).visible,
            "Double and Gold thread retain authentic border assets")
        _check(not panel.select_owner("thread:unknown") and
            not panel.select_owner("maker:warden") and
            not panel.select_part("not_a_patch") and
            not panel.select_tier(4) and panel.selected_tier == 3 and
            panel.selected_part_id == "warden_head_pot_helm_bonk",
            "invalid filter, part and finish cannot change state")
        _check(panel.select_owner("thread:crimson") and
            panel.select_slot("head") and
            panel.select_part("warden_head_pot_helm_bonk") and
            not panel.select_part("warden_head_helmet_rattle") and
            panel.selected_part_id == "warden_head_pot_helm_bonk",
            "thread-filtered ID selection refuses a valid different-thread ID")
        _check(panel.select_owner("thread:bone") and
            panel.select_slot("head") and
            panel.select_part("warden_head_helmet_rattle") and
            _real_patch(panel, "warden_head_helmet_rattle", "head"),
            "Bone head thread restores a real head part at plain finish")
        _check(panel.select_owner("thread:indigo") and
            panel.select_part("warden_arms_shield_catch") and
            _real_patch(panel, "warden_arms_shield_catch", "arms"),
            "Indigo arms thread selects real Warden arms across slots")
        _check(panel.select_owner("thread:ash") and
            panel.select_part("warden_arms_rivet_pummel") and
            _real_patch(panel, "warden_arms_rivet_pummel", "arms"),
            "Ash arms thread selects real Warden arms across slots")

        var examples: Array = []
        for id in EXAMPLES:
            examples.append(by_id[id].duplicate(true))
        _check(panel.present_parts(examples) and panel.select_owner("thread:indigo") and
            panel.select_slot("head") and _blank(panel) and
            not panel.select_part("warden_head_pot_helm_bonk") and
            not panel.select_tier(3) and _blank(panel),
            "empty real-only intersection blocks hidden ID/finish and clears stale previews")
        _check(panel.select_slot("arms") and
            _real_patch(panel, "warden_arms_shield_catch", "arms") and
            panel.select_tier(3) and _border(panel).visible,
            "moving from empty head to occupied arms restores a real patch")
        _check(panel.select_owner("all") and panel.select_slot("head") and
            panel.selected_part_id in _expected(examples, "head", "all") and
            panel.selected_tier == 1 and _path(_border(panel)).is_empty() and
            panel.part_ids_in_slot("arms") == _expected(examples, "arms", "all"),
            "All restores only supplied parts and resets a newly selected patch to Plain")

        var foe_catalog := StitchedParts.load_catalog("res://data/parts/enemy_parts.json")
        _check(bool(foe_catalog.get("ok", false)) and
            foe_catalog.get("by_id", {}).has("scissor_crab_claw_arm"),
            "real enemy Spoils catalog validates and contains Scissor Claw")
        if bool(foe_catalog.get("ok", false)) and foe_catalog["by_id"].has("scissor_crab_claw_arm"):
            var foe_id := "scissor_crab_claw_arm"
            var mixed: Array = [by_id["warden_head_pot_helm_bonk"].duplicate(true),
                foe_catalog["by_id"][foe_id].duplicate(true)]
            _check(StitchedSewnPatches.thread_of(foe_id) == "crimson" and
                panel.present_parts(mixed) and panel.select_owner("thread:crimson") and
                panel.select_slot("arms") and panel.visible_part_ids_in_slot("arms").has(foe_id) and
                panel.select_part(foe_id) and
                (panel.get_node("DetailsPanel/PartText") as Label).text.begins_with("Foe cloth"),
                "thread browser includes authored crimson Spoils across maker boundaries")
            _check(panel.select_owner("warden") and _blank(panel) and
                not panel.select_part(foe_id) and panel.select_owner("any") and
                panel.select_part(foe_id),
                "old maker filters still exclude foreign Spoils and restore them under Spoils")

        var fixture := StitchedParts.load_catalog("res://tests/fixtures/stitched_s1a_parts.json")
        _check(bool(fixture.get("ok", false)) and
            fixture.get("by_id", {}).has("warden_head_iron_helm"),
            "legacy validated part without a thread is available as a negative witness")
        if bool(fixture.get("ok", false)) and fixture["by_id"].has("warden_head_iron_helm"):
            var unthreaded: Array = [fixture["by_id"]["warden_head_iron_helm"].duplicate(true)]
            _check(StitchedSewnPatches.thread_of("warden_head_iron_helm").is_empty() and
                panel.present_parts(unthreaded) and
                panel.select_owner("thread:crimson") and _blank(panel) and
                not panel.select_part("warden_head_iron_helm") and
                panel.select_owner("warden") and
                panel.select_part("warden_head_iron_helm") and
                not (panel.get_node("DetailsPanel/PartMeta") as Label).text.contains("THREAD:"),
                "unthreaded cloth stays in its maker catalog without an invented thread")

        var closes := [0]
        panel.close_requested.connect(func(): closes[0] += 1)
        (panel.get_node("CloseButton") as Button).pressed.emit()
        _check(closes[0] == 1, "Close continues emitting once")
        _check(not panel.present_parts([{"id": "invalid"}]) and _blank(panel)
            and dropdown.disabled and dropdown.get_selected_id() == 0
            and panel.selected_owner == "all" and
            not panel.select_part("warden_head_helmet_rattle") and
            not panel.select_owner("thread:bone"),
            "rejected re-presentation fails closed without stale textures or selections")
        _check(panel.present_parts(given) and panel.select_owner("all") and
            panel.select_part("warden_head_pot_helm_bonk") and
            _real_patch(panel, "warden_head_pot_helm_bonk", "head"),
            "valid re-presentation recovers from an invalid catalog")
        _check(given == pristine and source == catalog["parts"] and randi() == expected_rng,
            "filter, slot, finish, clear and Close leave caller and global RNG unchanged")
        panel.free()
        await process_frame
        _check(not is_instance_valid(panel), "mount/free releases the gallery")

    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("PASS stitched_s13_reliquary_thread_filter_test: %d checks, two reversed passes" % checks)
        quit(0)
    else:
        for problem in failures:
            push_error("FAIL stitched_s13_reliquary_thread_filter_test: " + problem)
        print("FAIL stitched_s13_reliquary_thread_filter_test: %d/%d checks" %
            [failures.size(), checks])
        quit(1)
