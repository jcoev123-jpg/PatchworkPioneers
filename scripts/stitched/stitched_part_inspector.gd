class_name StitchedPartInspector
extends Control
## Detached, read-only S4 part browser. No run, equipment or battle references.

signal close_requested

const SLOTS := ["head", "arms", "torso", "legs"]
const OWNERS := ["all", "warden", "seamstress", "tinker", "yarn_ranger",
    "lantern_monk", "button_golem", "rag_duelist", "any", "scarecrow"]
const OWNER_LABELS := ["All", "Warden", "Seamstress", "Tinker", "Yarn Ranger",
    "Lantern Monk", "Button Golem", "Rag Duelist", "Spoils", "Scarecrow"]
const TIER_LABELS := ["I", "II", "III"]

@onready var _rows: VBoxContainer = $CatalogPanel/PartScroll/PartRows
@onready var _owner_filter: OptionButton = $CatalogPanel/OwnerFilter
@onready var _status: Label = $CatalogPanel/StatusLabel
@onready var _name: Label = $DetailsPanel/PartName
@onready var _meta: Label = $DetailsPanel/PartMeta
@onready var _patch_preview: TextureRect = $DetailsPanel/PatchPreview
@onready var _tier_border_preview: TextureRect = $DetailsPanel/TierBorderPreview
@onready var _text: Label = $DetailsPanel/PartText
@onready var _stat: Label = $DetailsPanel/StatLine
@onready var _ability: Label = $DetailsPanel/AbilityLine
@onready var _ranks: Label = $DetailsPanel/RanksLine
@onready var _numbers: Label = $DetailsPanel/NumbersLine
@onready var _effects: Label = $DetailsPanel/EffectsLine
@onready var _move: Label = $DetailsPanel/MovementLine

var selected_part_id: String = ""
var selected_tier: int = 1
var active_slot: String = "head"
var selected_owner: String = "all"
var _by_id: Dictionary = {}
var _by_slot: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _tier_buttons: Array[Button] = []
var _part_buttons: Dictionary = {}
var _filter_keys: Array[String] = []
var _filter_labels: Array[String] = []


func _ready() -> void:
    _slot_buttons = {
        "head": $CatalogPanel/SlotHead,
        "arms": $CatalogPanel/SlotArms,
        "torso": $CatalogPanel/SlotTorso,
        "legs": $CatalogPanel/SlotLegs,
    }
    _tier_buttons = [$DetailsPanel/TierI, $DetailsPanel/TierII, $DetailsPanel/TierIII]
    for index in range(OWNERS.size()):
        _filter_keys.append(OWNERS[index])
        _filter_labels.append(OWNER_LABELS[index])
    for thread in StitchedSewnPatches.THREADS:
        _filter_keys.append("thread:" + thread)
        _filter_labels.append(thread.capitalize() + " thread")
    for index in range(_filter_keys.size()):
        _owner_filter.add_item(_filter_labels[index], index)
    _owner_filter.focus_mode = Control.FOCUS_ALL
    _owner_filter.item_selected.connect(_on_owner_chosen)
    for slot in SLOTS:
        var key: String = slot
        var button: Button = _slot_buttons[key]
        button.focus_mode = Control.FOCUS_ALL
        button.pressed.connect(_on_slot_pressed.bind(key))
    for index in range(_tier_buttons.size()):
        var tier := index + 1
        _tier_buttons[index].focus_mode = Control.FOCUS_ALL
        _tier_buttons[index].pressed.connect(_on_tier_pressed.bind(tier))
    $CloseButton.pressed.connect(_on_close_pressed)
    _clear("No parts supplied.")


## Replaces the entire satchel, never the caller's data. Partial/bad catalogs are rejected.
## Mount this scene before calling the presentation API.
func present_parts(entries: Variant) -> bool:
    if not is_node_ready():
        return false
    var catalog := StitchedParts.build_catalog(entries)
    if not bool(catalog.get("ok", false)):
        _clear("No valid parts to inspect.")
        return false
    _clear("")
    _by_id = catalog["by_id"]
    for slot in SLOTS:
        _by_slot[slot] = []
    for part in catalog["parts"]:
        _by_slot[str(part["slot"])].append(part)
    for slot in SLOTS:
        _by_slot[slot].sort_custom(_part_before)
    _owner_filter.disabled = false
    for slot in SLOTS:
        if not _by_slot[slot].is_empty():
            return select_part(str(_by_slot[slot][0]["id"]))
    _clear("No parts supplied.")
    return false


