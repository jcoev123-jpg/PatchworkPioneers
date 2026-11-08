extends SceneTree
## Headless S6 contract: follow the real village entry to the guide's nested
## inspector. All configured disk-authored maker/spoils catalogs browse without runs.
const VILLAGE := preload("res://scenes/base_screen.tscn")
const WARDEN := "res://data/parts/warden_parts.json"
const FOES := "res://data/parts/enemy_parts.json"
const SEAMSTRESS := "res://data/parts/seamstress_parts.json"
const TINKER := "res://data/parts/tinker_parts.json"
const YARN_RANGER := "res://data/parts/yarn_ranger_parts.json"
const LANTERN_MONK := "res://data/parts/lantern_monk_parts.json"
const BUTTON_GOLEM := "res://data/parts/button_golem_parts.json"
const RAG_DUELIST := "res://data/parts/rag_duelist_parts.json"
const SCARECROW := "res://data/parts/scarecrow_parts.json"
const SCARECROW_PATCHES := {
    "head": [
        {"id": "scarecrow_head_sack_glare", "name": "Sack Glare", "thread": "indigo"},
        {"id": "scarecrow_head_crow_flock", "name": "Crow Flock", "thread": "ash"},
    ],
    "arms": [
        {"id": "scarecrow_arms_fork_jab", "name": "Fork Jab", "thread": "bone"},
        {"id": "scarecrow_arms_harvest_fright", "name": "Harvest Fright", "thread": "crimson"},
    ],
    "torso": [
        {"id": "scarecrow_torso_straw_padding", "name": "Straw Padding", "thread": "ash"},
        {"id": "scarecrow_torso_straw_wrap", "name": "Straw Wrap", "thread": "indigo"},
    ],
    "legs": [
        {"id": "scarecrow_legs_crow_dive", "name": "Crow Dive", "thread": "crimson"},
        {"id": "scarecrow_legs_crow_peck", "name": "Crow Peck", "thread": "bone"},
    ],
}
const RAG_PATCHES := {
    "head": [
        {"id": "rag_duelist_head_feather_feint", "name": "Feather Feint", "thread": "crimson"},
        {"id": "rag_duelist_head_tattered_snare", "name": "Tattered Snare", "thread": "bone"},
    ],
    "arms": [
        {"id": "rag_duelist_arms_rapier_lunge", "name": "Rapier Lunge", "thread": "indigo"},
        {"id": "rag_duelist_arms_needle_prick", "name": "Needle Prick", "thread": "ash"},
    ],
    "torso": [
        {"id": "rag_duelist_torso_cape_parry", "name": "Cape Parry", "thread": "bone"},
        {"id": "rag_duelist_torso_duelist_reprise", "name": "Duelist Reprise", "thread": "crimson"},
    ],
    "legs": [
        {"id": "rag_duelist_legs_cape_slip", "name": "Cape Slip", "thread": "ash"},
        {"id": "rag_duelist_legs_cape_flourish", "name": "Cape Flourish", "thread": "indigo"},
    ],
}
const SOURCES := [WARDEN, SEAMSTRESS, TINKER, YARN_RANGER, FOES, LANTERN_MONK, BUTTON_GOLEM, RAG_DUELIST, SCARECROW]

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


func _preview(inspector: StitchedPartInspector) -> TextureRect:
    return inspector.get_node("DetailsPanel/PatchPreview") as TextureRect


func _border(inspector: StitchedPartInspector) -> TextureRect:
    return inspector.get_node("DetailsPanel/TierBorderPreview") as TextureRect


func _texture_path(node: TextureRect) -> String:
    return node.texture.resource_path if node.texture != null else ""


func _no_retired_readouts(inspector: StitchedPartInspector) -> bool:
    for name in ["StatLine", "AbilityLine", "RanksLine", "NumbersLine",
            "EffectsLine", "MovementLine"]:
        if not _line(inspector, name).is_empty():
            return false
    return true


