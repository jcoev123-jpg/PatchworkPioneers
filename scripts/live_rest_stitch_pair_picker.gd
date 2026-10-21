class_name LiveRestStitchPairPicker
extends Control
## Detached Rest choice surface. Emits intent only; never pays scraps.
signal stitch_requested(first_index: int, second_index: int, source_snapshot: Dictionary)

const OWNER_COLORS := {
	"warden": Color("#4a5d73"),
	"seamstress": Color("#6e4f6b"),
	"tinker": Color("#c49a3a"),
}
const CREAM := Color("#f4e9d1")
const INK := Color("#28313c")

var first_selector: OptionButton
var second_selector: OptionButton
var confirm_button: Button
var summary_label: Label
var _left_edge: ColorRect
var _right_edge: ColorRect
var _model := RunRestStitchPairOptions.new()
var _epoch := 0
var _first_callback: Callable
var _second_callback: Callable
var _confirm_callback: Callable


func _ready() -> void:
	# Binding before mounting is supported too: retain the detached receipt
	# while constructing controls, then connect this UI session normally.
	var early_service: RunRestStitchCards = _model._service
	var early_source: Dictionary = _model._source.duplicate(true)
	custom_minimum_size = Vector2(600, 355)
	if size.x < 600 or size.y < 355:
		size = Vector2(600, 355)
	var paper := PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)

	_left_edge = ColorRect.new()
	_left_edge.color = OWNER_COLORS["warden"]
	_left_edge.position = Vector2(7, 7)
	_left_edge.size = Vector2(8, 340)
	_left_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_edge)
	_right_edge = ColorRect.new()
	_right_edge.color = OWNER_COLORS["tinker"]
	_right_edge.position = Vector2(585, 7)
	_right_edge.size = Vector2(8, 340)
	_right_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right_edge)
	# Tiny cream thread dashes on both owner-coloured felt seams.
	for y in range(15, 340, 17):
		for x in [9, 587]:
			var thread := ColorRect.new()
			thread.color = Color("#f9edd2")
			thread.position = Vector2(x, y)
			thread.size = Vector2(4, 3)
			thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(thread)

	var title := Label.new()
	title.text = "REST • STITCH TWO ORIGINAL CARDS"
	title.position = Vector2(27, 15)
	title.size = Vector2(545, 30)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	first_selector = _option(Vector2(30, 60), "Choose first original card")
	second_selector = _option(Vector2(30, 117), "Choose other-hero card")

	var preview_panel := PanelContainer.new()
	preview_panel.position = Vector2(30, 175)
	preview_panel.size = Vector2(540, 113)
	var inset := StyleBoxFlat.new()
	inset.bg_color = Color("#fff8e9")
	inset.border_color = Color("#968c7e")
	inset.set_border_width_all(2)
	inset.set_corner_radius_all(3)
	preview_panel.add_theme_stylebox_override("panel", inset)
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_panel)
	summary_label = Label.new()
	summary_label.position = Vector2(14, 10)
	summary_label.size = Vector2(510, 94)
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.add_theme_color_override("font_color", INK)
	summary_label.add_theme_font_size_override("font_size", 17)
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(summary_label)

	confirm_button = Button.new()
	confirm_button.text = "Confirm Stitch • 3 scraps"
	confirm_button.position = Vector2(30, 302)
	confirm_button.size = Vector2(540, 42)
	confirm_button.focus_mode = Control.FOCUS_ALL
	add_child(confirm_button)
	if early_service != null:
		bind(early_service, early_source)
	else:
		clear()


func _option(at: Vector2, placeholder: String) -> OptionButton:
	var result := OptionButton.new()
	result.position = at
	result.size = Vector2(540, 45)
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_size_override("font_size", 17)
	result.add_theme_color_override("font_color", INK)
	result.add_item(placeholder)
	result.set_item_disabled(0, true)
	result.select(-1)
	add_child(result)
	return result


func bind(service: RunRestStitchCards, source_snapshot: Variant) -> void:
	clear()
	_model.bind(service, source_snapshot)
	_first_callback = _on_first_changed.bind(_epoch)
	_second_callback = _on_second_changed.bind(_epoch)
	_confirm_callback = _on_confirm.bind(_epoch)
	if first_selector != null:
		first_selector.item_selected.connect(_first_callback)
		second_selector.item_selected.connect(_second_callback)
		confirm_button.pressed.connect(_confirm_callback)
	refresh()


func clear() -> void:
	if first_selector != null:
		if _first_callback.is_valid() and first_selector.item_selected.is_connected(_first_callback):
			first_selector.item_selected.disconnect(_first_callback)
		if _second_callback.is_valid() and second_selector.item_selected.is_connected(_second_callback):
			second_selector.item_selected.disconnect(_second_callback)
		if _confirm_callback.is_valid() and confirm_button.pressed.is_connected(_confirm_callback):
			confirm_button.pressed.disconnect(_confirm_callback)
	_epoch += 1
	_first_callback = Callable()
	_second_callback = Callable()
	_confirm_callback = Callable()
	_model.clear()
	if first_selector != null:
		first_selector.clear()
		second_selector.clear()
		first_selector.disabled = true
		second_selector.disabled = true
		confirm_button.disabled = true
		summary_label.text = "Choose two originals from different heroes.\nStitching costs 3 scraps; no scraps are spent in this preview."
		_left_edge.color = OWNER_COLORS["warden"]
		_right_edge.color = OWNER_COLORS["tinker"]


