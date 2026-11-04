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
    _finish()


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
