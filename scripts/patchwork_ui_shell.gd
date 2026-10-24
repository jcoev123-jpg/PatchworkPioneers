extends Control
## Presentation only. Child readiness installs the theme before App builds its UI.

const INK := Color("302b29")
const PAPER := Color("ecdfbd")
const THREAD := Color("c9b996")
const TITLE_BACKDROP := "res://assets/paper/backgrounds/title.png"
## Code-drawn ground for a missing owner picture; never a blank felt screen.
const FALLBACK_STAGE := Color("2b3135")
## Felt the three original title actions are sewn onto, darker than every button state.
const ACTION_BACKING := Color("3a4436")
## The two sewn backings stay inside this share of the picture, so scenery stays visible.
const MENU_COVERAGE_LIMIT := 0.35
var _title: Control
var _label: Label
var _actions: Array[Button] = []
var _backdrop: Texture2D


class ButtonStitches extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var edge := Rect2(Vector2(8, 7), size - Vector2(16, 14))
		for y in [edge.position.y, edge.end.y]:
			draw_dashed_line(Vector2(edge.position.x, y), Vector2(edge.end.x, y), THREAD, 1.0, 5.0)
		for x in [edge.position.x, edge.end.x]:
			draw_dashed_line(Vector2(x, edge.position.y), Vector2(x, edge.end.y), THREAD, 1.0, 5.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = _load_backdrop()
	get_parent().theme = _build_theme()
	get_parent().ready.connect(_bind_title, CONNECT_ONE_SHOT)
	resized.connect(queue_redraw)


## A missing owner image leaves the existing drawn backdrop instead of failing boot.
static func _load_backdrop(path: String = TITLE_BACKDROP) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


## Cover the whole shell while preserving the backdrop's proportions.
func backdrop_rect() -> Rect2:
	if _backdrop == null or _backdrop.get_width() <= 0 or _backdrop.get_height() <= 0:
		return Rect2()
	var texture_size := Vector2(_backdrop.get_width(), _backdrop.get_height())
	var fit := maxf(size.x / texture_size.x, size.y / texture_size.y)
	return Rect2((size - texture_size * fit) / 2.0, texture_size * fit)


## Compact paper backing that follows the live title label, in shell coordinates.
func title_backing_rect() -> Rect2:
	if not is_instance_valid(_label):
		return Rect2()
	return Rect2(_label.global_position - global_position, _label.size).grow_individual(26, 20, 26, 18)


## Compact felt backing that follows the three original actions, in shell coordinates.
func action_backing_rect() -> Rect2:
	var backing := Rect2()
	for index in range(_actions.size()):
		var button := _actions[index]
		if not is_instance_valid(button):
			return Rect2()
		var rect := Rect2(button.global_position - global_position, button.size)
		backing = rect if index == 0 else backing.merge(rect)
	if backing.size.x <= 0 or backing.size.y <= 0:
		return Rect2()
	return backing.grow_individual(26, 18, 26, 16)


func _panel(fill: Color, edge: Color, border: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(3)
	# Keep shared metrics compact: live visit and battle layouts already own spacing.
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _build_theme() -> Theme:
	var shared := Theme.new()
	shared.default_font_size = 18
	shared.set_font_size("font_size", "Label", 18)
	shared.set_color("font_color", "Label", PAPER)
	shared.set_type_variation("TitleLabel", "Label")
	shared.set_font_size("font_size", "TitleLabel", 48)
	shared.set_color("font_color", "TitleLabel", INK)
	shared.set_stylebox("panel", "Panel", _panel(PAPER, Color("a8997b")))
	shared.set_stylebox("panel", "PanelContainer", _panel(Color("514b42"), Color("a8997b")))
	# Cream ink stays readable on all four earthy felt states.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fills := {"normal": Color("555d48"), "hover": Color("6b7757"),
			"pressed": Color("3e493b"), "disabled": Color("45433f")}
		var edges := {"normal": Color("a99b79"), "hover": PAPER,
			"pressed": Color("c5ab73"), "disabled": Color("777166")}
		shared.set_stylebox(state, "Button", _panel(fills[state], edges[state]))
		shared.set_color("font_" + state + "_color", "Button", Color("aaa391") if state == "disabled" else PAPER)
	shared.set_color("font_color", "Button", PAPER)
	shared.set_color("font_hover_pressed_color", "Button", PAPER)
	shared.set_stylebox("hover_pressed", "Button", shared.get_stylebox("pressed", "Button"))
	var focus := _panel(Color.TRANSPARENT, Color("f5d480"), 3)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	shared.set_stylebox("focus", "Button", focus)
	shared.set_font_size("font_size", "Button", 18)
	return shared


func _bind_title() -> void:
	var app = get_parent()
	_title = app.title_view
	_label = app.title_label
	_actions.assign([app.start_button, app.route_button, app.base_button])
	# App creates the full-screen ColorRect first. Draw after it, before title actions.
	app.move_child(self, _title.get_index() - 1)
	_label.theme_type_variation = "TitleLabel"
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_constant_override("outline_size", 0)
	for button in _actions:
		button.add_child(ButtonStitches.new())
		# The menu backing follows the real action rects; containers may lay them out
		# after the first draw, so every later rect change repaints the backing.
		button.item_rect_changed.connect(queue_redraw)
	_title.visibility_changed.connect(_sync_visibility)
	_title.resized.connect(queue_redraw)
	_title.item_rect_changed.connect(queue_redraw)
	_label.item_rect_changed.connect(queue_redraw)
	_sync_visibility()


func _sync_visibility() -> void:
	visible = _title.visible
	queue_redraw()


func _sewn_patch(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= points.size()
	for index in range(points.size()):
		var from := points[index].move_toward(center, 10)
		var to := points[(index + 1) % points.size()].move_toward(center, 10)
		draw_dashed_line(from, to, THREAD, 1.5, 6.0)


## Deterministic torn paper outline: fixed inward bites, so decoration never touches
## either RNG and every corner stays exact (always a triangulable simple polygon).
static func _torn_rect(rect: Rect2, depth: float) -> PackedVector2Array:
	const EDGE_STEPS := 4
	var torn := PackedVector2Array()
	for index in range(EDGE_STEPS):
		var t := float(index) / float(EDGE_STEPS)
		torn.append(Vector2(lerpf(rect.position.x, rect.end.x, t),
			rect.position.y + _bite(index, depth)))
	for index in range(EDGE_STEPS):
		var t := float(index) / float(EDGE_STEPS)
		torn.append(Vector2(rect.end.x - _bite(index + 1, depth),
			lerpf(rect.position.y, rect.end.y, t)))
	for index in range(EDGE_STEPS):
		var t := float(index) / float(EDGE_STEPS)
		torn.append(Vector2(lerpf(rect.end.x, rect.position.x, t),
			rect.end.y - _bite(index + 2, depth)))
	for index in range(EDGE_STEPS):
		var t := float(index) / float(EDGE_STEPS)
		torn.append(Vector2(rect.position.x + _bite(index + 3, depth),
			lerpf(rect.end.y, rect.position.y, t)))
	return torn


static func _bite(index: int, depth: float) -> float:
	const BITES := [0.0, 0.62, 0.18, 0.86, 0.34, 0.0]
	return float(BITES[index % BITES.size()]) * depth


## One torn, stitched backing with a paper shadow: patchwork edges and seam detail kept.
func _draw_sewn_backing(rect: Rect2, fill: Color) -> void:
	var torn := _torn_rect(rect, 6.0)
	var shadow := PackedVector2Array()
	for point in torn:
		shadow.append(point + Vector2(4, 5))
	draw_colored_polygon(shadow, Color(0.11, 0.1, 0.09, 0.38))
	_sewn_patch(torn, fill)


## Code-drawn sewn horizon shown only when the owner picture is missing.
func _draw_fallback_picture() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FALLBACK_STAGE)
	var bands := [[0.54, Color("4c5548")], [0.7, Color("5a614b")], [0.86, Color("6b6046")]]
	for band in bands:
		var top: float = size.y * float(band[0])
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, top + 22.0), Vector2(size.x * 0.34, top - 8.0),
			Vector2(size.x * 0.68, top + 16.0), Vector2(size.x, top - 12.0),
			Vector2(size.x, size.y), Vector2(0.0, size.y)]), band[1])


func _draw() -> void:
	if not is_instance_valid(_label):
		return
	# Owner-supplied picture first: the whole viewport, proportions preserved.
	if _backdrop != null:
		draw_texture_rect(_backdrop, backdrop_rect(), false)
	else:
		_draw_fallback_picture()
	# Only two compact sewn backings follow the live controls. The rest of the picture
	# stays uncovered scenery, and every original control still draws above this shell.
	var banner := title_backing_rect()
	if banner.size.x > 0 and banner.size.y > 0:
		_draw_sewn_backing(banner, PAPER)
	var menu := action_backing_rect()
	if menu.size.x > 0 and menu.size.y > 0:
		_draw_sewn_backing(menu, ACTION_BACKING)