func _cloth_copy(inspector: StitchedPartInspector, slot: String) -> bool:
    if not inspector._by_id.has(inspector.selected_part_id):
        return false
    var part: Dictionary = inspector._by_id[inspector.selected_part_id]
    if str(part["slot"]) != slot:
        return false
    var owner := str(part["owner"])
    var expected := "Cloth for %s. Moves stay with the doll." % slot.to_upper()
    if StitchedSewnPatches.is_foe_patch(inspector.selected_part_id):
        expected = "Foe cloth for %s; may fray a doll outside its favoured seam. Moves stay with the doll." % slot.to_upper()
    elif not StitchedSewnPatches.favoured_slot(owner).is_empty():
        expected = "Cloth for %s; %s favours %s. Moves stay with the doll." % [
            slot.to_upper(), owner.replace("_", " ").capitalize(),
            StitchedSewnPatches.favoured_slot(owner).to_upper(),
        ]
    var label := inspector.get_node("DetailsPanel/PartText") as Label
    return label != null and label.get_line_count() >= 1 and label.get_line_count() <= 3 \
        and label.get_visible_line_count() == label.get_line_count() \
        and _line(inspector, "PartText") == expected



func _maker_matches(inspector: StitchedPartInspector, id: String) -> bool:
    var maker := StitchedSewnPatches.thread_of(id)
    var meta := _line(inspector, "PartMeta")
    if maker.is_empty():
        return not meta.contains("THREAD:")
    return meta.contains("\nTHREAD: " + maker.to_upper())


func _owner_label(filter: OptionButton, owner: String, label: String) -> bool:
    var index := StitchedPartInspector.OWNERS.find(owner)
    return index >= 0 and index < filter.get_item_count() and (
        filter.get_item_id(index) == index and filter.get_item_text(index) == label)


func _witness(inspector: StitchedPartInspector, id: String, name: String,
        slot: String, owner: String) -> void:
    _check(inspector.part_ids_in_slot(slot).has(id),
        "real catalog includes required id %s under %s (never a size/order fixture)" % [id, slot])
    _check(inspector.select_part(id), "public inspector selects real ID " + id)
    _check(inspector.selected_part_id == id and inspector.active_slot == slot
        and inspector.selected_tier == 1 and _line(inspector, "PartName") == name
        and _line(inspector, "PartMeta").contains("OWNER: " + owner)
        and _line(inspector, "PartMeta").contains("SLOT: " + slot.to_upper())
        and _line(inspector, "PartMeta").contains("ID: " + id)
        and _maker_matches(inspector, id) and _cloth_copy(inspector, slot)
        and _no_retired_readouts(inspector),
        "real identity, maker and doll-owned move copy (no retired attacks): " + id)


## Assertions derive independently from the validated on-disk catalog, rather
## than duplicating old tier-specific attack projections from those records.
func _source_witness(inspector: StitchedPartInspector, part: Dictionary) -> void:
    var id := str(part["id"])
    var slot := str(part["slot"])
    var owner := str(part["owner"])
    _check(inspector.part_ids_in_slot(slot).has(id) and inspector.select_part(id),
        "mounted inspector includes authentic source-backed part " + id)
    _check(inspector.selected_part_id == id and inspector.active_slot == slot
        and _line(inspector, "PartName") == str(part["name"])
        and _line(inspector, "PartMeta").contains("SLOT: " + slot.to_upper())
        and _line(inspector, "PartMeta").contains("OWNER: " + owner)
        and _line(inspector, "PartMeta").contains("ID: " + id)
        and _maker_matches(inspector, id) and _cloth_copy(inspector, slot)
        and _no_retired_readouts(inspector),
        "name, ID, owner, slot, maker and cloth copy match validated source for " + id)


func _source_tier(inspector: StitchedPartInspector, part: Dictionary, tier: int) -> void:
    var id := str(part["id"])
    var slot := str(part["slot"])
    var button := inspector.get_node("DetailsPanel/" + ["TierI", "TierII", "TierIII"][tier - 1]) as Button
    await _click(button)
    _check(inspector.selected_part_id == id and inspector.selected_tier == tier
        and button.button_pressed
        and _texture_path(_preview(inspector)) == StitchedSewnPatches.icon_path(id, slot)
        and _texture_path(_border(inspector)) == StitchedSewnPatches.border_path(tier)
        and _border(inspector).visible == (tier != 1)
        and _cloth_copy(inspector, slot) and _no_retired_readouts(inspector)
        and _maker_matches(inspector, id)
        and not _line(inspector, "PartMeta").contains("TIER "),
        "physical finish %d preserves authentic source art, maker and no obsolete move data: %s" % [tier, id])


