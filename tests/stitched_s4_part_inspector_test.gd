extends SceneTree
## Mounts the real read-only S4 reliquary twice, using only validated S1a fixture data.

const SCENE := "res://scenes/stitched_part_inspector.tscn"
const FIXTURE := "res://tests/fixtures/stitched_s1a_parts.json"
const SEAMSTRESS_PATH := "res://data/parts/seamstress_parts.json"
const BOBBIN_PART := "seamstress_bobbin_snag_spools"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
    _run.call_deferred()


func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)


func _line(panel: Control, label_name: String) -> String:
    return str(panel.get_node("DetailsPanel/" + label_name).text)


func _texture_path(preview: TextureRect) -> String:
    return preview.texture.resource_path if preview.texture != null else ""


func _preview(panel: Control) -> TextureRect:
    return panel.get_node("DetailsPanel/PatchPreview") as TextureRect


func _border(panel: Control) -> TextureRect:
    return panel.get_node("DetailsPanel/TierBorderPreview") as TextureRect


func _empty_preview(panel: Control) -> bool:
    return _preview(panel).texture == null and _border(panel).texture == null and (
        not _preview(panel).visible and not _border(panel).visible) and (
        not _line(panel, "PartMeta").contains("THREAD:")) and (
        _line(panel, "PartText").is_empty() and _no_retired_readouts(panel))


func _no_retired_readouts(panel: Control) -> bool:
    for name in ["StatLine", "AbilityLine", "RanksLine", "NumbersLine",
            "EffectsLine", "MovementLine"]:
        if not _line(panel, name).is_empty():
            return false
    return true


func _maker_matches(panel: Control, id: String) -> bool:
    var maker := StitchedSewnPatches.thread_of(id)
    var meta := _line(panel, "PartMeta")
    if maker.is_empty():
        return not meta.contains("THREAD:")
    return meta.contains("\nTHREAD: " + maker.to_upper())


func _cloth_copy(panel: Control, slot: String) -> bool:
    var text := _line(panel, "PartText")
    return text == ("Sewn on the doll's %s. Its battle moves belong to the doll, not this cloth patch." % slot.to_upper())


func _assert_helm(panel: StitchedPartInspector, tier: int) -> void:
    _check(panel.select_tier(tier), "finish %d selectable" % tier)
    _check(panel.selected_part_id == "warden_head_iron_helm" and panel.selected_tier == tier
        and _texture_path(_preview(panel)) == "res://assets/paper/stitched/patches/patch_head.png"
        and _texture_path(_border(panel)) == StitchedSewnPatches.border_path(tier)
        and _border(panel).visible == (tier != 1),
        "finish %d keeps Iron Helm and its same base cloth with correct border" % tier)
    _check(_no_retired_readouts(panel) and _cloth_copy(panel, "head")
        and not _line(panel, "PartMeta").contains("TIER ")
        and not _line(panel, "PartMeta").contains("THREAD:"),
        "finish %d never claims retired combat stats, tiers or an invented maker" % tier)


