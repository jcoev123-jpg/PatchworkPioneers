extends Control
## Presentation only. App owns the shared Theme before this child becomes ready.

const INK := Color("171419")
const PAPER := Color("e9ddc7")
const THREAD := Color("998053")
const TITLE_BACKDROP := "res://assets/paper/backgrounds/title.png"
## Stuffed-fabric wordmark drawn in place of the title text; the live label keeps its text.
const TITLE_LOGO := "res://assets/paper/ui/title_logo.png"
## Color is applied only when painting; the owner-supplied PNG is untouched.
const LOGO_TINT := Color("c9b7a4")
## Widest the wordmark may grow, centred on the title banner.
const LOGO_MAX_WIDTH := 760.0
## Small periodic presentation drift; independent of both gameplay and global RNG.
const LOGO_MOTION_PERIOD := 8.0
const LOGO_MOTION_OFFSET := Vector2(3.0, 1.5)
const LOGO_MOTION_ROTATION := 0.012
## Padded felt the title actions are sewn onto; the drawn felt patch is its fallback.
const MENU_FELT := "res://assets/paper/ui/panel_felt.png"
## Keep the original font Theme as a read-only fallback and font-family reference.
const THEME_PATH := "res://assets/fonts/patchwork_theme.tres"
const GOTHIC_THEME_PATH := "res://themes/gothic_theme.tres"
const TITLE_FONT := "res://assets/fonts/LondrinaSolid-Black.ttf"
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
## Code-drawn ground for a missing owner picture; never a blank felt screen.
const FALLBACK_STAGE := Color("171419")
## Dark oxblood backing behind the live title actions.
const ACTION_BACKING := Color("352126")
## The two sewn backings stay inside this share of the picture, so scenery stays visible.
const MENU_COVERAGE_LIMIT := 0.35
var _title: Control
var _label: Label
var _actions: Array[Button] = []
var _backdrop: Texture2D
var _logo: Texture2D
var _menu_felt: StyleBoxTexture
var _logo_elapsed := 0.0
var _reduced_motion_override: Variant = null


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
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = _load_backdrop()
	_logo = _load_backdrop(TITLE_LOGO)
	var felt := _load_backdrop(MENU_FELT)
	if felt != null:
		_menu_felt = StyleBoxTexture.new()
		_menu_felt.texture = felt
		_menu_felt.modulate_color = Color("725457")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_menu_felt.set_texture_margin(side, 48)
	if get_parent().theme == null:
		get_parent().theme = _build_theme()
	get_parent().ready.connect(_bind_title, CONNECT_ONE_SHOT)
	resized.connect(queue_redraw)


## A missing owner image leaves the existing drawn backdrop instead of failing boot.
static func _load_backdrop(path: String = TITLE_BACKDROP) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


## A detached copy of the master Theme, or an empty Theme when it is unavailable: the
## shell then still owns every style it sets, and the master resource is never mutated.
static func _load_master_theme(path: String = THEME_PATH) -> Theme:
	if path.is_empty() or not ResourceLoader.exists(path, "Theme"):
		return Theme.new()
	var master := load(path) as Theme
	if master == null:
		return Theme.new()
	var copy := master.duplicate(true) as Theme
	return copy if copy != null else Theme.new()


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


## The wordmark fills the space above the menu, centred on the title banner, proportions kept.
func logo_rect() -> Rect2:
	var banner := title_backing_rect()
	if _logo == null or not banner.has_area() or _logo.get_width() <= 0 or _logo.get_height() <= 0:
		return Rect2()
	var room := Rect2(banner.get_center().x - LOGO_MAX_WIDTH / 2.0, 12.0,
		LOGO_MAX_WIDTH, banner.end.y - 12.0)
	var texture_size := Vector2(_logo.get_width(), _logo.get_height())
	var fit := minf(room.size.x / texture_size.x, room.size.y / texture_size.y)
	var drawn := texture_size * fit
	return Rect2(Vector2(room.get_center().x - drawn.x / 2.0, room.end.y - drawn.y), drawn)


## Compact felt backing that follows the live title actions, in shell coordinates.
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


