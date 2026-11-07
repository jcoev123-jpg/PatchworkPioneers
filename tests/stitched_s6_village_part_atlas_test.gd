extends SceneTree
## Headless S6 contract: follow the real village entry to the guide's nested
## inspector. Only disk-authored Warden and foe parts may appear, without runs.
const VILLAGE := preload("res://scenes/base_screen.tscn")
const WARDEN := "res://data/parts/warden_parts.json"
const FOES := "res://data/parts/enemy_parts.json"
const SEAMSTRESS := "res://data/parts/seamstress_parts.json"
const TINKER := "res://data/parts/tinker_parts.json"
const YARN_RANGER := "res://data/parts/yarn_ranger_parts.json"
const SOURCES := [WARDEN, SEAMSTRESS, TINKER, YARN_RANGER, FOES]

var failures: Array[String] = []
var checks := 0
var view: BaseScreen
var calls: Dictionary = {"back": 0, "set_out": 0, "path": 0, "tinker": 0,
    "warden": 0, "difficulty": 0}


func _initialize() -> void:
    _run.call_deferred()


func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)


func _frames() -> void:
    for _i in range(3):
        await process_frame


func _key(key: Key, shifted: bool = false) -> void:
    for pressed in [true, false]:
        var event := InputEventKey.new()
        event.keycode = key
        event.physical_keycode = key
        event.shift_pressed = shifted
        event.pressed = pressed
        root.push_input(event, true)
        await process_frame


func _click(button: Button) -> void:
    var point := button.get_global_rect().get_center()
    _check(root.get_visible_rect().has_point(point), "button has reachable screen coordinates: " + button.name)
    var motion := InputEventMouseMotion.new()
    motion.position = point
    root.push_input(motion, true)
    await process_frame
    for pressed in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = point
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        root.push_input(event, true)
        await process_frame


func _paths(path: String) -> Array:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    var records: Variant = raw.get("paths", []) if raw is Dictionary else raw
    var output: Array = []
    if records is Array:
        for record in records:
            if record is Dictionary:
                output.append({"id": str(record.get("id", "")),
                    "display_name": str(record.get("display_name", "")),
                    "card_name": str(record.get("card", {}).get("display_name", ""))})
    return output


func _state() -> Array:
    return [view.wallet_label.text, view.selected_path_id(), view.selected_tinker_path_id(),
        view.selected_warden_path_id(), view._back_pending, view._set_out_pending,
        view._path_pending, view._tinker_pending, view._warden_pending,
        view._difficulty_request, view.field_guide._atlas_is_open(), calls.duplicate(true)]


func _line(inspector: StitchedPartInspector, name: String) -> String:
    return str(inspector.get_node("DetailsPanel/" + name).text)


func _witness(inspector: StitchedPartInspector, id: String, name: String,
        slot: String, owner: String, ability: String, kind: String,
        launch: String, side: String, targets: String, effect: String) -> void:
    _check(inspector.part_ids_in_slot(slot).has(id),
        "real catalog includes required id %s under %s (never a size/order fixture)" % [id, slot])
    _check(inspector.select_part(id), "public inspector selects real ID " + id)
    _check(inspector.selected_part_id == id and inspector.active_slot == slot
        and inspector.selected_tier == 1 and _line(inspector, "PartName") == name
        and _line(inspector, "PartMeta").contains("OWNER: " + owner)
        and _line(inspector, "PartMeta").contains("SLOT: " + slot.to_upper())
        and _line(inspector, "PartMeta").contains("ID: " + id),
        "real part ID/name/owner/slot and tier I are displayed: " + id)
    _check(_line(inspector, "AbilityLine").contains("ABILITY: " + ability)
        and _line(inspector, "AbilityLine").contains(kind.to_upper())
        and _line(inspector, "RanksLine").contains("LAUNCH: " + launch)
        and _line(inspector, "RanksLine").contains("TARGET: " + side.to_upper() + " RANKS " + targets)
        and _line(inspector, "EffectsLine").contains(effect),
        "ability, legal launch/target ranks and effects come from real part: " + id)