func _run() -> void:
    root.size = Vector2i(1280, 720)
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
    _check(raw is Dictionary and raw.has("parts"), "authored fixture is present and parseable")
    if not raw is Dictionary or not raw.has("parts"):
        _finish()
        return
    var catalog := StitchedParts.build_catalog(raw["parts"])
    _check(bool(catalog.get("ok", false)), "real S1a fixture passes StitchedParts validation")
    if not catalog.get("ok", false):
        _finish()
        return
    var warden_parts: Array = []
    var foreign: Dictionary = {}
    for entry in catalog["parts"]:
        if entry["owner"] == "warden":
            warden_parts.append(entry)
        elif entry["id"] == "any_torso_felt_coat":
            foreign = entry
    _check(warden_parts.size() == 8 and not foreign.is_empty(),
        "fixture supplies eight Warden parts and a foreign heal")
    if warden_parts.size() != 8 or foreign.is_empty():
        _finish()
        return
    var source_copy := warden_parts.duplicate(true)
    var foreign_copy := foreign.duplicate(true)
    var packed := load(SCENE) as PackedScene
    _check(packed != null, "inspector PackedScene loads independently")
    if packed == null:
        _finish()
        return
    var expected_order: Dictionary = {}
    for cycle in range(2):
        var panel := packed.instantiate() as StitchedPartInspector
        _check(panel != null, "scene uses the public StitchedPartInspector script")
        if panel == null:
            break
        root.add_child(panel)
        await process_frame
        _check(panel.size == Vector2(1280, 720) and panel.theme == load("res://themes/gothic_theme.tres"),
            "1280x720 panel inherits shipped Gothic Theme")
        var close: Button = panel.get_node("CloseButton")
        var focus_style: StyleBox = close.get_theme_stylebox("focus")
        _check(close.focus_mode == Control.FOCUS_ALL and focus_style != null and
            focus_style == panel.theme.get_stylebox("focus", "Button"),
            "Close uses keyboard focus and the inherited amber focus chrome")
        var slot_controls := ["SlotHead", "SlotArms", "SlotTorso", "SlotLegs"]
        for name in slot_controls:
            var control: Button = panel.get_node("CatalogPanel/" + name)
            _check(control.focus_mode == Control.FOCUS_ALL and control.toggle_mode and
                control.get_theme_stylebox("focus") == focus_style,
                "%s has a focusable Gothic selector" % name)
        var emits := [0]
        panel.close_requested.connect(func() -> void: emits[0] += 1)
        var parts_input: Array = warden_parts.duplicate(true)
        if cycle == 1:
            parts_input.reverse()
        var witness_seed := 197844 + cycle
        seed(witness_seed)
        var expected_draw := randi()
        seed(witness_seed)
        _check(panel.present_parts(parts_input), "Warden fixture mounts without app wiring")
        var owner_control := panel.get_node("CatalogPanel/OwnerFilter") as OptionButton
        _check(owner_control.get_item_count() == 8
            and owner_control.get_item_text(0) == "All"
            and owner_control.get_item_text(4) == "Yarn Ranger"
            and owner_control.get_item_text(5) == "Lantern Monk"
            and owner_control.get_item_text(6) == "Button Golem"
            and owner_control.get_item_text(7) == "Spoils",
            "original detached inspector exposes eight ordered maker/spoils labels")
        var fixture_head_ids := panel.part_ids_in_slot("head")
        for maker in ["lantern_monk", "button_golem"]:
            var maker_index := StitchedPartInspector.OWNERS.find(maker)
            owner_control.select(maker_index)
            owner_control.item_selected.emit(maker_index)
            _check(panel.selected_owner == maker and owner_control.get_selected_id() == maker_index
                and panel.selected_part_id.is_empty()
                and panel.visible_part_ids_in_slot("head").is_empty()
                and panel.part_ids_in_slot("head") == fixture_head_ids
                and (panel.get_node("CatalogPanel/PartScroll/PartRows") as VBoxContainer).get_child_count() == 0
                and _empty_preview(panel) and not panel.select_tier(2)
                and not panel.select_part("warden_head_iron_helm"),
                "new %s owner is selectable but cannot invent missing fixture rows" % maker)
        owner_control.select(0)
        owner_control.item_selected.emit(0)
        _check(panel.selected_owner == "all"
            and panel.visible_part_ids_in_slot("head") == fixture_head_ids
            and not panel.selected_part_id.is_empty(),
            "All restores the genuine detached fixture after selecting absent makers")
        var head_rows: VBoxContainer = panel.get_node("CatalogPanel/PartScroll/PartRows")
        _check(head_rows.get_child_count() == 2 and
            head_rows.get_child(0) is Button and head_rows.get_child(1) is Button,
            "head slot renders both real selectable parts")
        head_rows.get_child(0).pressed.emit()
        _check(panel.selected_part_id == panel.part_ids_in_slot("head")[0] and
            _line(panel, "PartName") != "No part selected",
            "clicking a generated part row selects that exact authored entry")
        for slot in StitchedParts.SLOTS:
            var ids: Array[String] = panel.part_ids_in_slot(slot)
            _check(ids.size() == 2, "%s retains the two fixture entries" % slot)
            _check(panel.select_slot(slot) and
                head_rows.get_child_count() == 2 and
                not panel.selected_part_id.is_empty(),
                "slot %s shows two independent selectable rows" % slot)
            if cycle == 0:
                expected_order[slot] = ids.duplicate()
            else:
                _check(ids == expected_order[slot], "slot %s order ignores input order" % slot)
        panel.get_node("CatalogPanel/SlotHead").pressed.emit()
        _check(panel.active_slot == "head" and head_rows.get_child_count() == 2,
            "physical head selector navigates back to its rows")
        _check(panel.select_part("warden_head_iron_helm"), "Iron Helm public selection works")
        _check(_texture_path(_preview(panel)) ==
            "res://assets/paper/stitched/patches/patch_head.png"
            and _preview(panel).visible and _texture_path(_border(panel)).is_empty()
            and not _line(panel, "PartMeta").contains("THREAD:"),
            "fixture Iron Helm uses slot-head fallback without invented maker thread or knot")
        _check(_line(panel, "PartName") == "Iron Helm" and
            _line(panel, "PartMeta").contains("OWNER: warden") and
            _line(panel, "PartMeta").contains("SLOT: HEAD") and
            _line(panel, "PartMeta").contains("ID: warden_head_iron_helm")
            and _cloth_copy(panel, "head") and _no_retired_readouts(panel),
            "head renders genuine name/owner/slot/ID and doll-owned battle-move copy")
        _assert_helm(panel, 1)
        panel.get_node("DetailsPanel/TierII").pressed.emit()
        _check(panel.selected_tier == 2 and _no_retired_readouts(panel)
            and (panel.get_node("DetailsPanel/TierII") as Button).button_pressed,
            "clicking Double selects finish II without resurrecting attack numbers")
        _check(_texture_path(_preview(panel)).ends_with("patch_head.png")
            and _texture_path(_border(panel)).ends_with("border_2.png")
            and _border(panel).visible, "fixture tier II adds actual double-stitch overlay")
        _assert_helm(panel, 2)
        panel.get_node("DetailsPanel/TierIII").pressed.emit()
        _check(_texture_path(_preview(panel)).ends_with("patch_head.png")
            and _texture_path(_border(panel)).ends_with("border_3.png")
            and _border(panel).visible, "fixture tier III adds actual gold-thread overlay")
        _assert_helm(panel, 3)
        _check(_no_retired_readouts(panel) and _cloth_copy(panel, "head"),
            "Gold thread finish never exposes retired crit, damage or move projections")
        _check(not panel.select_tier(0) and not panel.select_tier(4) and
            panel.selected_tier == 3 and panel.selected_part_id == "warden_head_iron_helm" and
            not panel.select_part("unknown_helm") and
            _texture_path(_preview(panel)).ends_with("patch_head.png") and
            _texture_path(_border(panel)).ends_with("border_3.png"),
            "invalid tier or unknown ID cannot change selection or artwork")
        _check(panel.select_part("warden_torso_quilt") and panel.selected_tier == 1,
            "different slot part resets to tier I")
        _check(panel.select_tier(3) and _cloth_copy(panel, "torso")
            and _no_retired_readouts(panel)
            and _texture_path(_preview(panel)).ends_with("patch_torso.png")
            and _texture_path(_border(panel)).ends_with("border_3.png"),
            "torso is shown as sewn cloth, with gold-thread border but no HP/buff promise")
        _check(panel.select_part("warden_arm_brace") and _cloth_copy(panel, "arms")
            and _no_retired_readouts(panel)
            and _texture_path(_preview(panel)).ends_with("patch_arms.png")
            and _texture_path(_border(panel)).is_empty(),
            "arms are a plain sewn patch, not a guard move or ally-target forecast")
        _check(panel.select_part("warden_legs_stride") and _cloth_copy(panel, "legs")
            and _no_retired_readouts(panel) and _texture_path(_border(panel)).is_empty(),
            "legs are sewn cloth, not a granted movement ability or pose")
        var mixed := [warden_parts[0].duplicate(true), foreign.duplicate(true), warden_parts[4].duplicate(true)]
        _check(panel.present_parts(mixed) and panel.part_ids_in_slot("torso").size() == 2 and
            panel.part_ids_in_slot("head").size() == 1,
            "mixed satchel retains all owner types and does not demand a full hero kit")
        _check(panel.select_part("any_torso_felt_coat") and _cloth_copy(panel, "torso")
            and _no_retired_readouts(panel)
            and _line(panel, "PartMeta").contains("OWNER: any")
            and _line(panel, "PartMeta").contains("ID: any_torso_felt_coat"),
            "foreign torso keeps genuine identity without promising a heal or stat bonus")
        _check(not panel.present_parts([{"id": "invalid"}]) and
            panel.selected_part_id.is_empty() and head_rows.get_child_count() == 0 and
            _line(panel, "NumbersLine").is_empty() and _empty_preview(panel),
            "bad entry fails closed and wipes previous part details and artwork")
        _check(not panel.present_parts({ "parts": warden_parts }) and
            panel.selected_part_id.is_empty() and not panel.select_tier(1) and _empty_preview(panel),
            "non-array catalog fails closed without artwork")
        _check(not panel.present_parts([]) and
            panel.selected_part_id.is_empty() and
            _line(panel, "PartName") == "No part selected" and _empty_preview(panel),
            "empty array restores clear empty state and clears artwork")
        _check(not panel.select_part("warden_head_iron_helm"),
            "cleared catalog cannot resurrect an old ID")
        _check(panel.present_parts(warden_parts) and
            panel.select_part("warden_head_iron_helm"),
            "valid parts can be presented after a rejection")
        close.pressed.emit()
        _check(emits[0] == 1, "one Close press emits exactly one request")
        close.pressed.emit()
        _check(emits[0] == 2, "second Close press emits exactly one further request")
        _check(randi() == expected_draw, "repeated selection and Close consume zero global RNG draws")
        _check(warden_parts == source_copy and foreign == foreign_copy and
            parts_input == (source_copy if cycle == 0 else _reversed(source_copy)),
            "source parts and passed arrays are not mutated")
        panel.free()
        await process_frame
        _check(not is_instance_valid(panel), "mount/free cycle %d leaves no inspector node" % cycle)
    await _test_live_owners(packed)
    _finish()


