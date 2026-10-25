class_name LiveCampfirePanel
extends Control
## Display-only Campfire. The route controller alone can consume the visit.
signal decision_requested(intent: Dictionary)

const CREAM := Color("#f2e6c9")
const MUSTARD := Color("#e2b963")
const THREAD := Color("#bfa788")
const TEAL := Color("#182f38")
const PLUM := Color("#37293c")
const OXBLOOD := Color("#713a45")
const INK := Color("#171c27")
const DIM := Color("#c1b6ae")
const PANEL_SIZE := Vector2(880, 600)

class Stitches extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 24 or size.y < 24:
			return
		var seam := Rect2(Vector2(10, 9), size - Vector2(20, 18))
		for y in [seam.position.y, seam.end.y]:
			draw_dashed_line(Vector2(seam.position.x, y), Vector2(seam.end.x, y), THREAD, 1.5, 8.0)
		for x in [seam.position.x, seam.end.x]:
			draw_dashed_line(Vector2(x, seam.position.y), Vector2(x, seam.end.y), THREAD, 1.5, 8.0)

var title_label: Label
var hero_labels: Array[Label] = []
var heal_button: Button
var leave_button: Button

var _visit: RunCampfireVisit
var _snapshot: Dictionary = {}
var _preview: Array = []
var _epoch: int = 0
var _submitted := false
var _connections: Dictionary = {} # Button -> generation-bound pressed Callable


func _ready() -> void:
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	title_label = _label("CAMPFIRE", Vector2(48, 31), Vector2(770, 62), 44, MUSTARD)
	for i in range(3):
		hero_labels.append(_label("", Vector2(70, 161 + i * 97),
			Vector2(740, 70), 26, CREAM))
	heal_button = _button("Heal", Vector2(48, 498), Vector2(373, 72), OXBLOOD)
	leave_button = _button("Leave", Vector2(459, 498), Vector2(373, 72), TEAL)
	_refresh()
	if _source_current():
		heal_button.grab_focus()


func _draw() -> void:
	# Gothic sewn felt and a simple compact flame; never a mouse target.
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), PLUM)
	draw_rect(Rect2(Vector2(21, 21), size - Vector2(42, 42)), THREAD, false, 2.0)
	draw_dashed_line(Vector2(32, 111), Vector2(size.x - 32, 111), MUSTARD, 2.0, 10.0)
	draw_dashed_line(Vector2(32, 471), Vector2(size.x - 32, 471), THREAD, 2.0, 9.0)
	for i in range(3):
		var backing := Rect2(45, 143 + i * 97, size.x - 90, 82)
		draw_rect(backing, TEAL)
		draw_rect(backing, INK, false, 4.0)
		draw_dashed_line(backing.position + Vector2(12, 11),
			Vector2(backing.end.x - 12, backing.position.y + 11), THREAD, 1.2, 8.0)
		draw_dashed_line(Vector2(backing.position.x + 12, backing.end.y - 11),
			backing.end - Vector2(12, 11), THREAD, 1.2, 8.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(765, 82), Vector2(747, 68), Vector2(758, 48),
		Vector2(767, 56), Vector2(772, 37), Vector2(786, 63),
		Vector2(779, 81)]), OXBLOOD)
	draw_colored_polygon(PackedVector2Array([
		Vector2(766, 78), Vector2(758, 66), Vector2(771, 54),
		Vector2(778, 70)]), MUSTARD)


func _label(caption: String, at: Vector2, dimensions: Vector2,
		font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(4)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)
	return style


func _button(caption: String, at: Vector2, dimensions: Vector2, fill: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = at
	button.size = dimensions
	button.custom_minimum_size = dimensions
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 31)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_stylebox_override("normal", _button_style(fill, INK))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.17), MUSTARD))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.13), MUSTARD))
	button.add_theme_stylebox_override("disabled", _button_style(PLUM, INK))
	var focus := _button_style(Color.TRANSPARENT, MUSTARD)
	focus.draw_center = false
	focus.set_border_width_all(4)
	button.add_theme_stylebox_override("focus", focus)
	add_child(button)
	button.add_child(Stitches.new())
	return button