func _tier(inspector: StitchedPartInspector, id: String, tier: int) -> void:
    var slot := inspector.active_slot
    var button := inspector.get_node("DetailsPanel/" + ["TierI", "TierII", "TierIII"][tier - 1]) as Button
    await _click(button)
    await _frames()
    _check(inspector.selected_part_id == id and inspector.selected_tier == tier
        and button.button_pressed and _cloth_copy(inspector, slot)
        and _no_retired_readouts(inspector) and _maker_matches(inspector, id)
        and _texture_path(_preview(inspector)) == StitchedSewnPatches.icon_path(id, slot)
        and _texture_path(_border(inspector)) == StitchedSewnPatches.border_path(tier)
        and _border(inspector).visible == (tier != 1)
        and not _line(inspector, "PartMeta").contains("TIER "),
        "physical finish %d keeps selected %s and changes only its border" % [tier, id])


## Exercise each new maker through the mounted owner's original selector, four
## physical slot buttons, authored rows, and the three original finish buttons.
## Expected identities come from independent validated disk data, not a total.
func _browse_new_maker(inspector: StitchedPartInspector, owner_filter: OptionButton,
        owner: String, source_path: String, head_id: String, arms_id: String,
        all_slots: Dictionary) -> void:
    var catalog := StitchedParts.load_catalog(source_path)
    _check(bool(catalog.get("ok", false)), "maker source loads independently: " + owner)
    if not bool(catalog.get("ok", false)):
        return
    var by_id: Dictionary = catalog["by_id"]
    var filter_index := StitchedPartInspector.OWNERS.find(owner)
    _check(filter_index >= 0 and owner_filter.get_item_text(filter_index) ==
        StitchedPartInspector.OWNER_LABELS[filter_index],
        "new maker has an authentic label in original dropdown: " + owner)
    if filter_index < 0:
        return
    owner_filter.select(filter_index)
    owner_filter.item_selected.emit(filter_index)
    _check(inspector.selected_owner == owner and not owner_filter.disabled
        and inspector.get_node("CatalogPanel/OwnerFilter") == owner_filter,
        "original owner selector chooses " + owner)
    for slot in StitchedPartInspector.SLOTS:
        var source_ids: Array[String] = []
        for part in catalog["parts"]:
            if str(part["slot"]) == slot:
                source_ids.append(str(part["id"]))
        _check(not source_ids.is_empty(), "real %s source provides %s patches" % [owner, slot])
        var slot_button := inspector.get_node("CatalogPanel/Slot" + slot.capitalize()) as Button
        await _click(slot_button)
        var visible := inspector.visible_part_ids_in_slot(slot)
        var rows := inspector.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer
        _check(inspector.active_slot == slot and slot_button.button_pressed
            and not visible.is_empty() and visible.size() == source_ids.size()
            and rows.get_child_count() == visible.size()
            and inspector.part_ids_in_slot(slot) == all_slots[slot],
            "physical %s slot selects just %s source rows, preserving full index" % [slot, owner])
        for i in range(visible.size()):
            var id: String = visible[i]
            _check(by_id.has(id) and source_ids.has(id),
                "no foreign source rows enter %s / %s: %s" % [owner, slot, id])
            if not by_id.has(id):
                continue
            var part: Dictionary = by_id[id]
            var row := rows.get_child(i) as Button
            _check(row != null and row.text == "%s   /   %s" % [str(part["name"]), owner]
                and str(part["owner"]) == owner and str(part["slot"]) == slot,
                "visible button matches actual source name, owner and slot: " + id)
            _source_witness(inspector, part)
        if slot == "head" or slot == "arms":
            var witness_id := head_id if slot == "head" else arms_id
            _check(by_id.has(witness_id) and visible.has(witness_id),
                "required %s maker ID is actually authored and visible: %s" % [slot, witness_id])
            if by_id.has(witness_id):
                _source_witness(inspector, by_id[witness_id])
                for finish in [1, 2, 3]:
                    await _source_tier(inspector, by_id[witness_id], finish)
        _check(_no_retired_readouts(inspector) and _cloth_copy(inspector, slot),
            "slot switch never reveals retired combat data: %s %s" % [owner, slot])
    var selected := inspector.selected_part_id
    _check(not inspector.select_part("warden_head_pot_helm_bonk")
        and not inspector.select_owner("unknown_maker")
        and inspector.selected_part_id == selected and inspector.selected_owner == owner,
        "foreign part and forged owner cannot change filtered %s selection" % owner)