## Change only which validated rows are visible. Reuse the selected part when
## possible; otherwise select the first sorted row in the active slot.
func select_owner(owner: String) -> bool:
    if not owner in _filter_keys or _by_id.is_empty():
        return false
    selected_owner = owner
    _owner_filter.select(_filter_keys.find(owner))
    return select_slot(active_slot)


## Select a tab with no gameplay effect. A new part always starts at tier I.
func select_slot(slot: String) -> bool:
    if not slot in SLOTS:
        return false
    active_slot = slot
    var visible := _visible_parts(slot)
    if visible.is_empty():
        selected_part_id = ""
        selected_tier = 1
        _refresh_rows()
        _refresh_details()
        return true
    if _by_id.has(selected_part_id) and str(_by_id[selected_part_id]["slot"]) == slot and (
            _matches_filter(_by_id[selected_part_id])):
        _refresh_rows()
        _refresh_details()
        return true
    return select_part(str(visible[0]["id"]))


## Selects an existing validated entry only; unknown IDs do not alter the display.
func select_part(part_id: String) -> bool:
    if not _by_id.has(part_id):
        return false
    var part: Dictionary = _by_id[part_id]
    if not _matches_filter(part):
        return false
    if selected_part_id != part_id:
        selected_tier = 1
    selected_part_id = part_id
    active_slot = str(part["slot"])
    _refresh_rows()
    _refresh_details()
    return true


## Changing finish preserves the chosen cloth patch and only changes its stitched border.
func select_tier(tier: int) -> bool:
    if not _by_id.has(selected_part_id) or tier < 1 or tier > 3:
        return false
    selected_tier = tier
    _refresh_details()
    return true


func part_ids_in_slot(slot: String) -> Array[String]:
    var ids: Array[String] = []
    if not slot in SLOTS or not _by_slot.has(slot):
        return ids
    for part in _by_slot[slot]:
        ids.append(str(part["id"]))
    return ids


## Full-catalog part_ids_in_slot remains independent of the visible owner rows.
func visible_part_ids_in_slot(slot: String) -> Array[String]:
    var ids: Array[String] = []
    for part in _visible_parts(slot):
        ids.append(str(part["id"]))
    return ids


func _visible_parts(slot: String) -> Array:
    var parts: Array = []
    if not slot in SLOTS or not _by_slot.has(slot):
        return parts
    for part in _by_slot[slot]:
        if _matches_filter(part):
            parts.append(part)
    return parts


func _matches_filter(part: Dictionary) -> bool:
    if selected_owner == "all":
        return true
    if selected_owner.begins_with("thread:"):
        return StitchedSewnPatches.thread_of(str(part["id"])) == selected_owner.trim_prefix("thread:")
    return str(part["owner"]) == selected_owner


func _part_before(a: Dictionary, b: Dictionary) -> bool:
    var left := str(a["name"]).to_lower()
    var right := str(b["name"]).to_lower()
    if left == right:
        return str(a["id"]) < str(b["id"])
    return left < right


func _clear(message: String) -> void:
    _by_id.clear()
    _by_slot.clear()
    _part_buttons.clear()
    selected_part_id = ""
    selected_tier = 1
    active_slot = "head"
    selected_owner = "all"
    _owner_filter.select(0)
    _owner_filter.disabled = true
    _status.text = message
    _refresh_rows()
    _refresh_details()


