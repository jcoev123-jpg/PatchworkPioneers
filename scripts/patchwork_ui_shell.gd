extends Control
## Presentation only. Child readiness installs the theme before App builds its UI.

const INK := Color("302b29")
const PAPER := Color("ecdfbd")
const THREAD := Color("c9b996")
var _title: Control
var _label: Label


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
	get_parent().theme = _build_theme()
	get_parent().ready.connect(_bind_title, CONNECT_ONE_SHOT)
	resized.connect(queue_redraw)


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
	# App creates the full-screen ColorRect first. Draw after it, before title actions.
	app.move_child(self, _title.get_index() - 1)
	_label.theme_type_variation = "TitleLabel"
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_constant_override("outline_size", 0)
	for button in [app.start_button, app.route_button]:
		button.add_child(ButtonStitches.new())
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


func _draw() -> void:
	if not is_instance_valid(_label):
		return
	# Authored, deterministic cut edges: decoration never touches either RNG.
	var scale_to_view := size / Vector2(1280, 720)
	draw_set_transform(Vector2.ZERO, 0.0, scale_to_view)
	_sewn_patch(PackedVector2Array([Vector2(42, 60), Vector2(462, 38), Vector2(480, 650), Vector2(24, 674)]), Color("414c48"))
	_sewn_patch(PackedVector2Array([Vector2(824, 36), Vector2(1230, 76), Vector2(1252, 676), Vector2(800, 646)]), Color("594c48"))
	_sewn_patch(PackedVector2Array([Vector2(216, 130), Vector2(1062, 110), Vector2(1092, 614), Vector2(196, 632)]), Color("74714e"))
	_sewn_patch(PackedVector2Array([Vector2(276, 178), Vector2(1002, 166), Vector2(1026, 568), Vector2(258, 580)]), Color("4d5a54"))
	_sewn_patch(PackedVector2Array([Vector2(76, 506), Vector2(186, 514), Vector2(178, 620), Vector2(68, 612)]), Color("8c6550"))
	_sewn_patch(PackedVector2Array([Vector2(1100, 112), Vector2(1202, 102), Vector2(1210, 202), Vector2(1112, 214)]), Color("79738a"))
	draw_set_transform(Vector2.ZERO)
	# Follow the existing title label, including container layout and viewport resizing.
	var banner := Rect2(_label.global_position - global_position, _label.size).grow_individual(36, 24, 36, 24)
	var a := banner.position
	var b := banner.end
	_sewn_patch(PackedVector2Array([a + Vector2(0, 7), Vector2(a.x + 92, a.y),
		Vector2(b.x - 80, a.y + 3), Vector2(b.x, a.y - 3), Vector2(b.x - 8, b.y - 12),
		b, Vector2(a.x + 70, b.y - 4), Vector2(a.x - 6, b.y)]), PAPER)