## Binding before mount is allowed; only the actual service creates the snapshot.
func bind(visit: RunCampfireVisit) -> void:
	_epoch += 1
	_retire_callbacks()
	_visit = null
	_snapshot = {}
	_preview = []
	_submitted = false
	if visit != null:
		var state: Dictionary = visit.read_state()
		if state.get("ok") == true and state.get("status") == RunCampfireVisit.OPEN \
				and RunCampfireVisit._valid_node_id(state.get("node_id")) \
				and typeof(state.get("heroes")) == TYPE_ARRAY \
				and RunRestRecovery._is_valid_roster(state["heroes"]):
			var recovery := RunRestRecovery.new(state["heroes"])
			var result: Dictionary = recovery.choose_heal()
			if result.get("ok") == true and typeof(result.get("heroes")) == TYPE_ARRAY:
				_visit = visit
				_snapshot = state.duplicate(true)
				_preview = result["heroes"].duplicate(true)
	if is_node_ready():
		show()
		_refresh()
		if _source_current():
			heal_button.grab_focus()


func close() -> void:
	bind(null)
	hide()


func _retire_callbacks() -> void:
	for button in _connections:
		var callback: Callable = _connections[button]
		if is_instance_valid(button) and button.pressed.is_connected(callback):
			button.pressed.disconnect(callback)
	_connections.clear()


func _source_current() -> bool:
	if _visit == null or _submitted or _snapshot.is_empty():
		return false
	var state := _visit.read_state()
	return state.get("ok") == true and state.get("status") == RunCampfireVisit.OPEN \
		and state.get("node_id") == _snapshot.get("node_id") \
		and state.get("heroes") == _snapshot.get("heroes") \
		and state == _snapshot and _preview.size() == 3 \
		and RunRestRecovery.new(state["heroes"]).choose_heal().get("heroes") == _preview


func _hero_text(i: int) -> String:
	var hero: Dictionary = _snapshot["heroes"][i]
	var forecast: Dictionary = _preview[i]
	var display_name: String = str(hero.get("name", "")).strip_edges()
	if display_name.is_empty():
		display_name = str(hero["id"]).replace("_", " ").capitalize()
	var before: int = int(hero["hp"])
	var after: int = int(forecast["hp"])
	var maximum: int = int(hero["max_hp"])
	var note := "  ·  TORN → REVIVED" if before == 0 else ""
	return "%s    %d → %d / %d HP%s" % [display_name, before, after, maximum, note]


func _display_current() -> bool:
	if title_label == null or title_label.text != "CAMPFIRE" \
			or heal_button.text != "Heal" or leave_button.text != "Leave":
		return false
	if hero_labels.size() != 3:
		return false
	for i in range(3):
		if hero_labels[i].text != _hero_text(i):
			return false
	return true


func _refresh() -> void:
	if title_label == null:
		return
	var valid := _source_current()
	for i in range(hero_labels.size()):
		hero_labels[i].text = _hero_text(i) if valid else ""
	heal_button.disabled = not valid
	leave_button.disabled = not valid
	_retire_callbacks()
	if valid:
		var generation := _epoch
		var source := _visit
		var heal_callback := _request.bind("heal", generation, source)
		var leave_callback := _request.bind("leave", generation, source)
		heal_button.pressed.connect(heal_callback)
		leave_button.pressed.connect(leave_callback)
		_connections[heal_button] = heal_callback
		_connections[leave_button] = leave_callback


func _request(action: String, generation: int, source: RunCampfireVisit) -> void:
	if generation != _epoch or source == null or not is_same(_visit, source) \
			or not is_inside_tree() or not is_visible_in_tree() \
			or not _source_current() or not _display_current() \
			or (action != "heal" and action != "leave"):
		return
	var button := heal_button if action == "heal" else leave_button
	if button.disabled or not button.is_visible_in_tree():
		return
	_submitted = true
	heal_button.disabled = true
	leave_button.disabled = true
	decision_requested.emit({
		"action": action,
		"source_visit": source,
		"node_id": _snapshot["node_id"],
		"expected_heroes": _snapshot["heroes"].duplicate(true),
	})
