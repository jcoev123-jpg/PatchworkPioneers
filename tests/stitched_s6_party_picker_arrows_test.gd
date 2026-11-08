extends SceneTree
## Self-contained physical-input contract for the original Stitched four-of-eight picker.

const DEFAULT_PICKS := ["warden", "seamstress", "tinker", "lantern_monk"]
const REPLACEMENT_PICKS := ["seamstress", "tinker", "lantern_monk", "rag_duelist"]
const REPLACEMENT_RANKS := ["rag_duelist", "seamstress", "tinker", "lantern_monk"]

var failures: Array[String] = []
var checks := 0
var snapshots: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _check(ok: bool, detail: String) -> void:
    checks += 1
    if not ok:
        failures.append(detail)


func _record_snapshot(picks: Array) -> void:
    snapshots.append(picks.duplicate())


func _key(code: Key, shifted: bool = false) -> void:
    for down in [true, false]:
        var event := InputEventKey.new()
        event.keycode = code
        event.physical_keycode = code
        event.shift_pressed = shifted
        event.pressed = down
        Input.parse_input_event(event)
        await process_frame


func _mouse(button: Button) -> void:
    await process_frame
    var point := button.get_global_rect().get_center()
    var hover := InputEventMouseMotion.new()
    hover.position = point
    root.push_input(hover, true)
    await process_frame
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = point
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        root.push_input(event, true)
        await process_frame


func _visible_ids(picker: StitchedRunPartyPicker) -> Array:
    var ids: Array = []
    for child in picker.get_children():
        if child is Button:
            ids.append(child.get_meta("hero_id", ""))
    return ids


func _check_layout(picker: StitchedRunPartyPicker, expected: Array, context: String) -> void:
    _check(picker.columns == 2 and picker.get_child_count() == 8
        and picker.tiles.size() == 8 and _visible_ids(picker) == expected,
        context + ": original eight buttons appear in row-major visual order")
    if picker.get_child_count() != 8:
        return
    for index in 8:
        var tile := picker.get_child(index) as Button
        _check(tile != null and picker.tiles.get(expected[index]) == tile,
            context + ": original tile occupies index " + str(index))
        if tile == null:
            return
        var col := index % 2
        var row: int = index / 2
        var across := picker.get_child(index + (1 if col == 0 else -1)) as Button
        var above := picker.get_child(((row + 3) % 4) * 2 + col) as Button
        var below := picker.get_child(((row + 1) % 4) * 2 + col) as Button
        _check(not tile.focus_neighbor_left.is_empty()
            and tile.get_node_or_null(tile.focus_neighbor_left) == across
            and not tile.focus_neighbor_right.is_empty()
            and tile.get_node_or_null(tile.focus_neighbor_right) == across,
            context + ": left/right links match visual row at " + str(index))
        _check(not tile.focus_neighbor_top.is_empty()
            and tile.get_node_or_null(tile.focus_neighbor_top) == above
            and not tile.focus_neighbor_bottom.is_empty()
            and tile.get_node_or_null(tile.focus_neighbor_bottom) == below,
            context + ": up/down wrap links match visual column at " + str(index))
        _check(tile.focus_next.is_empty() and tile.focus_previous.is_empty(),
            context + ": original Tab and Shift-Tab navigation is not overridden")


func _check_originals(picker: StitchedRunPartyPicker, originals: Dictionary,
        skins: Dictionary, context: String) -> void:
    var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
    _check(picker.get_child_count() == 8, context + ": no additional controls")
    for id in StitchedPartyAdmission.HERO_IDS:
        var tile: Button = picker.tiles.get(id)
        if tile == null:
            _check(false, context + ": missing tile " + id)
            continue
        var portrait := tile.get_node_or_null("Portrait") as TextureRect
        var nameplate := tile.get_node_or_null("DollName") as Label
        var rect := tile.get_global_rect()
        _check(tile == originals.get(id) and tile.name == "HeroTile_" + id
            and tile.get_meta("hero_id", "") == id
            and tile.focus_mode == Control.FOCUS_ALL and tile.toggle_mode,
            context + ": exact original focusable Button for " + id)
        _check(portrait != null
            and portrait.get_meta("art_path", "") == "res://assets/paper/heroes/" + id + ".png"
            and nameplate != null and nameplate.text.contains(id.replace("_", " ").capitalize()),
            context + ": original portrait and nameplate for " + id)
        _check(tile.custom_minimum_size == Vector2(516, 94)
            and rect.size.x >= 516 and rect.size.y >= 94 and bounds.encloses(rect),
            context + ": unchanged onscreen 1280x720 hit area for " + id)
        _check(tile.get_theme_stylebox("normal") == skins.get(id),
            context + ": original authored skin instance for " + id)


