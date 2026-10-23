class_name BaseScreen
extends Control
## The Quilt Village: the patchwork base between the title and a run.
## Presentation only. It allocates no run, RNG, deck or currency state and
## reports exactly two sewn actions, Set out and Back to title, which the host
## validates by view identity and visibility before acting on them.
##
## The owner's base_village.png is mounted as a cover backdrop only when
## ResourceLoader confirms the art exists. The matte quilt ground, sewn houses
## and tents, central spool and running-stitch paths are always drawn, so the
## village stays readable and identifiable with or without the optional image.

signal set_out_requested
signal back_requested

const BASE_BACKDROP := "res://assets/paper/backgrounds/base_village.png"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const INK := Color("#2b3135")
const PAPER := Color("#ecdfbd")
const THREAD := Color("#c9b996")
const MATTE := Color("#414c48")
const PIN_PAPER := Color("#f3e8cd")
const PIN_THREAD := Color("#85715b")
const LABEL_FONT_SIZE := 18

var set_out_button: Button
var back_button: Button
var village_title_label: Label
var wallet_label: Label

var _open := false
var _set_out_pending := false
var _back_pending := false
var _backdrop: Texture2D
var _buildings: Array = []
var _paths: Array = []
var _spool_rect := Rect2()


## Dashed thread stitching and cross-stitches; never takes pointer or focus.
class SewnEdge extends Control:
	const EDGE := Color("#c9b996")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 18.0 or size.y <= 16.0:
			return
		var inset := Rect2(Vector2(7.0, 6.0), size - Vector2(14.0, 12.0))
		var corners := [inset.position, Vector2(inset.end.x, inset.position.y), inset.end,
			Vector2(inset.position.x, inset.end.y)]
		for index in range(corners.size()):
			draw_dashed_line(corners[index], corners[(index + 1) % corners.size()], EDGE, 1.0, 5.0)
		for corner: Vector2 in corners:
			draw_line(corner + Vector2(-3, -3), corner + Vector2(3, 3), EDGE, 1.0, true)
			draw_line(corner + Vector2(3, -3), corner + Vector2(-3, 3), EDGE, 1.0, true)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build_layout()
	_backdrop = load_base_backdrop()
	_build_top_strip()
	_build_actions()
	_wire_focus()
	resized.connect(queue_redraw)
	_apply_closed_state()


## Author the deterministic village once: no randomness, no RNG draw.
func _build_layout() -> void:
	_buildings = [
		{"label": "Heroes", "kind": "house", "rect": Rect2(112, 240, 190, 150),
			"cloth": Color("#7b8a6a"), "roof": Color("#8c6550")},
		{"label": "Camp", "kind": "tent", "rect": Rect2(352, 236, 180, 160),
			"cloth": Color("#8f7a55"), "roof": Color("#8f7a55")},
		{"label": "Deck", "kind": "house", "rect": Rect2(778, 240, 190, 150),
			"cloth": Color("#6f7f86"), "roof": Color("#9a6b52")},
		{"label": "Settings", "kind": "tent", "rect": Rect2(1000, 400, 176, 140),
			"cloth": Color("#7f7086"), "roof": Color("#7f7086")},
	]
	_spool_rect = Rect2(600, 214, 80, 186)
	_paths = [
		PackedVector2Array([Vector2(302, 315), Vector2(380, 320), Vector2(470, 330), Vector2(600, 318)]),
		PackedVector2Array([Vector2(442, 396), Vector2(520, 400), Vector2(580, 370), Vector2(600, 348)]),
		PackedVector2Array([Vector2(778, 316), Vector2(700, 318), Vector2(680, 318)]),
		PackedVector2Array([Vector2(1088, 400), Vector2(980, 392), Vector2(820, 372),
			Vector2(690, 356), Vector2(680, 342)]),
		PackedVector2Array([Vector2(640, 400), Vector2(640, 470), Vector2(640, 540), Vector2(640, 604)]),
	]