func _refresh_rows() -> void:
    for child in _rows.get_children():
        _rows.remove_child(child)
        child.queue_free()
    _part_buttons.clear()
    for slot in SLOTS:
        var slot_button: Button = _slot_buttons[slot]
        slot_button.button_pressed = slot == active_slot
        slot_button.disabled = _visible_parts(slot).is_empty()
    if not _by_slot.has(active_slot):
        return
    var visible := _visible_parts(active_slot)
    for part in visible:
        var id := str(part["id"])
        var button := Button.new()
        button.name = "Part_" + id
        button.text = "%s   /   %s" % [str(part["name"]), str(part["owner"])]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size = Vector2(0, 56)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.focus_mode = Control.FOCUS_ALL
        button.toggle_mode = true
        button.button_pressed = id == selected_part_id
        button.pressed.connect(_on_part_pressed.bind(id))
        _rows.add_child(button)
        _part_buttons[id] = button
    _status.text = "%d parts / %s / %s" % [visible.size(), active_slot.to_upper(),
        _filter_labels[_filter_keys.find(selected_owner)]]


func _on_owner_chosen(index: int) -> void:
    if index >= 0 and index < _filter_keys.size():
        select_owner(_filter_keys[index])


func _on_slot_pressed(slot: String) -> void:
    select_slot(slot)


func _on_tier_pressed(tier: int) -> void:
    select_tier(tier)


func _on_part_pressed(id: String) -> void:
    select_part(id)


func _refresh_details() -> void:
    for index in range(_tier_buttons.size()):
        var button: Button = _tier_buttons[index]
        button.disabled = not _by_id.has(selected_part_id)
        button.button_pressed = index + 1 == selected_tier and not button.disabled
    if not _by_id.has(selected_part_id):
        _patch_preview.texture = null
        _tier_border_preview.texture = null
        _patch_preview.hide()
        _tier_border_preview.hide()
        _name.text = "No part selected"
        _meta.text = "Choose a supplied part to inspect its stitches."
        _text.text = ""
        _stat.text = ""
        _ability.text = ""
        _ranks.text = ""
        _numbers.text = ""
        _effects.text = ""
        _move.text = ""
        return
    var part: Dictionary = _by_id[selected_part_id]
    var slot := str(part["slot"]).to_upper()
    var patch_path := StitchedSewnPatches.icon_path(selected_part_id, str(part["slot"]))
    var border_path := StitchedSewnPatches.border_path(selected_tier)
    _patch_preview.texture = load(patch_path) as Texture2D if not patch_path.is_empty() else null
    _tier_border_preview.texture = load(border_path) as Texture2D if not border_path.is_empty() else null
    _patch_preview.visible = _patch_preview.texture != null
    _tier_border_preview.visible = _tier_border_preview.texture != null and _patch_preview.visible
    _name.text = str(part["name"])
    _meta.text = "SLOT: %s    OWNER: %s    ID: %s" % [
        slot, str(part["owner"]), selected_part_id,
    ]
    var maker_thread := StitchedSewnPatches.thread_of(selected_part_id)
    if not maker_thread.is_empty():
        _meta.text += "\nTHREAD: " + maker_thread.to_upper()
    # Legacy part ability, tier prose, ranks and numeric modifiers are not
    # promises of moves granted by wearing a cloth patch (S14 fixed doll kits).
    var favoured := StitchedSewnPatches.favoured_slot(str(part["owner"]))
    if StitchedSewnPatches.is_foe_patch(selected_part_id):
        # The maker is not the wearer. Retired fray must not appear in the live atlas.
        if StitchedRules.fray_enabled:
            _text.text = "Foe cloth for %s; may fray a doll outside its favoured seam. Moves stay with the doll." % slot
        else:
            _text.text = "Foe cloth for %s; a stranger's stitching. Moves stay with the doll." % slot
    elif not favoured.is_empty():
        var maker := str(part["owner"]).replace("_", " ").capitalize()
        _text.text = "Cloth for %s; %s favours %s. Moves stay with the doll." % [
            slot, maker, favoured.to_upper(),
        ]
    else:
        _text.text = "Cloth for %s. Moves stay with the doll." % slot
    _stat.text = ""
    _ability.text = ""
    _ranks.text = ""
    _numbers.text = ""
    _effects.text = ""
    _move.text = ""


func _on_close_pressed() -> void:
    close_requested.emit()