func _test_live_owners(packed: PackedScene) -> void:
    var paths := [
        "res://data/parts/warden_parts.json",
        "res://data/parts/seamstress_parts.json",
        "res://data/parts/tinker_parts.json",
        "res://data/parts/yarn_ranger_parts.json",
        "res://data/parts/enemy_parts.json",
        "res://data/parts/lantern_monk_parts.json",
        "res://data/parts/button_golem_parts.json",
    ]
    var input: Array = []
    var source: Dictionary = {}
    for path in paths:
        var catalog := StitchedParts.load_catalog(path)
        _check(bool(catalog.get("ok", false)), "independent live source validates: " + path)
        if not bool(catalog.get("ok", false)):
            return
        input.append_array(catalog["parts"])
    var pristine := input.duplicate(true)
    for part in input:
        source[str(part["id"])] = part
    var witness_ids := [
        "warden_head_pot_helm_bonk", "seamstress_mending_knot_hat",
        "tinker_head_cog_shot", "yarn_ranger_head_needle_nock",
        "scissor_crab_claw_arm", "moth_swarm_wings",
        "felt_bulwark_button_shield",
        "lantern_monk_head_moth_wink", "lantern_monk_arms_wick_spark",
        "button_golem_head_loose_pop", "button_golem_arms_button_fist",
    ]
    for id in witness_ids:
        _check(source.has(id), "combined seven real catalogs contain " + id)
    var panel := packed.instantiate() as StitchedPartInspector
    root.add_child(panel)
    await process_frame
    var owner_control := panel.get_node("CatalogPanel/OwnerFilter") as OptionButton
    _check(owner_control.get_item_count() == 8
        and owner_control.get_item_text(5) == "Lantern Monk"
        and owner_control.get_item_text(6) == "Button Golem"
        and owner_control.get_item_text(7) == "Spoils"
        and owner_control.focus_mode == Control.FOCUS_ALL
        and owner_control.get_theme_stylebox("focus") != null
        and root.get_visible_rect().encloses(owner_control.get_global_rect()),
        "Gothic owner dropdown is reachable and themed within 1280x720")
    seed(886124)
    var expected_draw := randi()
    seed(886124)
    _check(panel.present_parts(input) and panel.selected_owner == "all"
        and panel.part_ids_in_slot("head").has("tinker_head_cog_shot"),
        "standalone full validated atlas opens at All with source-backed rows")
    var all_head := panel.part_ids_in_slot("head")
    var preview := _preview(panel)
    var border := _border(panel)
    _check((panel.get_node("DetailsPanel/TierHeading") as Label).text == "STITCH FINISH"
        and (panel.get_node("DetailsPanel/TierI") as Button).text == "Plain"
        and (panel.get_node("DetailsPanel/TierII") as Button).text == "Double"
        and (panel.get_node("DetailsPanel/TierIII") as Button).text == "Gold thread"
        and (panel.get_node("DetailsPanel/TierI") as Button).focus_mode == Control.FOCUS_ALL
        and (panel.get_node("DetailsPanel/TierII") as Button).focus_mode == Control.FOCUS_ALL
        and (panel.get_node("DetailsPanel/TierIII") as Button).focus_mode == Control.FOCUS_ALL,
        "the three original focusable controls name authentic stitch finishes")
    _check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE
        and border.mouse_filter == Control.MOUSE_FILTER_IGNORE
        and preview.focus_mode == Control.FOCUS_NONE
        and border.focus_mode == Control.FOCUS_NONE
        and preview.get_global_rect() == border.get_global_rect()
        and preview.get_global_rect().size == Vector2(96, 96)
        and root.get_visible_rect().encloses(preview.get_global_rect()),
        "shipped 96px aligned transparent art layers are passive and within viewport")
    for owner in ["warden", "seamstress", "tinker", "yarn_ranger",
            "lantern_monk", "button_golem", "any"]:
        var idx := StitchedPartInspector.OWNERS.find(owner)
        owner_control.select(idx)
        owner_control.item_selected.emit(idx)
        _check(panel.selected_owner == owner
            and panel.part_ids_in_slot("head") == all_head
            and panel.visible_part_ids_in_slot("head").size()
                == panel.get_node("CatalogPanel/PartScroll/PartRows").get_child_count(),
            "owner " + owner + " changes rows, not full validated index")
        var last_name := ""
        var last_id := ""
        for id in panel.visible_part_ids_in_slot("head"):
            var part: Dictionary = source[id]
            var part_name := str(part["name"]).to_lower()
            _check(str(part["owner"]) == owner,
                "every visible head row belongs to selected owner " + owner)
            _check(last_name.is_empty() or last_name < part_name or (
                last_name == part_name and last_id < id),
                "owner rows remain name/ID alphabetic")
            last_name = part_name
            last_id = id
    for group in [
            ["warden", "warden_head_pot_helm_bonk"],
            ["seamstress", "seamstress_mending_knot_hat"],
            ["tinker", "tinker_head_cog_shot"],
            ["yarn_ranger", "yarn_ranger_head_needle_nock"],
            ["lantern_monk", "lantern_monk_head_moth_wink"],
            ["button_golem", "button_golem_head_loose_pop"],
            ["any", "scissor_crab_claw_arm"]]:
        var owner: String = group[0]
        var id: String = group[1]
        var part: Dictionary = source[id]
        _check(panel.select_owner(owner) and panel.select_part(id),
            "owner and valid part are selectable: " + id)
        _check(_line(panel, "PartMeta").contains("OWNER: " + owner)
            and _line(panel, "PartName") == str(part["name"]),
            "group selection does not invent the ID or displayed name: " + id)
        _check(_texture_path(preview) == StitchedSewnPatches.icon_path(id, str(part["slot"]))
            and preview.visible and _texture_path(border).is_empty()
            and _maker_matches(panel, id)
            and not _line(panel, "PartMeta").contains("KNOT"),
            "selected live sourced patch has its own icon, actual maker thread, no set knot: " + id)
        if id == "warden_head_pot_helm_bonk" or id == "scissor_crab_claw_arm":
            _check(_texture_path(preview) ==
                "res://assets/paper/stitched/patches/" + id + ".png"
                and StitchedSewnPatches.thread_of(id) == "crimson"
                and _line(panel, "PartMeta").contains("THREAD: CRIMSON"),
                "named sewn-patch art and crimson thread explicitly authored: " + id)
        for tier in [1, 2, 3]:
            var tier_button := panel.get_node("DetailsPanel/Tier%s" % StitchedPartInspector.TIER_LABELS[tier - 1]) as Button
            tier_button.pressed.emit()
            _check(panel.selected_part_id == id and panel.selected_tier == tier
                and tier_button.button_pressed
                and _texture_path(preview) == StitchedSewnPatches.icon_path(id, str(part["slot"]))
                and _texture_path(border) == StitchedSewnPatches.border_path(tier)
                and border.visible == (tier != 1)
                and _maker_matches(panel, id),
                "real finish button changes border alone while keeping patch/thread: %s finish %d" % [id, tier])
            _check(panel.select_tier(tier) and _cloth_copy(panel, str(part["slot"]))
                and _no_retired_readouts(panel)
                and not _line(panel, "PartMeta").contains("TIER "),
                "real finish %d has stable sewn-cloth copy, not combat numbers: %s" % [tier, id])
        _check(not panel.select_tier(0) and not panel.select_tier(4)
            and not panel.select_owner("not_a_hero") and not panel.select_part("fictional")
            and panel.selected_part_id == id and panel.selected_tier == 3
            and _texture_path(preview) == StitchedSewnPatches.icon_path(id, str(part["slot"]))
            and _texture_path(border).ends_with("border_3.png"),
            "invalid tier, owner and part do not mutate selection or textures")
        _check(panel.select_slot("legs")
            and panel.active_slot == "legs" and not panel.selected_part_id.is_empty()
            and panel.selected_tier == 1,
            "owner " + owner + " can change slot and resets on a different part")
    _test_bobbin_patch_copy(panel, source)
    _check(panel.select_owner("all") and panel.visible_part_ids_in_slot("head") == all_head
        and panel.select_part("felt_bulwark_button_shield"),
        "All restores full rows and allows other-slot foreign torso")
    _check(panel.select_owner("seamstress")
        and not panel.select_part("felt_bulwark_button_shield")
        and panel.selected_owner == "seamstress",
        "filtered selection rejects valid but hidden IDs")
    var limited: Array = [source["scissor_crab_claw_arm"].duplicate(true)]
    _check(panel.present_parts(limited) and panel.selected_owner == "all"
        and panel.select_owner("tinker")
        and panel.selected_part_id.is_empty()
        and panel.visible_part_ids_in_slot("arms").is_empty()
        and panel.part_ids_in_slot("arms").has("scissor_crab_claw_arm")
        and _empty_preview(panel),
        "group without parts empties details/art, not the full source index")
    _check(not panel.select_tier(2) and not panel.select_part("scissor_crab_claw_arm")
        and _line(panel, "NumbersLine").is_empty()
        and not panel.select_owner("invalid"),
        "empty visible owner refuses stale tier, hidden part and invalid owner")
    _check(not panel.present_parts([{"id": "bad"}])
        and panel.selected_part_id.is_empty() and panel.selected_owner == "all"
        and owner_control.disabled and not panel.select_owner("warden")
        and _empty_preview(panel),
        "invalid re-presentation clears owner, selection, textures and disables dropdown")
    _check(panel.present_parts(input) and not owner_control.disabled
        and panel.selected_owner == "all",
        "full atlas recovers in All after invalid source")
    _check(input == pristine and randi() == expected_draw,
        "owner browsing never mutates input arrays or advances global RNG")
    panel.free()
    await process_frame