func refresh() -> void:
	if first_selector == null:
		return
	first_selector.clear()
	second_selector.clear()
	first_selector.disabled = true
	second_selector.disabled = true
	confirm_button.disabled = true
	summary_label.text = "No eligible Rest stitching pair (3 scraps required)."
	if not is_inside_tree() or not _model.is_available():
		return
	for entry in _model.first_options():
		first_selector.add_item(_entry_text(entry))
		first_selector.set_item_metadata(first_selector.item_count - 1, entry["index"])
	first_selector.select(-1)
	first_selector.disabled = first_selector.item_count == 0
	summary_label.text = "Pick an original card, then a card owned by another hero.\nStitch price: 3 scraps. No Rest choice has been spent."


func _entry_text(entry: Dictionary) -> String:
	return "#%d  %s • %s (%d energy)" % [entry["index"], entry["name"], entry["owner"].capitalize(), entry["cost"]]


func _on_first_changed(item: int, epoch: int) -> void:
	if epoch != _epoch or not _model.is_available() or not is_inside_tree():
		_disable_choice()
		return
	second_selector.clear()
	second_selector.disabled = true
	confirm_button.disabled = true
	if item < 0 or item >= first_selector.item_count:
		_disable_choice()
		return
	var index: int = first_selector.get_item_metadata(item)
	for entry in _model.second_options(index):
		second_selector.add_item(_entry_text(entry))
		second_selector.set_item_metadata(second_selector.item_count - 1, entry["index"])
	second_selector.select(-1)
	second_selector.disabled = second_selector.item_count == 0
	summary_label.text = "Choose a different hero's original card.\nScrap cost: 3."
	_left_edge.color = _color_for_index(index)
	_right_edge.color = OWNER_COLORS["tinker"]


func _on_second_changed(_item: int, epoch: int) -> void:
	if epoch != _epoch:
		return
	_update_preview()


func _update_preview() -> void:
	confirm_button.disabled = true
	var pair := _current_pair()
	if pair.is_empty():
		summary_label.text = "Select two originals from different heroes."
		return
	summary_label.text = "%s\n%s (%d) + %s (%d) → %d energy\nRest stitch: %d scraps (confirmation requests only)" % [
		pair["display_name"], pair["first_name"], pair["first_cost"], pair["second_name"],
		pair["second_cost"], pair["energy_cost"], pair["scrap_cost"]]
	_left_edge.color = OWNER_COLORS.get(pair["first_owner"], INK)
	_right_edge.color = OWNER_COLORS.get(pair["second_owner"], INK)
	confirm_button.disabled = false


func _current_pair() -> Dictionary:
	if not is_inside_tree() or not is_visible_in_tree() or not _model.is_available():
		return {}
	if first_selector.selected < 0 or second_selector.selected < 0:
		return {}
	if first_selector.selected >= first_selector.item_count or second_selector.selected >= second_selector.item_count:
		return {}
	var first: Variant = first_selector.get_item_metadata(first_selector.selected)
	var second: Variant = second_selector.get_item_metadata(second_selector.selected)
	var pair := _model.preview(first, second)
	if pair.is_empty():
		return {}
	# Audit the entire displayed option mapping. A changed metadata index
	# must not silently confirm a different pair than the player's visible row.
	var firsts := _model.first_options()
	var seconds := _model.second_options(first)
	if first_selector.item_count != firsts.size() or second_selector.item_count != seconds.size():
		return {}
	for i in range(firsts.size()):
		if first_selector.get_item_metadata(i) != firsts[i]["index"] or first_selector.get_item_text(i) != _entry_text(firsts[i]):
			return {}
	for i in range(seconds.size()):
		if second_selector.get_item_metadata(i) != seconds[i]["index"] or second_selector.get_item_text(i) != _entry_text(seconds[i]):
			return {}
	return pair


func _color_for_index(index: int) -> Color:
	for entry in _model.first_options():
		if entry["index"] == index:
			return OWNER_COLORS.get(entry["owner"], INK)
	return INK


func _disable_choice() -> void:
	second_selector.clear()
	second_selector.disabled = true
	confirm_button.disabled = true


func _on_confirm(epoch: int) -> void:
	if epoch != _epoch or confirm_button.disabled:
		return
	var pair := _current_pair()
	if pair.is_empty():
		confirm_button.disabled = true
		return
	stitch_requested.emit(pair["first_index"], pair["second_index"], pair["source_snapshot"].duplicate(true))


func _exit_tree() -> void:
	# A removed or closed panel must never retain an active choice callback.
	clear()