## The real App owns the gothic Theme in its scene. Do not replace or mutate it;
## detached callers (including UI fixtures) resolve the same resource.
func _build_theme() -> Theme:
	var host := get_parent() as Control
	if host != null and host.theme != null:
		return host.theme
	if ResourceLoader.exists(GOTHIC_THEME_PATH, "Theme"):
		var gothic := load(GOTHIC_THEME_PATH) as Theme
		if gothic != null:
			return gothic
	return _load_master_theme()


## Reuse pipeline art as nine-patch UI, with the same legible flat fallback as
## the rest of the shell when an image cannot be loaded.
func _fabric_style(path: String, tint: Color, margin: int = 8) -> StyleBox:
	var texture := _load_backdrop(path)
	if texture == null:
		return _panel(tint, THREAD)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
		style.set_content_margin(side, margin)
	return style


func _bind_title() -> void:
	var app = get_parent()
	_title = app.title_view
	_label = app.title_label
	_actions.assign([app.start_button, app.stitched_continue_button, app.base_button])
	# App creates the full-screen ColorRect first. Draw after it, before title actions.
	app.move_child(self, _title.get_index() - 1)
	_label.theme_type_variation = "PatchTitle"
	_label.add_theme_color_override("font_color", PAPER)
	_label.add_theme_constant_override("outline_size", 0)
	# The live label remains in layout and accessible; the sync chooses whether it paints.
	for button in _actions:
		# Every live title action speaks in the master Theme's Londrina heading face.
		button.theme_type_variation = "PatchHeadingButton"
		button.add_theme_font_size_override("font_size", 28)
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
	_sync_logo_motion()


## Like the reward panel, null follows the accessibility ProjectSetting and a boolean
## override lets mounted tests exercise both settings without changing player options.
func set_reduced_motion_override(value: Variant) -> void:
	_reduced_motion_override = value if value is bool else null
	_sync_logo_motion()


func _reduced_motion() -> bool:
	if _reduced_motion_override is bool:
		return _reduced_motion_override
	return ProjectSettings.get_setting("accessibility/reduced_motion", false) == true


func _can_animate_logo() -> bool:
	return is_node_ready() and visible and is_instance_valid(_title) \
		and _title.is_visible_in_tree() and not _reduced_motion() \
		and _logo != null and logo_rect().has_area()


func _sync_logo_motion() -> void:
	set_process(false)
	_logo_elapsed = 0.0
	if is_instance_valid(_label):
		_label.self_modulate = Color(1, 1, 1, 0) if logo_rect().has_area() else Color.WHITE
	if _can_animate_logo():
		set_process(true)
	queue_redraw()


## Purely a draw-time transform. Never changes shell, label or hit-target geometry.
func logo_motion() -> Dictionary:
	if not _can_animate_logo():
		return {"offset": Vector2.ZERO, "rotation": 0.0}
	var phase := TAU * _logo_elapsed / LOGO_MOTION_PERIOD
	return {"offset": Vector2(LOGO_MOTION_OFFSET.x * sin(phase),
		LOGO_MOTION_OFFSET.y * sin(2.0 * phase)),
		"rotation": LOGO_MOTION_ROTATION * sin(phase)}


func _process(delta: float) -> void:
	if not _can_animate_logo():
		_sync_logo_motion()
		return
	_logo_elapsed = fposmod(_logo_elapsed + maxf(delta, 0.0), LOGO_MOTION_PERIOD)
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
	var bands := [[0.54, Color("352126")], [0.7, Color("382a26")], [0.86, Color("503238")]]
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
	var logo := logo_rect()
	if banner.size.x > 0 and banner.size.y > 0 and not logo.has_area():
		_draw_sewn_backing(banner, ACTION_BACKING)
	var menu := action_backing_rect()
	if menu.size.x > 0 and menu.size.y > 0:
		if _menu_felt != null:
			draw_style_box(_menu_felt, menu)
		else:
			_draw_sewn_backing(menu, ACTION_BACKING)
	if logo.has_area():
		var motion := logo_motion()
		draw_set_transform(logo.get_center() + motion["offset"], motion["rotation"], Vector2.ONE)
		draw_texture_rect(_logo, Rect2(-logo.size * 0.5, logo.size), false, LOGO_TINT)
		# Reset the CanvasItem draw state so later decorations never inherit the sway.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