## A missing owner image leaves the drawn matte village instead of failing boot.
static func load_base_backdrop(path: String = BASE_BACKDROP) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


## Cover the whole view while preserving the image proportions.
func cover_rect_for(texture: Texture2D, view_size: Vector2 = Vector2.ZERO) -> Rect2:
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		return Rect2()
	var view := size if view_size == Vector2.ZERO else view_size
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	if view.x <= 0.0 or view.y <= 0.0:
		return Rect2()
	var fit := maxf(view.x / texture_size.x, view.y / texture_size.y)
	return Rect2((view - texture_size * fit) / 2.0, texture_size * fit)


func backdrop_rect() -> Rect2:
	return cover_rect_for(_backdrop)


func backdrop_path() -> String:
	return BASE_BACKDROP


func backdrop_texture() -> Texture2D:
	return _backdrop


func has_backdrop_texture() -> bool:
	return _backdrop != null


func village_buildings() -> Array:
	return _buildings.duplicate(true)


func village_paths() -> Array:
	return _paths.duplicate(true)


func village_spool() -> Rect2:
	return _spool_rect


func has_open_village() -> bool:
	return _open


## Host entry point after mounting. Returns false while already open.
func open_village(gold: int = 0, scraps: int = 0) -> bool:
	if _open or not is_instance_valid(set_out_button) or not is_instance_valid(back_button):
		return false
	_open = true
	_set_out_pending = false
	_back_pending = false
	set_out_button.disabled = false
	back_button.disabled = false
	if is_instance_valid(wallet_label):
		wallet_label.text = "Gold %d  ·  Scraps %d" % [gold, scraps]
	visible = true
	queue_redraw()
	set_out_button.grab_focus()
	return true


func close_village() -> void:
	_apply_closed_state()


func _apply_closed_state() -> void:
	_open = false
	_set_out_pending = false
	_back_pending = false
	visible = false
	if is_instance_valid(set_out_button):
		set_out_button.disabled = true
		set_out_button.release_focus()
	if is_instance_valid(back_button):
		back_button.disabled = true
		back_button.release_focus()


## The host refused Set out (no run was created): restore the sewn action.
func release_set_out() -> bool:
	if not _open or _back_pending or not is_instance_valid(set_out_button):
		return false
	_set_out_pending = false
	set_out_button.disabled = false
	if is_instance_valid(back_button):
		back_button.disabled = false
	set_out_button.grab_focus()
	return true


func _build_top_strip() -> void:
	var strip := PanelContainer.new()
	strip.name = "TopStrip"
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 24.0
	strip.offset_right = -24.0
	strip.offset_top = 16.0
	strip.offset_bottom = 72.0
	strip.custom_minimum_size = Vector2(0, 56)
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_color = Color("#766351")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 12.0
	paper.content_margin_right = 14.0
	paper.content_margin_top = 6.0
	paper.content_margin_bottom = 6.0
	strip.add_theme_stylebox_override("panel", paper)
	add_child(strip)

	var row := HBoxContainer.new()
	row.name = "StripRow"
	row.add_theme_constant_override("separation", 18)
	strip.add_child(row)

	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back to title"
	back_button.custom_minimum_size = Vector2(200, 40)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.tooltip_text = "Return to the title"
	back_button.pressed.connect(_on_back_pressed)
	back_button.add_child(SewnEdge.new())
	row.add_child(back_button)

	village_title_label = Label.new()
	village_title_label.name = "VillageTitle"
	village_title_label.text = "Quilt village"
	village_title_label.add_theme_color_override("font_color", INK)
	village_title_label.add_theme_font_size_override("font_size", 30)
	village_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(village_title_label)

	var spacer := Control.new()
	spacer.name = "StripSpacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.focus_mode = Control.FOCUS_NONE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	wallet_label = Label.new()
	wallet_label.name = "Wallet"
	wallet_label.text = "Gold 0  ·  Scraps 0"
	wallet_label.add_theme_color_override("font_color", INK)
	wallet_label.add_theme_font_size_override("font_size", 20)
	wallet_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wallet_label)