## Test each exact authored patch without asserting a global catalog total.
func _browse_rag_duelist(inspector: StitchedPartInspector, owner_filter: OptionButton,
        all_slots: Dictionary) -> void:
    var catalog := StitchedParts.load_catalog(RAG_DUELIST)
    _check(bool(catalog.get("ok", false)), "Rag Duelist independently validates")
    if not bool(catalog.get("ok", false)):
        return
    var by_id: Dictionary = catalog["by_id"]
    var owner_index := StitchedPartInspector.OWNERS.find("rag_duelist")
    _check(_owner_label(owner_filter, "rag_duelist", "Rag Duelist"),
        "Rag Duelist is named in the existing owner selector")
    if owner_index < 0:
        return
    owner_filter.select(owner_index)
    owner_filter.item_selected.emit(owner_index)
    _check(inspector.selected_owner == "rag_duelist" and not owner_filter.disabled,
        "mounted owner selector chooses Rag Duelist")
    for slot in StitchedPartInspector.SLOTS:
        var button := inspector.get_node("CatalogPanel/Slot" + slot.capitalize()) as Button
        await _click(button)
        var visible := inspector.visible_part_ids_in_slot(slot)
        var rows := inspector.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer
        _check(inspector.active_slot == slot and button.button_pressed
            and visible.size() == 2 and rows.get_child_count() == 2
            and inspector.part_ids_in_slot(slot) == all_slots[slot],
            "Rag has two real rows in %s, with full slot index unchanged" % slot)
        for expected in RAG_PATCHES[slot]:
            var id := str(expected["id"])
            var name := str(expected["name"])
            var thread := str(expected["thread"])
            _check(by_id.has(id) and visible.has(id)
                and str(by_id[id]["slot"]) == slot
                and str(by_id[id]["owner"]) == "rag_duelist"
                and str(by_id[id]["name"]) == name
                and StitchedSewnPatches.thread_of(id) == thread,
                "Rag validated source names exact patch, owner, slot and maker thread: " + id)
            if not by_id.has(id):
                continue
            var row := rows.get_node_or_null("Part_" + id) as Button
            _check(row != null and row.text == "%s   /   rag_duelist" % name,
                "Rag has actual selectable authored row: " + id)
            _source_witness(inspector, by_id[id])
            _check(inspector.selected_part_id == id and inspector.active_slot == slot
                and _line(inspector, "PartName") == name
                and _line(inspector, "PartMeta").contains("THREAD: " + thread.to_upper())
                and _no_retired_readouts(inspector) and _cloth_copy(inspector, slot),
                "Rag selected metadata has no retired ability or numerical projection: " + id)
            var icon := "res://assets/paper/stitched/patches/" + id + ".png"
            _check(ResourceLoader.exists(icon)
                and StitchedSewnPatches.icon_path(id, slot) == icon
                and _texture_path(_preview(inspector)) == icon
                and _preview(inspector).visible,
                "Rag exact-ID PNG is mounted instead of a fallback: " + id)
            if id == "rag_duelist_head_feather_feint" or id == "rag_duelist_arms_rapier_lunge":
                for tier in [1, 2, 3]:
                    await _source_tier(inspector, by_id[id], tier)
        _check(not inspector.select_part("warden_head_pot_helm_bonk")
            and inspector.selected_owner == "rag_duelist" and _no_retired_readouts(inspector),
            "Rag-only slot refuses foreign ID and retired combat readouts: " + slot)