## Expectations are computed from the independently validated on-disk record,
## not copied numeric values or duplicated rows.
func _source_witness(inspector: StitchedPartInspector, part: Dictionary) -> void:
    var id := str(part["id"])
    var slot := str(part["slot"])
    var owner := str(part["owner"])
    var ability: Dictionary = StitchedParts.ability_at_tier(part, 1)
    _check(inspector.part_ids_in_slot(slot).has(id) and inspector.select_part(id),
        "mounted inspector includes authentic source-backed part " + id)
    _check(inspector.selected_part_id == id and inspector.active_slot == slot
        and _line(inspector, "PartName") == str(part["name"])
        and _line(inspector, "PartMeta").contains("OWNER: " + owner)
        and _line(inspector, "PartMeta").contains("ID: " + id)
        and _line(inspector, "AbilityLine").contains("ABILITY: " + str(ability["name"]))
        and _line(inspector, "RanksLine").contains("TARGET: " + str(ability["target_side"]).to_upper()),
        "name, ID, owner, slot and ability match validated source for " + id)


func _source_tier(inspector: StitchedPartInspector, part: Dictionary, tier: int) -> void:
    var ability := StitchedParts.ability_at_tier(part, tier)
    var stat := StitchedParts.stat_at_tier(part, tier)
    var id := str(part["id"])
    await _click(inspector.get_node("DetailsPanel/" + ["TierI", "TierII", "TierIII"][tier - 1]) as Button)
    _check(inspector.selected_part_id == id and inspector.selected_tier == tier
        and _line(inspector, "NumbersLine").contains("ACC: %d%%" % int(ability["acc"]))
        and _line(inspector, "NumbersLine").contains("DAMAGE: %d-%d" % [
            int(ability["dmg"][0]), int(ability["dmg"][1])])
        and _line(inspector, "RanksLine").contains("LAUNCH: " + _ranks(ability["launch"]))
        and _line(inspector, "RanksLine").contains("RANKS " + _ranks(ability["target"]))
        and _line(inspector, "MovementLine").contains("POSE: " + str(ability["move"])),
        "tier %d numbers/ranks/pose are authored for %s" % [tier, id])
    for key in stat:
        _check(_line(inspector, "StatLine").contains(
            "%s +%d" % [str(key).to_upper().replace("_", " "), int(stat[key])]),
            "tier %d stat %s comes from source %s" % [tier, str(key), id])
    for key in ability["effects"]:
        _check(_line(inspector, "EffectsLine").contains(
            "%s %d" % [str(key).capitalize(), int(ability["effects"][key])]),
            "tier %d effect %s comes from source %s" % [tier, str(key), id])


func _ranks(ranks: Array) -> String:
    var values: Array[String] = []
    for rank in ranks:
        values.append(str(rank))
    return ", ".join(values)


func _tier(inspector: StitchedPartInspector, id: String, tier: int,
        accuracy: int, damage: String, effect: String) -> void:
    var button: Button = inspector.get_node(
        "DetailsPanel/" + ["TierI", "TierII", "TierIII"][tier - 1])
    await _click(button)
    await _frames()
    _check(inspector.selected_part_id == id and inspector.selected_tier == tier,
        "physical tier button %d keeps selected ID %s" % [tier, id])
    _check(_line(inspector, "NumbersLine").contains("ACC: %d%%" % accuracy)
        and _line(inspector, "NumbersLine").contains("DAMAGE: " + damage)
        and _line(inspector, "EffectsLine").contains(effect)
        and _line(inspector, "PartMeta").contains("TIER " + ["I", "II", "III"][tier - 1]),
        "tier-%d real authored accuracy/damage/effect readout for %s" % [tier, id])