func _build_actions() -> void:
	var row := HBoxContainer.new()
	row.name = "SetOutRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 24.0
	row.offset_right = -24.0
	row.offset_top = -104.0
	row.offset_bottom = -24.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	set_out_button = Button.new()
	set_out_button.name = "SetOutButton"
	set_out_button.text = "Set out"
	set_out_button.custom_minimum_size = Vector2(380, 72)
	set_out_button.add_theme_font_size_override("font_size", 30)
	set_out_button.tooltip_text = "Choose this run's opening route"
	set_out_button.pressed.connect(_on_set_out_pressed)
	set_out_button.add_child(SewnEdge.new())
	row.add_child(set_out_button)


## Both sewn actions form one forward/reverse Tab loop.
func _wire_focus() -> void:
	set_out_button.focus_next = set_out_button.get_path_to(back_button)
	set_out_button.focus_previous = set_out_button.get_path_to(back_button)
	back_button.focus_next = back_button.get_path_to(set_out_button)
	back_button.focus_previous = back_button.get_path_to(set_out_button)


func _on_set_out_pressed() -> void:
	if not _open or _set_out_pending or _back_pending:
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if not is_instance_valid(set_out_button) or set_out_button.disabled:
		return
	_set_out_pending = true
	set_out_button.disabled = true
	if is_instance_valid(back_button):
		back_button.disabled = true
	set_out_requested.emit()


func _on_back_pressed() -> void:
	if not _open or _back_pending or _set_out_pending:
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if not is_instance_valid(back_button) or back_button.disabled:
		return
	_back_pending = true
	back_button.disabled = true
	if is_instance_valid(set_out_button):
		set_out_button.disabled = true
	back_requested.emit()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), MATTE)
	if _backdrop != null:
		draw_texture_rect(_backdrop, backdrop_rect(), false)
	var scale_to_view := size / DESIGN_SIZE
	draw_set_transform(Vector2.ZERO, 0.0, scale_to_view)
	if _backdrop == null:
		_draw_quilt_ground()
	_draw_paths()
	for building in _buildings:
		_draw_building(building)
	_draw_spool()
	for building in _buildings:
		_draw_pin_label(building)
	draw_set_transform(Vector2.ZERO)


## Matte sewn quilt ground: large felt patches joined with running stitches.
func _draw_quilt_ground() -> void:
	var patches := [
		{"rect": Rect2(60, 120, 470, 330), "fill": Color("#4d5a54")},
		{"rect": Rect2(520, 110, 300, 360), "fill": Color("#5b5443")},
		{"rect": Rect2(810, 130, 410, 300), "fill": Color("#4a5459")},
		{"rect": Rect2(90, 460, 1100, 120), "fill": Color("#565144")},
	]
	for patch in patches:
		draw_rect(patch.rect, patch.fill)
		_stitched_rect((patch.rect as Rect2).grow(-4.0), THREAD)
		var center: Vector2 = (patch.rect as Rect2).get_center()
		draw_line(center + Vector2(-7, -7), center + Vector2(7, 7), PIN_THREAD, 1.5, true)
		draw_line(center + Vector2(7, -7), center + Vector2(-7, 7), PIN_THREAD, 1.5, true)


func _draw_paths() -> void:
	for path in _paths:
		var points: PackedVector2Array = path
		for index in range(points.size() - 1):
			draw_dashed_line(points[index], points[index + 1], THREAD, 2.0, 7.0)
		for point in points:
			draw_circle(point, 5.0, PIN_THREAD)
			draw_circle(point, 2.5, PAPER)