## The Scarecrow is an existing maker, not an equip action. Prove all eight
## source records through the real owner, slot and row controls with exact art.
func _browse_scarecrow(inspector: StitchedPartInspector, owner_filter: OptionButton,
        all_slots: Dictionary) -> void:
    var catalog := StitchedParts.load_catalog(SCARECROW)
    _check(bool(catalog.get("ok", false)), "Scarecrow authored source independently validates")
    if not bool(catalog.get("ok", false)):
        return
    var by_id: Dictionary = catalog["by_id"]
    _check(_owner_label(owner_filter, "scarecrow", "Scarecrow"),
        "Scarecrow is a named option in the existing owner dropdown")
    var owner_index := StitchedPartInspector.OWNERS.find("scarecrow")
    if owner_index < 0:
        return
    owner_filter.select(owner_index)
    owner_filter.item_selected.emit(owner_index)
    _check(inspector.selected_owner == "scarecrow" and not owner_filter.disabled
        and owner_filter.get_selected_id() == owner_index,
        "mounted dropdown filters real Scarecrow parts")
    _check(StitchedSewnPatches.border_path(1).is_empty()
        and not StitchedSewnPatches.border_path(2).is_empty()
        and not StitchedSewnPatches.border_path(3).is_empty(),
        "authored Plain, Double and Gold thread borders are available")
    for slot in StitchedPartInspector.SLOTS:
        var source_ids: Array[String] = []
        for part in catalog["parts"]:
            if str(part["slot"]) == slot:
                source_ids.append(str(part["id"]))
        _check(source_ids.size() == 2,
            "independent Scarecrow source has two sewn cloth entries in " + slot)
        var slot_button := inspector.get_node("CatalogPanel/Slot" + slot.capitalize()) as Button
        await _click(slot_button)
        var visible := inspector.visible_part_ids_in_slot(slot)
        var rows := inspector.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer
        var source_matches := visible.size() == source_ids.size()
        for id in visible:
            source_matches = source_matches and source_ids.has(id)
        _check(inspector.active_slot == slot and slot_button.button_pressed
            and visible.size() == 2 and source_matches
            and rows.get_child_count() == visible.size()
            and inspector.part_ids_in_slot(slot) == all_slots[slot],
            "physical %s slot shows only two real Scarecrow rows, full index intact" % slot)
        for expected in SCARECROW_PATCHES[slot]:
            var id := str(expected["id"])
            var name := str(expected["name"])
            var thread := str(expected["thread"])
            _check(by_id.has(id) and source_ids.has(id) and visible.has(id),
                "independent source and mounted %s tab both contain %s" % [slot, id])
            if not by_id.has(id):
                continue
            var part: Dictionary = by_id[id]
            _check(str(part["name"]) == name and str(part["slot"]) == slot
                and str(part["owner"]) == "scarecrow"
                and StitchedSewnPatches.thread_of(id) == thread,
                "Scarecrow authored name, slot, owner and maker thread: " + id)
            var row := rows.get_node_or_null("Part_" + id) as Button
            _check(row != null and row.is_visible_in_tree()
                and row.text == "%s   /   scarecrow" % name,
                "authentic Scarecrow part has a clickable existing row: " + id)
            if row == null:
                continue
            await _click(row)
            _check(inspector.selected_part_id == id and inspector.active_slot == slot
                and inspector.selected_owner == "scarecrow" and inspector.selected_tier == 1
                and _line(inspector, "PartName") == name
                and _line(inspector, "PartMeta").contains("SLOT: " + slot.to_upper())
                and _line(inspector, "PartMeta").contains("OWNER: scarecrow")
                and _line(inspector, "PartMeta").contains("ID: " + id)
                and _line(inspector, "PartMeta").contains("THREAD: " + thread.to_upper())
                and _no_retired_readouts(inspector) and _cloth_copy(inspector, slot),
                "clicking real Scarecrow row shows authored identity without old combat data: " + id)
            var icon := "res://assets/paper/stitched/patches/" + id + ".png"
            _check(ResourceLoader.exists(icon)
                and StitchedSewnPatches.icon_path(id, slot) == icon
                and _texture_path(_preview(inspector)) == icon
                and _preview(inspector).visible,
                "Scarecrow uses its exact sewn-patch PNG rather than fallback: " + id)
            _source_witness(inspector, part)
            # The witness rebuilds the button rows: wait for the new layout
            # before finding and clicking the next real row.
            await _frames()
            if id == "scarecrow_head_sack_glare" or id == "scarecrow_arms_fork_jab":
                for tier in [1, 2, 3]:
                    await _source_tier(inspector, part, tier)
        _check(_no_retired_readouts(inspector) and _cloth_copy(inspector, slot),
            "switching Scarecrow slots never exposes retired abilities or numbers: " + slot)
    var selected := inspector.selected_part_id
    _check(not inspector.select_part("warden_head_pot_helm_bonk")
        and not inspector.select_owner("unknown_maker")
        and not inspector.select_part("fictional_scarecrow_patch")
        and inspector.selected_part_id == selected
        and inspector.selected_owner == "scarecrow",
        "Scarecrow-only view refuses foreign and unknown part IDs or forged owners")


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
            "felt_bulwark_button_shield",
            "lantern_monk_head_moth_wink", "lantern_monk_arms_wick_spark",
            "button_golem_head_loose_pop", "button_golem_arms_button_fist",
            "rag_duelist_head_feather_feint", "rag_duelist_head_tattered_snare",
            "rag_duelist_arms_rapier_lunge", "rag_duelist_arms_needle_prick",
            "rag_duelist_torso_cape_parry", "rag_duelist_torso_duelist_reprise",
            "rag_duelist_legs_cape_slip", "rag_duelist_legs_cape_flourish"]:
        _check(actual_ids.has(id), "validated source actually contains witness " + id)
    for slot in StitchedPartInspector.SLOTS:
        for expected in SCARECROW_PATCHES[slot]:
            _check(actual_ids.has(str(expected["id"])),
                "combined validated catalogs include Scarecrow " + str(expected["id"]))
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
    _check(owner_filter != null
        and _owner_label(owner_filter, "all", "All")
        and _owner_label(owner_filter, "yarn_ranger", "Yarn Ranger")
        and _owner_label(owner_filter, "lantern_monk", "Lantern Monk")
        and _owner_label(owner_filter, "button_golem", "Button Golem")
        and _owner_label(owner_filter, "rag_duelist", "Rag Duelist")
        and _owner_label(owner_filter, "any", "Spoils")
        and _owner_label(owner_filter, "scarecrow", "Scarecrow")
        and owner_filter.focus_mode == Control.FOCUS_ALL
        and root.get_visible_rect().encloses(owner_filter.get_global_rect()),
        "Gothic owner filter has named groups without assuming a global count or Spoils index")
    _check(_no_retired_readouts(inspector)
        and _preview(inspector).get_global_rect().size == Vector2(176, 176)
        and root.get_visible_rect().encloses(_preview(inspector).get_global_rect()),
        "real mounted Reliquary has passive readable patch art and no attack projections")
    var all_sources_once := true
    for path in SOURCES:
        all_sources_once = all_sources_once and guide.catalog_paths.count(path) == 1
    _check(all_sources_once and guide.catalog_paths.size() > 8
        and guide.catalog_paths[8] == SCARECROW and inspector.selected_owner == "all",
        "live guide appends the Scarecrow source at index 8 once, preserving every old index")
    var all_head := inspector.part_ids_in_slot("head")
    var all_slots: Dictionary = {}
    for slot in StitchedPartInspector.SLOTS:
        all_slots[slot] = inspector.part_ids_in_slot(slot)
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
    await _browse_new_maker(inspector, owner_filter, "lantern_monk", LANTERN_MONK,
        "lantern_monk_head_moth_wink", "lantern_monk_arms_wick_spark", all_slots)
    await _browse_new_maker(inspector, owner_filter, "button_golem", BUTTON_GOLEM,
        "button_golem_head_loose_pop", "button_golem_arms_button_fist", all_slots)
    await _browse_rag_duelist(inspector, owner_filter, all_slots)
    await _browse_scarecrow(inspector, owner_filter, all_slots)
    _check(inspector.select_owner("all") and
        inspector.visible_part_ids_in_slot("head") == all_head,
        "All recovers original combined index after browsing the added makers")
    _check(inspector.select_owner("warden") and inspector.select_part("warden_head_pot_helm_bonk"),
        "Warden group remains browseable")
    _check(inspector.select_owner("any") and inspector.select_part("scissor_crab_claw_arm"),
        "Spoils owner group browses actual foe parts")
    _check(inspector.select_owner("all") and inspector.visible_part_ids_in_slot("head") == all_head,
        "All restores the same alphabetical full-catalog HEAD rows")
    for id in ["warden_head_pot_helm_bonk", "scissor_crab_claw_arm",
            "moth_swarm_wings", "felt_bulwark_button_shield",
            "lantern_monk_head_moth_wink", "lantern_monk_arms_wick_spark",
            "button_golem_head_loose_pop", "button_golem_arms_button_fist",
            "rag_duelist_head_feather_feint", "rag_duelist_head_tattered_snare",
            "rag_duelist_arms_rapier_lunge", "rag_duelist_arms_needle_prick",
            "rag_duelist_torso_cape_parry", "rag_duelist_torso_duelist_reprise",
            "rag_duelist_legs_cape_slip", "rag_duelist_legs_cape_flourish"]:
        _source_witness(inspector, actual_ids[id])
    _check((inspector.get_node("DetailsPanel/TierHeading") as Label).text == "STITCH FINISH"
        and (inspector.get_node("DetailsPanel/TierI") as Button).text == "Plain"
        and (inspector.get_node("DetailsPanel/TierII") as Button).text == "Double"
        and (inspector.get_node("DetailsPanel/TierIII") as Button).text == "Gold thread"
        and _preview(inspector).get_global_rect() == _border(inspector).get_global_rect()
        and _preview(inspector).get_global_rect().size == Vector2(176, 176)
        and _preview(inspector).mouse_filter == Control.MOUSE_FILTER_IGNORE
        and _border(inspector).mouse_filter == Control.MOUSE_FILTER_IGNORE
        and _preview(inspector).focus_mode == Control.FOCUS_NONE
        and _border(inspector).focus_mode == Control.FOCUS_NONE,
        "real mounted inspector retains three focusable stitch finishes and passive enlarged art")
    _check(StitchedSewnPatches.favoured_slot("warden") == "torso"
        and StitchedSewnPatches.favoured_slot("seamstress") == "arms"
        and StitchedSewnPatches.is_foe_patch("scissor_crab_claw_arm"),
        "mounted guidance uses authored S13 maker favours and foe identity")
    _witness(inspector, "warden_head_pot_helm_bonk", "Pot Helm Bonk", "head", "warden")
    _check(_line(inspector, "PartText") == "Cloth for HEAD; Warden favours TORSO. Moves stay with the doll.",
        "mounted Warden head clearly favours TORSO, not a granted move")
    _check(inspector.select_owner("seamstress") and inspector.select_part("seamstress_mending_knot_hat")
        and _line(inspector, "PartText") == "Cloth for HEAD; Seamstress favours ARMS. Moves stay with the doll.",
        "mounted owner switch replaces Warden seam with Seamstress ARMS guidance")
    _check(inspector.select_owner("all") and inspector.select_part("warden_head_pot_helm_bonk")
        and _cloth_copy(inspector, "head"),
        "All restores maker-specific Warden copy after owner switch")
    await _tier(inspector, "warden_head_pot_helm_bonk", 1)
    await _tier(inspector, "warden_head_pot_helm_bonk", 3)
    _witness(inspector, "scissor_crab_claw_arm", "Scissor Claw", "arms", "any")
    _check(_line(inspector, "PartText") ==
        "Foe cloth for ARMS; may fray a doll outside its favoured seam. Moves stay with the doll."
        and not _line(inspector, "PartText").contains("Warden")
        and not _line(inspector, "PartText").contains("Seamstress"),
        "mounted foe part describes only conditional wearer fray, never a guessed doll")
    await _tier(inspector, "scissor_crab_claw_arm", 1)
    await _tier(inspector, "scissor_crab_claw_arm", 2)
    _witness(inspector, "moth_swarm_wings", "Tatter Wings", "legs", "any")
    await _tier(inspector, "moth_swarm_wings", 3)
    _witness(inspector, "felt_bulwark_button_shield", "Button Shield Torso", "torso", "any")
    _check(_no_retired_readouts(inspector) and _cloth_copy(inspector, "torso")
        and _line(inspector, "PartText").contains("may fray a doll outside its favoured seam"),
        "foe torso cloth warns conditionally without promising old ally guard or damage")
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
        and inspector.select_part("scissor_crab_claw_arm")
        and _cloth_copy(inspector, "arms")
        and _line(inspector, "PartText").contains("may fray a doll outside its favoured seam"),
        "re-entry restores the foe warning with the new selection, not stale hero copy")
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
        and _line(inspector, "PartText").is_empty()
        and _no_retired_readouts(inspector)
        and _preview(inspector).texture == null and _border(inspector).texture == null
        and guide.atlas_status.text.contains("UNAVAILABLE")
        and root.gui_get_focus_owner() != inspector.get_node("CloseButton"),
        "missing original FOE catalog rejects whole atlas without stale rows, stats or focus")
    guide.catalog_paths[4] = FOES
    await _click(guide.atlas_button)
    _check(inspector.is_visible_in_tree() and inspector.select_part("moth_swarm_wings")
        and _cloth_copy(inspector, "legs")
        and guide.get_children().filter(func(node: Node) -> bool:
            return node is StitchedPartInspector).size() == 1,
        "valid retry restores current foe leg copy and authentic catalog exactly once")
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
        "missing original Seamstress source fails whole atlas closed with no stale owner, row or focus")
    guide.catalog_paths[1] = SEAMSTRESS
    await _click(guide.atlas_button)
    _check(inspector.is_visible_in_tree()
        and inspector.select_part("seamstress_mending_knot_hat")
        and _cloth_copy(inspector, "head")
        and not _line(inspector, "PartText").contains("may fray")
        and inspector.selected_owner == "all"
        and guide.get_children().filter(func(node: Node) -> bool:
            return node is StitchedPartInspector).size() == 1,
        "new hero catalog restores on retry without duplicate inspector")
    await _key(KEY_ESCAPE)
    _check(not inspector.visible and inspector.selected_part_id.is_empty(),
        "new-missing-source tests begin with a cleared, closed atlas")
    await _click(guide.atlas_button)
    _check(inspector.is_visible_in_tree()
        and inspector.select_part("scarecrow_head_sack_glare")
        and _texture_path(_preview(inspector)) ==
            "res://assets/paper/stitched/patches/scarecrow_head_sack_glare.png",
        "authentic Scarecrow cloth is displayed before missing-source retry")
    await _key(KEY_ESCAPE)
    _check(not inspector.visible and inspector.selected_part_id.is_empty(),
        "Scarecrow cloth clears before failed re-open")
    seed(568263)
    var new_failure_expected_draw := randi()
    seed(568263)
    var before_new_failures := _state()
    for injection in [
            [5, LANTERN_MONK, "lantern_monk_head_moth_wink"],
            [6, BUTTON_GOLEM, "button_golem_head_loose_pop"],
            [7, RAG_DUELIST, "rag_duelist_head_feather_feint"],
            [8, SCARECROW, "scarecrow_head_sack_glare"]]:
        var index: int = injection[0]
        var authentic_path: String = injection[1]
        var authentic_id: String = injection[2]
        guide.catalog_paths[index] = "res://data/parts/missing_maker_%d.json" % index
        await _click(guide.atlas_button)
        _check(guide.is_open() and not inspector.visible
            and not guide._atlas_is_open() and inspector.selected_part_id.is_empty()
            and inspector.selected_owner == "all" and owner_filter.disabled
            and inspector.part_ids_in_slot("head").is_empty()
            and inspector.visible_part_ids_in_slot("head").is_empty()
            and (inspector.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer).get_child_count() == 0
            and not inspector.select_part(authentic_id)
            and not inspector.select_part("scarecrow_head_sack_glare")
            and not inspector.select_owner("scarecrow") and not inspector.select_tier(2)
            and _line(inspector, "PartText").is_empty() and _no_retired_readouts(inspector)
            and _preview(inspector).texture == null and _border(inspector).texture == null
            and guide._atlas_focus_buttons().is_empty()
            and root.gui_get_focus_owner() != owner_filter
            and root.gui_get_focus_owner() != inspector.get_node("CloseButton")
            and guide.atlas_status.text.contains("UNAVAILABLE"),
            "missing maker catalog at index %d refuses entire atlas with no rows, focus or stale art" % index)
        guide.catalog_paths[index] = authentic_path
        await _click(guide.atlas_button)
        _check(inspector.is_visible_in_tree() and inspector.select_part(authentic_id)
            and inspector.selected_owner == "all"
            and _texture_path(_preview(inspector)) ==
                StitchedSewnPatches.icon_path(authentic_id, str(inspector.active_slot))
            and _cloth_copy(inspector, str(inspector.active_slot))
            and guide.get_children().filter(func(node: Node) -> bool:
                return node is StitchedPartInspector).size() == 1,
            "restored real maker at index %d reloads once, including its authored ID" % index)
        await _key(KEY_ESCAPE)
        _check(not inspector.visible and inspector.selected_part_id.is_empty(),
            "maker retry index %d closes and clears the inspector" % index)
    _check(_state() == before_new_failures and randi() == new_failure_expected_draw,
        "all missing-maker failures and retries leave village state and global RNG unchanged")
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
        and _line(inspector, "PartText").is_empty()
        and _no_retired_readouts(inspector)
        and _preview(inspector).texture == null and _border(inspector).texture == null
        and guide.atlas_status.text.contains("UNAVAILABLE"),
        "direct Parts doorway also rejects a partial catalog with no stale rows or facts")
    await _key(KEY_ESCAPE)
    _check(view.parts_button.has_focus() and not view.parts_button.disabled,
        "failed direct doorway restores Parts focus")
    guide.catalog_paths[4] = FOES
    await _click(view.parts_button)
    _check(inspector.is_visible_in_tree() and inspector.select_part("scissor_crab_claw_arm")
        and inspector.select_part("rag_duelist_arms_rapier_lunge")
        and _texture_path(_preview(inspector)) ==
            "res://assets/paper/stitched/patches/rag_duelist_arms_rapier_lunge.png"
        and _line(inspector, "PartMeta").contains("THREAD: INDIGO")
        and _no_retired_readouts(inspector),
        "direct Sewing Tin Parts recovers authentic foe and Rag inspection")
    view.close_village()
    _check(not guide.is_open() and not inspector.visible and entry.disabled
        and not view.has_open_village() and inspector.selected_part_id.is_empty(),
        "parent close clears nested panel, guard, selection and village entry")
    var sources_unchanged := true
    for path in SOURCES:
        sources_unchanged = sources_unchanged and originals[path] == FileAccess.get_file_as_string(path)
    _check(sources_unchanged, "all named authored JSON files remain byte-for-byte unchanged")
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