func _reversed(parts: Array) -> Array:
    var result := parts.duplicate(true)
    result.reverse()
    return result


## Independently loaded authored entry stays browsable, but its retired ability
## and tier-text forecasts must never reach the visible S13 cloth reference.
func _test_bobbin_patch_copy(panel: StitchedPartInspector, source: Dictionary) -> void:
    var catalog := StitchedParts.load_catalog(SEAMSTRESS_PATH)
    _check(bool(catalog.get("ok", false)) and catalog["by_id"].has(BOBBIN_PART),
        "the shipped Seamstress catalog validates and authors " + BOBBIN_PART)
    if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(BOBBIN_PART):
        return
    var part: Dictionary = catalog["by_id"][BOBBIN_PART]
    _check(source.has(BOBBIN_PART) and source[BOBBIN_PART] == part
        and str(part["slot"]) == "legs" and str(part["owner"]) == "seamstress"
        and part["tiers"].has("2") and part["tiers"].has("3"),
        "mounted Bobbin entry equals independent validated source, with three finishes")
    _check(panel.select_owner("seamstress") and panel.select_part(BOBBIN_PART)
        and panel.selected_tier == 1
        and _line(panel, "PartName") == str(part["name"])
        and _line(panel, "PartMeta").contains("ID: " + BOBBIN_PART)
        and _maker_matches(panel, BOBBIN_PART),
        "public owner/part selection retains genuine Bobbin identity and maker")
    var base := StitchedSewnPatches.icon_path(BOBBIN_PART, "legs")
    for tier in [1, 2, 3]:
        var button := panel.get_node("DetailsPanel/" + ["TierI", "TierII", "TierIII"][tier - 1]) as Button
        button.pressed.emit()
        _check(panel.selected_tier == tier and panel.selected_part_id == BOBBIN_PART
            and button.button_pressed and _texture_path(_preview(panel)) == base
            and _texture_path(_border(panel)) == StitchedSewnPatches.border_path(tier)
            and _border(panel).visible == (tier != 1),
            "Bobbin finish %d keeps its base cloth art with only the authored border" % tier)
        _check(_cloth_copy(panel, "legs") and _no_retired_readouts(panel)
            and _maker_matches(panel, BOBBIN_PART)
            and not _line(panel, "PartMeta").contains("TIER ")
            and not _line(panel, "PartText").contains("Mark")
            and not _line(panel, "PartText").contains("Tangled"),
            "Bobbin finish %d never projects old Mark/Tangled move prose" % tier)


func _finish() -> void:
    if failures.is_empty():
        print("PASS stitched_s4_part_inspector_test: %d checks, two mount/free cycles" % checks)
        quit(0)
    else:
        for message in failures:
            push_error("FAIL stitched_s4_part_inspector_test: " + message)
        print("FAIL stitched_s4_part_inspector_test: %d/%d checks failed" % [failures.size(), checks])
        quit(1)
