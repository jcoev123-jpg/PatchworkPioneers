extends SceneTree
## Mounts the real read-only S4 reliquary twice, using only validated S1a fixture data.

const SCENE := "res://scenes/stitched_part_inspector.tscn"
const FIXTURE := "res://tests/fixtures/stitched_s1a_parts.json"
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


func _assert_helm(panel: StitchedPartInspector, tier: int, acc: int, lo: int, hi: int) -> void:
    _check(panel.select_tier(tier), "tier %d selectable" % tier)
    var numbers := _line(panel, "NumbersLine")
    _check(numbers.contains("ACC: %d%%" % acc) and numbers.contains("DAMAGE: %d-%d" % [lo, hi]),
        "Iron Helm tier %d accurately shows ACC %d and damage %d-%d: %s" % [tier, acc, lo, hi, numbers])
    _check(_line(panel, "EffectsLine").contains("Weak 1") and
        _line(panel, "RanksLine").contains("LAUNCH: 1") and
        _line(panel, "RanksLine").contains("TARGET: ENEMY RANKS 1, 2") and
        _line(panel, "AbilityLine").contains("Iron Helm Bash") and
        _line(panel, "MovementLine").contains("POSE: attack"),
        "Iron Helm tier %d preserves real ability, ranks and Weak effect" % tier)
    _check(panel.selected_part_id == "warden_head_iron_helm" and panel.selected_tier == tier,
        "tier selection does not replace the part")


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
        _check(_line(panel, "PartName") == "Iron Helm" and
            _line(panel, "PartMeta").contains("OWNER: warden") and
            _line(panel, "PartMeta").contains("SLOT: HEAD") and
            _line(panel, "PartText").contains("front-rank foe") and
            _line(panel, "StatLine").contains("ACC +5"),
            "head renders actual name, metadata, rules text and ACC stat")
        _assert_helm(panel, 1, 90, 5, 8)
        panel.get_node("DetailsPanel/TierII").pressed.emit()
        _check(panel.selected_tier == 2 and _line(panel, "NumbersLine").contains("ACC: 92%"),
            "clicking actual tier-II button updates selected part values")
        _assert_helm(panel, 2, 92, 6, 9)
        _assert_helm(panel, 3, 95, 7, 11)
        _check(_line(panel, "NumbersLine").contains("CRIT: 8%"),
            "third-tier crit override displays")
        _check(not panel.select_tier(0) and not panel.select_tier(4) and
            panel.selected_tier == 3 and panel.selected_part_id == "warden_head_iron_helm" and
            not panel.select_part("unknown_helm"),
            "invalid tier or unknown ID cannot change selection")
        _check(panel.select_part("warden_torso_quilt") and panel.selected_tier == 1,
            "different slot part resets to tier I")
        _check(panel.select_tier(3) and
            _line(panel, "StatLine").contains("MAX HP +12") and
            _line(panel, "StatLine").contains("PROT +15") and
            _line(panel, "EffectsLine").contains("Thorns 4") and
            _line(panel, "AbilityLine").contains("BUFF") and
            _line(panel, "NumbersLine").contains("DAMAGE: 0-0"),
            "non-head torso displays effective tier-III HP/PROT and buff, not an invented attack")
        _check(panel.select_part("warden_arm_brace") and
            _line(panel, "AbilityLine").contains("GUARD") and
            _line(panel, "EffectsLine").contains("Guard 2") and
            _line(panel, "NumbersLine").contains("DAMAGE: 0-0") and
            _line(panel, "RanksLine").contains("TARGET: ALLY RANKS 1, 4") and
            _line(panel, "MovementLine").contains("POSE: guard"),
            "different slot guard shows true ally targets, zero damage and pose")
        _check(panel.select_part("warden_legs_stride") and
            _line(panel, "AbilityLine").contains("MOVE") and
            _line(panel, "MovementLine").contains("SELF MOVE: -1") and
            _line(panel, "MovementLine").contains("POSE: skill"),
            "leg movement is presented without executing it")
        var mixed := [warden_parts[0].duplicate(true), foreign.duplicate(true), warden_parts[4].duplicate(true)]
        _check(panel.present_parts(mixed) and panel.part_ids_in_slot("torso").size() == 2 and
            panel.part_ids_in_slot("head").size() == 1,
            "mixed satchel retains all owner types and does not demand a full hero kit")
        _check(panel.select_part("any_torso_felt_coat") and
            _line(panel, "AbilityLine").contains("HEAL") and
            _line(panel, "NumbersLine").contains("DAMAGE: 0-0") and
            _line(panel, "EffectsLine").contains("Heal 5") and
            _line(panel, "StatLine").contains("MAX HP +8") and
            _line(panel, "StatLine").contains("PROT +5"),
            "foreign heal readout preserves zero damage, heal effect and torso stats")
        _check(not panel.present_parts([{"id": "invalid"}]) and
            panel.selected_part_id.is_empty() and head_rows.get_child_count() == 0 and
            _line(panel, "NumbersLine").is_empty(),
            "bad entry fails closed and wipes previous part details")
        _check(not panel.present_parts({ "parts": warden_parts }) and
            panel.selected_part_id.is_empty() and not panel.select_tier(1),
            "non-array catalog fails closed")
        _check(not panel.present_parts([]) and
            panel.selected_part_id.is_empty() and
            _line(panel, "PartName") == "No part selected",
            "empty array restores clear empty state")
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
    ]
    for id in witness_ids:
        _check(source.has(id), "combined five real catalogs contain " + id)
    var panel := packed.instantiate() as StitchedPartInspector
    root.add_child(panel)
    await process_frame
    var owner_control := panel.get_node("CatalogPanel/OwnerFilter") as OptionButton
    _check(owner_control.get_item_count() == 6
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
    for owner in ["warden", "seamstress", "tinker", "yarn_ranger", "any"]:
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
            ["any", "scissor_crab_claw_arm"]]:
        var owner: String = group[0]
        var id: String = group[1]
        var part: Dictionary = source[id]
        _check(panel.select_owner(owner) and panel.select_part(id),
            "owner and valid part are selectable: " + id)
        _check(_line(panel, "PartMeta").contains("OWNER: " + owner)
            and _line(panel, "PartName") == str(part["name"]),
            "group selection does not invent the ID or displayed name: " + id)
        for tier in [1, 2, 3]:
            var ability := StitchedParts.ability_at_tier(part, tier)
            var stats := StitchedParts.stat_at_tier(part, tier)
            _check(panel.select_tier(tier)
                and _line(panel, "NumbersLine").contains("ACC: %d%%" % int(ability["acc"]))
                and _line(panel, "NumbersLine").contains("DAMAGE: %d-%d" % [
                    int(ability["dmg"][0]), int(ability["dmg"][1])])
                and _line(panel, "AbilityLine").contains(str(ability["name"]))
                and _line(panel, "MovementLine").contains("POSE: " + str(ability["move"])),
                "real tier %d accuracy/damage/ability/pose for %s" % [tier, id])
            for key in stats:
                _check(_line(panel, "StatLine").contains("%s +%d" % [
                    str(key).to_upper().replace("_", " "), int(stats[key])]),
                    "real tier %d %s stat for %s" % [tier, str(key), id])
            for key in ability["effects"]:
                _check(_line(panel, "EffectsLine").contains("%s %d" % [
                    str(key).capitalize(), int(ability["effects"][key])]),
                    "real tier %d %s effect for %s" % [tier, str(key), id])
        _check(not panel.select_tier(0) and not panel.select_tier(4)
            and not panel.select_owner("not_a_hero") and not panel.select_part("fictional")
            and panel.selected_part_id == id and panel.selected_tier == 3,
            "invalid tier, owner and part do not mutate selection")
        _check(panel.select_slot("legs")
            and panel.active_slot == "legs" and not panel.selected_part_id.is_empty()
            and panel.selected_tier == 1,
            "owner " + owner + " can change slot and resets on a different part")
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
        and panel.part_ids_in_slot("arms").has("scissor_crab_claw_arm"),
        "group without parts empties details, not the full source index")
    _check(not panel.select_tier(2) and not panel.select_part("scissor_crab_claw_arm")
        and _line(panel, "NumbersLine").is_empty()
        and not panel.select_owner("invalid"),
        "empty visible owner refuses stale tier, hidden part and invalid owner")
    _check(not panel.present_parts([{"id": "bad"}])
        and panel.selected_part_id.is_empty() and panel.selected_owner == "all"
        and owner_control.disabled and not panel.select_owner("warden"),
        "invalid re-presentation clears owner, selection and disables dropdown")
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


func _finish() -> void:
    if failures.is_empty():
        print("PASS stitched_s4_part_inspector_test: %d checks, two mount/free cycles" % checks)
        quit(0)
    else:
        for message in failures:
            push_error("FAIL stitched_s4_part_inspector_test: " + message)
        print("FAIL stitched_s4_part_inspector_test: %d/%d checks failed" % [failures.size(), checks])
        quit(1)
