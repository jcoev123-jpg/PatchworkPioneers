class_name StitchedBedroomDollInspector
extends Control
## Passive, image-backed memory of the dolls' last outing. Never a party/HP
## authority; it has no buttons and takes neither mouse nor keyboard input.

const FELT := preload("res://assets/paper/ui/panel_felt.png")
const BONE := Color("#f4e5cd")
const AMBER := Color("#e0b977")
const HERO_NAMES := {
	"warden": "Warden", "seamstress": "Seamstress", "tinker": "Tinker",
	"lantern_monk": "Lantern Monk", "rag_duelist": "Rag Duelist",
	"scarecrow": "Scarecrow", "yarn_ranger": "Yarn Ranger",
	"button_golem": "Button Golem",
}
## Below the drawings and to the right of the door; never over another hotspot.
const PANEL_RECT := Rect2(755, 373, 342, 335)

var heading: Label
var subtitle: Label
var entries: VBoxContainer
var entry_order: Array[String] = []
var name_labels: Dictionary = {}
var status_labels: Dictionary = {}
var empty_label: Label
var _record: Dictionary = StitchedBedroomRecord.fresh()
var _view := ""


func _ready() -> void:
	name = "LastOutingInspector"
	position = PANEL_RECT.position
	size = PANEL_RECT.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

	var felt := NinePatchRect.new()
	felt.name = "FeltPanel"
	felt.texture = FELT
	felt.patch_margin_left = 36
	felt.patch_margin_top = 36
	felt.patch_margin_right = 36
	felt.patch_margin_bottom = 36
	felt.modulate = Color(0.29, 0.26, 0.27, 0.98)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.focus_mode = Control.FOCUS_NONE
	add_child(felt)
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margins := MarginContainer.new()
	margins.name = "Content"
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.focus_mode = Control.FOCUS_NONE
	margins.add_theme_constant_override("margin_left", 17)
	margins.add_theme_constant_override("margin_right", 17)
	margins.add_theme_constant_override("margin_top", 12)
	margins.add_theme_constant_override("margin_bottom", 12)
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stack := VBoxContainer.new()
	stack.name = "Ledger"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.focus_mode = Control.FOCUS_NONE
	stack.add_theme_constant_override("separation", 3)
	margins.add_child(stack)

	heading = _label("Heading", 23, AMBER)
	heading.theme_type_variation = &"PatchHeading"
	heading.text = "LAST OUTING"
	stack.add_child(heading)

	subtitle = _label("Subtitle", 14, AMBER)
	stack.add_child(subtitle)

	entries = VBoxContainer.new()
	entries.name = "Entries"
	entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entries.focus_mode = Control.FOCUS_NONE
	entries.add_theme_constant_override("separation", 1)
	stack.add_child(entries)

	empty_label = _label("EmptyMessage", 17, BONE)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(empty_label)
	hide()


func _label(label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## A fresh record is first-night memory. An absent ID means stayed home, not
## a doll with zero Fray. LOST and HANGING outrank the Fray pose mnemonic.
static func has_ended_outing(record: Dictionary) -> bool:
	return int(record.get("nights", 0)) > 0 and str(record.get("outcome", "")) in ["victory", "defeat"]


static func status_for(record: Dictionary, id: String) -> String:
	if not has_ended_outing(record):
		return "NOT YET GONE OUT"
	var history: Dictionary = record.get("dolls", {})
	if not history.has(id):
		return "STAYED HOME"
	var last: Dictionary = history[id]
	if bool(last.get("lost", false)):
		return "LOST"
	if bool(last.get("hanging", false)):
		return "HANGING BY A THREAD"
	var fray := int(last.get("fray", 0))
	var status := "FRAY %d/200" % fray
	if fray >= 150:
		return status + "\nFACING WALL"
	if fray >= 100:
		return status + "\nSLUMPED"
	return status


func present(record: Dictionary) -> void:
	_record = record.duplicate(true) if StitchedBedroomRecord.valid(record) else StitchedBedroomRecord.fresh()
	_render()


## The shelf always includes all eight dolls. The tin includes only actual
## losses, and explains an empty/no-history record rather than inventing one.
func show_view(view: String) -> void:
	if not view in ["shelf", "tin"]:
		dismiss()
		return
	_view = view
	_render()
	show()


func dismiss() -> void:
	_view = ""
	hide()


func _render() -> void:
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	entry_order.clear()
	name_labels.clear()
	status_labels.clear()
	empty_label.text = ""
	empty_label.hide()
	if _view == "tin":
		subtitle.text = "SEWING TIN  •  Last night's losses"
	else:
		subtitle.text = "TOY SHELF  •  Memory, not today's health"
	for id in StitchedPartyAdmission.HERO_IDS:
		if _view == "tin" and (not has_ended_outing(_record)
				or not bool(_record.get("dolls", {}).get(id, {}).get("lost", false))):
			continue
		var row := HBoxContainer.new()
		row.name = "Entry_" + id
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size.y = 29
		row.add_theme_constant_override("separation", 4)
		entries.add_child(row)
		var doll_name := _label("Name_" + id, 15, AMBER)
		doll_name.text = HERO_NAMES.get(id, id.capitalize())
		doll_name.custom_minimum_size.x = 118
		row.add_child(doll_name)
		var condition := _label("Status_" + id, 15, BONE)
		condition.text = status_for(_record, id)
		condition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		condition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(condition)
		entry_order.append(id)
		name_labels[id] = doll_name
		status_labels[id] = condition
	if _view == "tin" and entry_order.is_empty():
		empty_label.text = ("No outing has ended yet" if not has_ended_outing(_record)
			else "No dolls lost on the last outing")
		empty_label.show()