func _draw_building(building: Dictionary) -> void:
	var body: Rect2 = building.rect
	var cloth: Color = building.cloth
	if String(building.kind) == "tent":
		var apex := Vector2(body.get_center().x, body.position.y - 46.0)
		draw_colored_polygon(PackedVector2Array([apex,
			Vector2(body.position.x, body.end.y), Vector2(body.end.x, body.end.y)]), cloth)
		draw_line(apex, Vector2(apex.x, body.end.y + 4.0), THREAD, 3.0, true)
		draw_dashed_line(apex + Vector2(0, 14), Vector2(body.position.x + 14, body.end.y - 10), THREAD, 1.2, 6.0)
		draw_dashed_line(apex + Vector2(0, 14), Vector2(body.end.x - 14, body.end.y - 10), THREAD, 1.2, 6.0)
		# Sewn door flap on the tent cloth.
		draw_colored_polygon(PackedVector2Array([apex + Vector2(0, 60),
			Vector2(apex.x - 17, body.end.y), Vector2(apex.x + 17, body.end.y)]), Color("#4b4038"))
		_stitched_rect(Rect2(body.position, body.size), THREAD)
		return
	draw_rect(body, cloth)
	var roof: Color = building.roof
	var eave := 14.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(body.position.x - eave, body.position.y + 6.0),
		Vector2(body.get_center().x, body.position.y - 46.0),
		Vector2(body.end.x + eave, body.position.y + 6.0)]), roof)
	_stitched_rect(body, THREAD)
	# One sewn door and one lit window keep each house readable at a glance.
	draw_rect(Rect2(Vector2(body.get_center().x - 18.0, body.end.y - 46.0), Vector2(36, 46)),
		Color("#4b4038"))
	draw_rect(Rect2(Vector2(body.position.x + 20.0, body.position.y + 30.0), Vector2(34, 30)),
		Color("#e9d79f"))
	_stitched_rect(Rect2(Vector2(body.position.x + 20.0, body.position.y + 30.0), Vector2(34, 30)), PIN_THREAD)


## Central spool tower with wound thread and a needle; the village landmark.
func _draw_spool() -> void:
	var body := _spool_rect
	var center := body.get_center()
	draw_rect(body, Color("#d9c9a4"))
	var wound := 0
	while wound < 8:
		var y := body.position.y + 14.0 + wound * 20.0
		draw_dashed_line(Vector2(body.position.x + 4.0, y), Vector2(body.end.x - 4.0, y),
			Color("#a78b62"), 1.6, 5.0)
		wound += 1
	_stitched_rect(body, THREAD)
	for flange in [Rect2(Vector2(center.x - 66.0, body.position.y - 18.0), Vector2(132, 22)),
			Rect2(Vector2(center.x - 66.0, body.end.y - 4.0), Vector2(132, 22))]:
		draw_rect(flange, Color("#8c6550"))
		_stitched_rect(flange, THREAD)
	draw_dashed_line(Vector2(center.x, body.position.y - 18.0),
		Vector2(center.x + 18.0, body.position.y - 74.0), THREAD, 2.0, 6.0)
	draw_circle(Vector2(center.x, body.position.y - 88.0), 12.0, PIN_PAPER)
	draw_circle(Vector2(center.x, body.position.y - 88.0), 6.0, PIN_THREAD)


## Pinned name label above each building, joined to the roof with one stitch.
func _draw_pin_label(building: Dictionary) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var body: Rect2 = building.rect
	var text := String(building.label)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	if text_size.x <= 0.0:
		return
	var patch := Rect2(Vector2(body.get_center().x - text_size.x / 2.0 - 12.0,
		body.position.y - 96.0), Vector2(text_size.x + 24.0, 30.0))
	draw_rect(patch, PIN_PAPER)
	_stitched_rect(patch.grow(-3.0), PIN_THREAD)
	draw_dashed_line(Vector2(body.get_center().x, patch.end.y),
		Vector2(body.get_center().x, body.position.y - 46.0), PIN_THREAD, 1.0, 4.0)
	draw_string(font, Vector2(patch.position.x + 12.0, patch.position.y + 21.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, INK)


func _stitched_rect(rect: Rect2, color: Color) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for index in range(corners.size()):
		draw_dashed_line(corners[index], corners[(index + 1) % corners.size()], color, 1.2, 6.0)