func _run() -> void:
    root.size = Vector2i(1280, 720)
    var originals: Dictionary = {}
    var actual_ids: Dictionary = {}
    var sources: Dictionary = {}
    for path in SOURCES:
        var contents := FileAccess.get_file_as_string(path)
        var parsed := StitchedParts.load_catalog(path)
        _check(not contents.is_empty() and bool(parsed.get("ok", false)),
            "independent authored catalog validates: " + path)
        if contents.is_empty() or not bool(parsed.get("ok", false)):
            _finish()
            return
        originals[path] = contents
        sources[path] = parsed
        for part in parsed["parts"]:
            actual_ids[str(part["id"])] = part
    for id in ["warden_head_pot_helm_bonk", "seamstress_mending_knot_hat",
            "tinker_head_cog_shot", "yarn_ranger_head_needle_nock",
            "scissor_crab_claw_arm", "moth_swarm_wings",
            "felt_bulwark_button_shield"]:
        _check(actual_ids.has(id), "validated source actually contains witness " + id)
    view = VILLAGE.instantiate() as BaseScreen
    root.add_child(view)
    await _frames()
    var guide := view.field_guide
    var entry := view.guide_button
    _check(view.scene_file_path == "res://scenes/base_screen.tscn" and guide != null
        and entry != null and not view.has_open_village(),
        "one actual mounted village has the existing guide button and guide")
    if guide == null or entry == null:
        _finish()
        return
    var seam := _paths("res://data/heroes/seamstress_paths.json")
    var tinker := _paths("res://data/heroes/tinker_paths.json")
    var warden := _paths("res://data/heroes/warden_paths.json")
    _check(not seam.is_empty() and not tinker.is_empty() and not warden.is_empty(),
        "real option catalogs mount, so action guards cannot pass vacuously")
    if seam.is_empty() or tinker.is_empty() or warden.is_empty():
        _finish()
        return
    _check(view.present_path_options(seam) and view.present_tinker_path_options(tinker)
        and view.present_warden_path_options(warden), "all three real hero boards present")
    view.present_difficulty([0, 1], 0)
    view.back_requested.connect(func() -> void: calls["back"] += 1)
    view.set_out_requested.connect(func() -> void: calls["set_out"] += 1)
    view.path_choice_requested.connect(func(_id: String) -> void: calls["path"] += 1)
    view.tinker_path_choice_requested.connect(func(_id: String) -> void: calls["tinker"] += 1)
    view.warden_path_choice_requested.connect(func(_id: String) -> void: calls["warden"] += 1)
    view.difficulty_choice_requested.connect(func(_tier: int) -> void: calls["difficulty"] += 1)
    _check(view.open_village(27, 6), "host opens real wallet and village actions")
    await _frames()
    _check(not guide.open_part_atlas(), "atlas cannot open when the guide itself is closed")
    await _click(entry)
    _check(guide.is_open() and guide.atlas_button != null
        and guide.atlas_button.text == "Parts & spoils"
        and guide.atlas_button.focus_mode == Control.FOCUS_ALL
        and guide.tab_buttons.size() == 4 and guide.page_labels.size() == 4,
        "four current guide pages coexist with one guide-level atlas action")
    _check(guide.page_text(0).contains("ROUND ORDER")
        and guide.page_text(1).contains("RETREAT")
        and guide.page_text(2).contains("STEADFAST")
        and guide.page_text(2).contains("UNRAVELLED")
        and guide.page_text(3).contains("CANDLE")
        and guide.page_text(3).contains("SNUFFED 0"),
        "ranks and seams persist, Fray is page 2 and the live Candle bands are page 3")
    await _click(guide.atlas_button)
    var inspector := guide.part_atlas
    _check(inspector != null and inspector is StitchedPartInspector
        and inspector.get_script() == load("res://scripts/stitched/stitched_part_inspector.gd")
        and inspector.scene_file_path == "res://scenes/stitched_part_inspector.tscn",
        "real existing inspector scene, not a fake copy, is opened by actual guide click")
    if inspector == null:
        _finish()
        return
    _check(inspector.is_visible_in_tree() and guide.is_open() and entry.disabled
        and root.gui_get_focus_owner() == inspector.get_node("CloseButton")
        and (inspector.get_node("Subtitle") as Label).text.contains("REFERENCE ONLY")
        and guide.get_children().filter(func(node: Node) -> bool:
            return node is StitchedPartInspector).size() == 1,
        "nested modal stays blocked, labelled reference-only and singly mounted")
    var owner_filter := inspector.get_node("CatalogPanel/OwnerFilter") as OptionButton
    _check(owner_filter != null and owner_filter.get_item_count() == 6
        and owner_filter.get_item_text(0) == "All"
        and owner_filter.get_item_text(4) == "Yarn Ranger"
        and owner_filter.get_item_text(5) == "Spoils"
        and owner_filter.focus_mode == Control.FOCUS_ALL
        and root.get_visible_rect().encloses(owner_filter.get_global_rect()),
        "real Gothic owner filter exposes six groups inside 1280x720")
    _check(guide.catalog_paths == SOURCES and inspector.selected_owner == "all",
        "live guide loads five independent files and defaults to All")
    var all_head := inspector.part_ids_in_slot("head")
    for pair in [
            ["seamstress", "seamstress_mending_knot_hat", 2],
            ["tinker", "tinker_head_cog_shot", 3],
            ["yarn_ranger", "yarn_ranger_head_needle_nock", 2]]:
        var owner_id: String = pair[0]
        var part_id: String = pair[1]
        var group_index := StitchedPartInspector.OWNERS.find(owner_id)
        owner_filter.select(group_index)
        owner_filter.item_selected.emit(group_index)
        _check(inspector.selected_owner == owner_id
            and inspector.active_slot == "head"
            and inspector.visible_part_ids_in_slot("head").has(part_id)
            and inspector.part_ids_in_slot("head") == all_head,
            "owner selection filters only visible rows, retaining full HEAD index: " + owner_id)
        var rows: VBoxContainer = inspector.get_node("CatalogPanel/PartScroll/PartRows")
        _check(rows.get_child_count() == inspector.visible_part_ids_in_slot("head").size()
            and not rows.get_children().is_empty(),
            "owner " + owner_id + " has real clickable rows")
        _source_witness(inspector, actual_ids[part_id])
        await _source_tier(inspector, actual_ids[part_id], int(pair[2]))
        _check(not inspector.select_part("scissor_crab_claw_arm")
            and not inspector.select_owner("imaginary_hero")
            and inspector.selected_part_id == part_id,
            "hidden foreign part and invalid owner cannot change " + owner_id)
        _check(inspector.select_slot("arms")
            and inspector.active_slot == "arms"
            and not inspector.visible_part_ids_in_slot("arms").is_empty()
            and inspector.selected_tier == 1,
            "switching owner " + owner_id + " into ARMS selects a real tier-I part")
        _check(inspector.select_slot("head") and inspector.select_part(part_id),
            "returning to HEAD recovers the selected owner's authored part")
    _check(inspector.select_owner("warden") and inspector.select_part("warden_head_pot_helm_bonk"),
        "Warden group remains browseable")
    _check(inspector.select_owner("any") and inspector.select_part("scissor_crab_claw_arm"),
        "Spoils owner group browses actual foe parts")
    _check(inspector.select_owner("all") and inspector.visible_part_ids_in_slot("head") == all_head,
        "All restores the same alphabetical full-catalog HEAD rows")
    for id in ["warden_head_pot_helm_bonk", "scissor_crab_claw_arm",
            "moth_swarm_wings", "felt_bulwark_button_shield"]:
        _source_witness(inspector, actual_ids[id])
    _witness(inspector, "warden_head_pot_helm_bonk", "Pot Helm Bonk", "head", "warden",
        "Pot Helm Bonk", "melee", "1, 2", "enemy", "1, 2", "Weak 2")
    await _tier(inspector, "warden_head_pot_helm_bonk", 1, 90, "4-6", "Weak 2")
    await _tier(inspector, "warden_head_pot_helm_bonk", 3, 95, "7-10", "Weak 2")
    _witness(inspector, "scissor_crab_claw_arm", "Scissor Claw", "arms", "any",
        "Snip", "melee", "1, 2", "enemy", "1, 2", "Bleed 2")
    await _tier(inspector, "scissor_crab_claw_arm", 1, 90, "4-7", "Bleed 2")
    await _tier(inspector, "scissor_crab_claw_arm", 2, 90, "5-8", "Bleed 3")
    _witness(inspector, "moth_swarm_wings", "Tatter Wings", "legs", "any",
        "Flutter Back", "move", "1, 2, 3", "self", "1, 2, 3", "Dodge 5")
    _check(_line(inspector, "MovementLine").contains("SELF MOVE: +1")
        and _line(inspector, "MovementLine").contains("POSE: skill")
        and _line(inspector, "EffectsLine").contains("Duration 1"),
        "Tatter Wings describes backwards movement and one-turn duration")
    await _tier(inspector, "moth_swarm_wings", 3, 100, "0-0", "Dodge 10")
    _check(_line(inspector, "EffectsLine").contains("Duration 1"),
        "Flutter Back tier III still lasts one turn")
    _witness(inspector, "felt_bulwark_button_shield", "Button Shield Torso", "torso",
        "any", "Button Shield", "guard", "1, 2", "ally", "1, 2, 3, 4", "Guard 2")
    _check(_line(inspector, "NumbersLine").contains("DAMAGE: 0-0")
        and _line(inspector, "MovementLine").contains("POSE: guard"),
        "Button Shield is an ally guard, not an invented damage attack")
    _check(not inspector.select_part("fictional_part")
        and inspector.selected_part_id == "felt_bulwark_button_shield"
        and not inspector.select_tier(0) and not inspector.select_tier(4),
        "inspector refuses fabricated IDs or tiers without changing the selection")

    (inspector.get_node("CloseButton") as Button).grab_focus()
    await _key(KEY_TAB)
    _check(root.gui_get_focus_owner() == inspector.get_node("CatalogPanel/OwnerFilter"),
        "Tab from inspector Close reaches the theme-aware owner selector")
    await _key(KEY_TAB)
    _check(root.gui_get_focus_owner() == inspector.get_node("CatalogPanel/SlotHead"),
        "Tab from owner reaches first genuine slot, not the underlying guide")
    await _key(KEY_TAB, true)
    _check(root.gui_get_focus_owner() == inspector.get_node("CatalogPanel/OwnerFilter"),
        "Shift-Tab from Head reaches Owner filter")
    await _key(KEY_TAB, true)
    _check(root.gui_get_focus_owner() == inspector.get_node("CloseButton"),
        "Shift-Tab stays in inspector focus loop")
    await _key(KEY_TAB, true)
    _check(root.gui_get_focus_owner() == inspector.get_node("DetailsPanel/TierIII"),
        "reverse wrap from inspector Close reaches final tier control")
    await _key(KEY_TAB)
    _check(root.gui_get_focus_owner() == inspector.get_node("CloseButton"),
        "forward wrap from last tier never reaches guide or village")

    seed(515615)
    var expected_draw := randi()
    seed(515615)
    var witness := _state()
    view._on_back_pressed()
    view._on_set_out_pressed()
    view._on_parts_pressed()
    view._on_heroes_house_pressed()
    view._on_camp_house_pressed()
    view._on_path_pressed(str(seam[0]["id"]))
    view._on_tinker_path_pressed(str(tinker[0]["id"]))
    view._on_warden_path_pressed(str(warden[0]["id"]), view.warden_buttons[0])
    view._request_difficulty(0)
    _check(not view.mark_path_selected(str(seam[0]["id"]), str(seam[0]["display_name"]))
        and not view.mark_tinker_path_selected(str(tinker[0]["id"]), str(tinker[0]["display_name"]))
        and not view.mark_warden_path_selected(str(warden[0]["id"]), str(warden[0]["display_name"])),
        "no host confirmation can choose any hero while the nested atlas is open")
    await _click(view.back_button)
    _check(_state() == witness and randi() == expected_draw,
        "pointer and stale action handlers dispatch no village signals, spend nothing and draw no RNG")
    _check(not guide.open_part_atlas() and guide.get_children().filter(func(node: Node) -> bool:
        return node is StitchedPartInspector).size() == 1,
        "repeated nested entry is inert and cannot duplicate inspector")

    await _click(inspector.get_node("CloseButton") as Button)
    _check(guide.is_open() and not inspector.visible and inspector.selected_part_id.is_empty()
        and root.gui_get_focus_owner() == guide.atlas_button and entry.disabled,
        "inspector pointer Close clears its catalog and restores guide focus and modal guard")
    await _click(guide.atlas_button)
    _check(inspector.is_visible_in_tree() and guide.part_atlas == inspector
        and inspector.select_part("scissor_crab_claw_arm"),
        "re-entry uses one refreshed inspector and genuine foreign source")
    await _key(KEY_ESCAPE)
    _check(guide.is_open() and not inspector.visible and inspector.selected_part_id.is_empty()
        and root.gui_get_focus_owner() == guide.atlas_button,
        "first Escape closes nested atlas only and returns focus to guide")
    await _key(KEY_ESCAPE)
    _check(not guide.is_open() and root.gui_get_focus_owner() == entry and not entry.disabled,
        "second Escape closes guide and returns focus to real village")
    await _click(entry)
    _check(guide.is_open(), "guide reopens for fail-closed retry")
    guide.catalog_paths[4] = "res://data/parts/missing_atlas_catalog.json"
    await _click(guide.atlas_button)
    _check(guide.is_open() and not inspector.visible and inspector.selected_part_id.is_empty()
        and inspector.part_ids_in_slot("head").is_empty()
        and (inspector.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer).get_child_count() == 0
        and _line(inspector, "NumbersLine").is_empty()
        and guide.atlas_status.text.contains("UNAVAILABLE")
        and root.gui_get_focus_owner() != inspector.get_node("CloseButton"),
        "missing second catalog rejects whole atlas without stale rows, stats or focus")
    guide.catalog_paths[4] = FOES
    await _click(guide.atlas_button)
    _check(inspector.is_visible_in_tree() and inspector.select_part("moth_swarm_wings")
        and guide.get_children().filter(func(node: Node) -> bool:
            return node is StitchedPartInspector).size() == 1,
        "valid retry after a failed read restores authentic catalog exactly once")
    await _key(KEY_ESCAPE)
    _check(not inspector.visible and inspector.selected_part_id.is_empty(),
        "valid foe retry can close without retaining parts")
    guide.catalog_paths[1] = "res://data/parts/missing_seamstress_atlas.json"
    await _click(guide.atlas_button)
    _check(not inspector.visible and inspector.selected_part_id.is_empty()
        and inspector.selected_owner == "all"
        and inspector.part_ids_in_slot("head").is_empty()
        and inspector.visible_part_ids_in_slot("head").is_empty()
        and (inspector.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer).get_child_count() == 0
        and _line(inspector, "NumbersLine").is_empty()
        and owner_filter.disabled
        and root.gui_get_focus_owner() != owner_filter
        and guide.atlas_status.text.contains("UNAVAILABLE"),
        "missing new hero source fails whole atlas closed with no stale owner, row or focus")
    guide.catalog_paths[1] = SEAMSTRESS
    await _click(guide.atlas_button)
    _check(inspector.is_visible_in_tree()
        and inspector.select_part("seamstress_mending_knot_hat")
        and inspector.selected_owner == "all"
        and guide.get_children().filter(func(node: Node) -> bool:
            return node is StitchedPartInspector).size() == 1,
        "new hero catalog restores on retry without duplicate inspector")
    view.hide()
    await _frames()
    _check(not guide.is_open() and not guide.visible and not inspector.visible
        and inspector.selected_part_id.is_empty(),
        "parent hide closes both stacked modals and clears parts")
    view.show()
    await _frames()
    _check(not guide.is_open() and not entry.disabled,
        "showing village does not resurrect nested or outer overlay")
    await _click(entry)
    await _click(guide.atlas_button)
    _check(inspector.is_visible_in_tree(), "nested atlas still works after parent hide/show")
    view._on_field_guide_close_requested()
    guide.catalog_paths[4] = "res://missing-direct-parts-catalog.json"
    await _click(view.parts_button)
    _check(guide.is_open() and not inspector.visible and inspector.selected_part_id.is_empty()
        and inspector.part_ids_in_slot("head").is_empty()
        and (inspector.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer).get_child_count() == 0
        and _line(inspector, "NumbersLine").is_empty()
        and guide.atlas_status.text.contains("UNAVAILABLE"),
        "direct Parts doorway also rejects a partial catalog with no stale rows or facts")
    await _key(KEY_ESCAPE)
    _check(view.parts_button.has_focus() and not view.parts_button.disabled,
        "failed direct doorway restores Parts focus")
    guide.catalog_paths[4] = FOES
    await _click(view.parts_button)
    _check(inspector.is_visible_in_tree() and inspector.select_part("scissor_crab_claw_arm"),
        "direct house recovers authentic foe inspection after invalid source")
    view.close_village()
    _check(not guide.is_open() and not inspector.visible and entry.disabled
        and not view.has_open_village() and inspector.selected_part_id.is_empty(),
        "parent close clears nested panel, guard, selection and village entry")
    var sources_unchanged := true
    for path in SOURCES:
        sources_unchanged = sources_unchanged and originals[path] == FileAccess.get_file_as_string(path)
    _check(sources_unchanged, "all five authored JSON files remain byte-for-byte unchanged")
    _check(_state()[0] == "Gold 27  ·  Scraps 6" and calls["back"] == 0
        and calls["set_out"] == 0 and calls["path"] == 0 and calls["tinker"] == 0
        and calls["warden"] == 0 and calls["difficulty"] == 0,
        "all village action spies and wallet are unchanged by browse and hide/close")
    view.queue_free()
    await _frames()
    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("stitched_s6_village_part_atlas_test: PASS (%d checks)" % checks)
        quit(0)
    else:
        for failure in failures:
            printerr("FAIL: " + failure)
        printerr("stitched_s6_village_part_atlas_test: FAIL (%d/%d)" % [failures.size(), checks])
        quit(1)