func _run() -> void:
    root.size = Vector2i(1280, 720)
    var host := Control.new()
    host.name = "PickerTestHost"
    host.size = Vector2(1280, 720)
    root.add_child(host)
    var picker := StitchedRunPartyPicker.new()
    picker.name = "StitchedRunPartyPicker"
    picker.position = Vector2(80, 60)
    picker.size = Vector2(1080, 420)
    host.add_child(picker)
    picker.build(DEFAULT_PICKS)
    picker.draft_changed.connect(_record_snapshot)
    await process_frame
    await process_frame

    var admission := StitchedPartyAdmission.admit(DEFAULT_PICKS)
    _check(admission.get("ok") == true and admission.get("hero_ids") == DEFAULT_PICKS,
        "stable authored default ranks have genuine admission")
    _check(picker.selected_ids() == DEFAULT_PICKS
        and picker.displayed_rank_ids() == DEFAULT_PICKS and picker.tiles_match_draft()
        and snapshots.is_empty(), "default draft is complete without a change signal")

    var originals := picker.tiles.duplicate()
    var skins: Dictionary = {}
    for id in StitchedPartyAdmission.HERO_IDS:
        var tile: Button = originals.get(id)
        if tile == null:
            continue
        var skin := tile.get_theme_stylebox("normal") as StyleBoxTexture
        skins[id] = skin
        _check(skin != null and skin.texture != null
            and skin.texture.resource_path == StitchedRunPartyPicker.TILE_SKIN,
            "authored reward_button image skin for " + id)
    _check_layout(picker, StitchedPartyAdmission.HERO_IDS, "initial grid")
    _check_originals(picker, originals, skins, "initial picker")

    # Real arrow events must change actual keyboard focus, including both wraps.
    picker.tiles["warden"].grab_focus()
    _check(root.gui_get_focus_owner() == picker.tiles["warden"], "Warden starts focused")
    await _key(KEY_RIGHT)
    _check(root.gui_get_focus_owner() == picker.tiles["seamstress"], "RIGHT reaches same-row Seamstress")
    await _key(KEY_LEFT)
    _check(root.gui_get_focus_owner() == picker.tiles["warden"], "LEFT returns to Warden")
    await _key(KEY_DOWN)
    _check(root.gui_get_focus_owner() == picker.tiles["tinker"], "DOWN reaches next-row Tinker")
    picker.tiles["warden"].grab_focus()
    await _key(KEY_UP)
    _check(root.gui_get_focus_owner() == picker.get_child(6), "UP wraps row zero to last row")
    await _key(KEY_DOWN)
    _check(root.gui_get_focus_owner() == picker.tiles["warden"], "DOWN wraps last row to first")
    picker.tiles["seamstress"].grab_focus()
    await _key(KEY_LEFT)
    _check(root.gui_get_focus_owner() == picker.tiles["warden"], "second-column LEFT returns to first column")
    picker.tiles["warden"].grab_focus()
    await _key(KEY_TAB)
    _check(root.gui_get_focus_owner() == picker.tiles["seamstress"], "Tab still uses normal tree traversal")
    await _key(KEY_TAB, true)
    _check(root.gui_get_focus_owner() == picker.tiles["warden"], "Shift-Tab still uses normal tree traversal")

    seed(74921)
    var expected_rng := randi()
    seed(74921)

    # Space causes only one deselection, then a deferred selected-first reflow.
    await _key(KEY_SPACE)
    await process_frame
    var three := ["seamstress", "tinker", "lantern_monk"]
    var incomplete_order := ["seamstress", "tinker", "lantern_monk",
        "warden", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
    _check(picker.selected_ids() == three and picker.displayed_rank_ids().is_empty()
        and picker.tiles_match_draft() and snapshots == [three],
        "one physical Space deselects only Warden and emits one snapshot")
    _check(root.gui_get_focus_owner() == originals["warden"],
        "Warden remains the same focused Button after moving to unselected area")
    _check_layout(picker, incomplete_order, "three selected after deferred reflow")
    _check_originals(picker, originals, skins, "three selected")

    # A real Enter adds the fourth, but its visible admission is canonical,
    # deliberately distinct from the original click order.
    picker.tiles["rag_duelist"].grab_focus()
    await _key(KEY_ENTER)
    await process_frame
    var replacement_order := REPLACEMENT_RANKS + [
        "warden", "scarecrow", "yarn_ranger", "button_golem"]
    _check(picker.selected_ids() == REPLACEMENT_PICKS
        and picker.displayed_rank_ids() == REPLACEMENT_RANKS
        and picker.tiles_match_draft() and snapshots == [three, REPLACEMENT_PICKS],
        "Enter adds Rag once, draft stays in click order and visible ranks are admitted")
    _check(StitchedPartyAdmission.admit(REPLACEMENT_PICKS).get("hero_ids") == REPLACEMENT_RANKS,
        "replacement rank order comes from canonical authored admission")
    _check(root.gui_get_focus_owner() == originals["rag_duelist"],
        "Rag Duelist keeps exact focus identity despite moving to first slot")
    _check_layout(picker, replacement_order, "four selected after deferred reflow")
    _check_originals(picker, originals, skins, "four selected")
    picker.tiles["seamstress"].grab_focus()
    await _key(KEY_LEFT)
    _check(root.gui_get_focus_owner() == originals["rag_duelist"],
        "rebuilt LEFT arrow follows new first-row neighboring tile")

    # Refusing the fifth through keyboard or mouse cannot reorder or emit.
    picker.tiles["scarecrow"].grab_focus()
    await _key(KEY_SPACE)
    await process_frame
    _check(picker.selected_ids() == REPLACEMENT_PICKS
        and not picker.tiles["scarecrow"].button_pressed
        and _visible_ids(picker) == replacement_order
        and snapshots.size() == 2
        and root.gui_get_focus_owner() == originals["scarecrow"],
        "keyboard fifth choice is refused without movement, signal or lost focus")
    await _mouse(picker.tiles["scarecrow"])
    _check(picker.selected_ids() == REPLACEMENT_PICKS
        and _visible_ids(picker) == replacement_order
        and snapshots.size() == 2
        and root.gui_get_focus_owner() == originals["scarecrow"],
        "physical pointer fifth choice is likewise inert")
    _check_layout(picker, replacement_order, "after refused fifth choices")

    # Second Enter on the same original tile deselects exactly once, then
    # Space re-adds exactly once; no leaked duplicate input or draft signals.
    picker.tiles["rag_duelist"].grab_focus()
    await _key(KEY_ENTER)
    await process_frame
    _check(picker.selected_ids() == three
        and snapshots == [three, REPLACEMENT_PICKS, three]
        and picker.displayed_rank_ids().is_empty()
        and root.gui_get_focus_owner() == originals["rag_duelist"],
        "second Enter deselects the focused doll exactly once")
    _check_layout(picker, incomplete_order, "second deselection")
    await _key(KEY_SPACE)
    await process_frame
    _check(picker.selected_ids() == REPLACEMENT_PICKS
        and picker.displayed_rank_ids() == REPLACEMENT_RANKS
        and snapshots == [three, REPLACEMENT_PICKS, three, REPLACEMENT_PICKS]
        and root.gui_get_focus_owner() == originals["rag_duelist"],
        "Space restores fourth doll exactly once and retains logical focus")
    _check_layout(picker, replacement_order, "final recompleted ranks")
    _check_originals(picker, originals, skins, "final unchanged controls")
    _check(randi() == expected_rng, "all picker input/reflows are global RNG-neutral")

    # Unsolicited visual tampering must not be silently repaired by settle()
    # or by an already-consumed deferred call.
    picker.move_child(picker.tiles["rag_duelist"], 7)
    picker.settle_pending_tile_order()
    await process_frame
    _check(picker.displayed_rank_ids() != REPLACEMENT_RANKS
        and (picker.get_child(7) as Button) == originals["rag_duelist"],
        "external move_child tampering remains visible for App rank guard")

    host.free()
    await process_frame
    _finish()


func _finish() -> void:
    for failure in failures:
        printerr(failure)
    print("stitched_s6_party_picker_arrows_test: ",
        "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
    quit(0 if failures.is_empty() else 1)
