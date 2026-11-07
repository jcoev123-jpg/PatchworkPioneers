class_name StitchedPartInspector
extends Control
## Detached, read-only S4 part browser. No run, equipment or battle references.

signal close_requested

const SLOTS := ["head", "arms", "torso", "legs"]
const OWNERS := ["all", "warden", "seamstress", "tinker", "yarn_ranger", "any"]
const OWNER_LABELS := ["All", "Warden", "Seamstress", "Tinker", "Yarn Ranger", "Spoils"]
const STAT_LABELS := {
    "acc": "ACC", "crit": "CRIT", "dmg": "DMG", "max_hp": "MAX HP",
    "prot": "PROT", "speed": "SPEED", "dodge": "DODGE",
}
const TIER_LABELS := ["I", "II", "III"]

@onready var _rows: VBoxContainer = $CatalogPanel/PartScroll/PartRows
@onready var _owner_filter: OptionButton = $CatalogPanel/OwnerFilter
@onready var _status: Label = $CatalogPanel/StatusLabel
@onready var _name: Label = $DetailsPanel/PartName
@onready var _meta: Label = $DetailsPanel/PartMeta
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


func _ready() -> void:
    _slot_buttons = {
        "head": $CatalogPanel/SlotHead,
        "arms": $CatalogPanel/SlotArms,
        "torso": $CatalogPanel/SlotTorso,
        "legs": $CatalogPanel/SlotLegs,
    }
    _tier_buttons = [$DetailsPanel/TierI, $DetailsPanel/TierII, $DetailsPanel/TierIII]
    for index in range(OWNERS.size()):
        _owner_filter.add_item(OWNER_LABELS[index], index)
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
    if not owner in OWNERS or _by_id.is_empty():
        return false
    selected_owner = owner
    _owner_filter.select(OWNERS.find(owner))
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
            selected_owner == "all" or str(_by_id[selected_part_id]["owner"]) == selected_owner):
        _refresh_rows()
        _refresh_details()
        return true
    return select_part(str(visible[0]["id"]))


## Selects an existing validated entry only; unknown IDs do not alter the display.
func select_part(part_id: String) -> bool:
    if not _by_id.has(part_id):
        return false
    var part: Dictionary = _by_id[part_id]
    if selected_owner != "all" and str(part["owner"]) != selected_owner:
        return false
    if selected_part_id != part_id:
        selected_tier = 1
    selected_part_id = part_id
    active_slot = str(part["slot"])
    _refresh_rows()
    _refresh_details()
    return true


## Changing tier preserves the chosen part and only changes the readout.
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
        if selected_owner == "all" or str(part["owner"]) == selected_owner:
            parts.append(part)
    return parts


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
        OWNER_LABELS[OWNERS.find(selected_owner)]]


func _on_owner_chosen(index: int) -> void:
    if index >= 0 and index < OWNERS.size():
        select_owner(OWNERS[index])


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
    var ability := StitchedParts.ability_at_tier(part, selected_tier)
    var stat := StitchedParts.stat_at_tier(part, selected_tier)
    var tier_data: Dictionary = part["tiers"].get(str(selected_tier), {})
    _name.text = str(part["name"])
    _meta.text = "SLOT: %s    OWNER: %s    TIER %s    ID: %s" % [
        str(part["slot"]).to_upper(), str(part["owner"]), TIER_LABELS[selected_tier - 1], selected_part_id,
    ]
    _text.text = str(tier_data.get("text", part["text"]))
    var stats: Array[String] = []
    for key in StitchedParts.SLOT_STATS[str(part["slot"])]:
        if stat.has(key):
            stats.append("%s +%d" % [STAT_LABELS[key], int(stat[key])])
    _stat.text = "PART MODIFIER: " + (", ".join(stats) if not stats.is_empty() else "None")
    _ability.text = "ABILITY: %s  /  %s  (%s)" % [
        str(ability["name"]), str(ability["kind"]).to_upper(), str(ability["id"]),
    ]
    _ranks.text = "LAUNCH: %s    TARGET: %s RANKS %s    MULTI: %s" % [
        _rank_text(ability["launch"]), str(ability["target_side"]).to_upper(),
        _rank_text(ability["target"]), "Yes" if ability["multi"] else "No",
    ]
    var damage: Array = ability["dmg"]
    _numbers.text = "ACC: %d%%    DAMAGE: %d-%d    CRIT: %d%%    MARK BONUS: %d" % [
        int(ability["acc"]), int(damage[0]), int(damage[1]), int(ability["crit"]),
        int(ability["mark_damage"]),
    ]
    _effects.text = "EFFECTS: " + _effect_text(ability["effects"])
    _move.text = "SELF MOVE: %+d    POSE: %s" % [int(ability["self_move"]), str(ability["move"])]


func _rank_text(ranks: Array) -> String:
    var items: Array[String] = []
    for rank in ranks:
        items.append(str(rank))
    return ", ".join(items)


func _effect_text(effects: Dictionary) -> String:
    if effects.is_empty():
        return "None"
    var keys := effects.keys()
    keys.sort()
    var labels: Array[String] = []
    for key in keys:
        labels.append("%s %d" % [str(key).capitalize(), int(effects[key])])
    return ", ".join(labels)


func _on_close_pressed() -> void:
    close_requested.emit()
