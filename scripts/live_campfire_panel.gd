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
const HEAL_TEXT := "1 Heal · 30%"
const LEAVE_TEXT := "0 Leave · free"
const REST_ART_PATH := "res://assets/paper/backgrounds/rest_camp.png"
const REST_REDUCED_MOTION_SETTING := "accessibility/reduced_motion"
## One authored decoration: the already-present rest art, cropped to the sewn
## frame and slightly dimmed so cream text stays legible above it.
const REST_ART_ALPHA := 0.85
## The image stays oversized for the frame by this margin, so the restrained
## breath and drift below never reveal an image edge at any panel size.
const REST_ART_OVERSAMPLE := 1.03
const REST_ART_BREATH := 0.012
const REST_ART_PAN := Vector2(3.0, 2.0)
const REST_ART_BREATH_PERIOD := 7.0
const REST_ART_PAN_PERIOD := 11.0

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

## Authored rest-art decoration, drawn only inside the panel's own canvas item:
## never a child node, so it can never take mouse or keyboard focus.
var rest_art_texture: Texture2D
## Nullable explicit reduced-motion override for focused tests and hosts; null
## follows ProjectSettings accessibility/reduced_motion (default false).
var reduced_motion_override: Variant = null
var _rest_art_elapsed := 0.0


func _ready() -> void:
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	rest_art_texture = _load_rest_art()
	visibility_changed.connect(_on_rest_art_visibility_changed)
	title_label = _label("CAMPFIRE", Vector2(48, 31), Vector2(770, 62), 44, MUSTARD)
	for i in range(3):
		hero_labels.append(_label("", Vector2(70, 161 + i * 97),
			Vector2(740, 70), 26, CREAM))
	heal_button = _button(HEAL_TEXT, Vector2(48, 498), Vector2(373, 72), OXBLOOD)
	leave_button = _button(LEAVE_TEXT, Vector2(459, 498), Vector2(373, 72), TEAL)
	heal_button.tooltip_text = "1 → Heal each hero 30% max HP (Torn revives at 1 HP first)"
	leave_button.tooltip_text = "0 → Leave (2 also works)"
	_refresh()
	_focus_default()


func _draw() -> void:
	# Gothic sewn felt and a simple compact flame; never a mouse target.
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), PLUM)
	_draw_rest_art()
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


## The only decoration this screen ever animates: the already-present authored
## rest art, painted behind every stitched layer and every actionable child.
## It lives inside the panel's own canvas item, so it is structurally
## ineligible for mouse or focus input, and only its visual crop transform moves.
func _draw_rest_art() -> void:
	if rest_art_texture == null:
		return
	var frame := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	var crop := rest_art_crop(rest_art_texture.get_size(), frame, rest_art_transform())
	if crop.is_empty():
		return
	var dest: Rect2 = crop["rect"]
	var region: Rect2 = crop["region"]
	draw_texture_rect_region(rest_art_texture, dest, region,
		Color(1.0, 1.0, 1.0, REST_ART_ALPHA))


static func _load_rest_art() -> Texture2D:
	if not FileAccess.file_exists(REST_ART_PATH) or not ResourceLoader.exists(REST_ART_PATH, "Texture2D"):
		return null
	return load(REST_ART_PATH) as Texture2D


## Pure deterministic presentation transform: a slow ~1% scale breath plus a
## few pixels of drift, both exactly at rest at elapsed zero. No RNG and no
## wall clock; the caller accumulates a deterministic delta.
static func rest_art_transform_at(elapsed: float) -> Dictionary:
	var breath := 0.5 - 0.5 * cos(TAU * fposmod(elapsed, REST_ART_BREATH_PERIOD) / REST_ART_BREATH_PERIOD)
	var clock := TAU * fposmod(elapsed, REST_ART_PAN_PERIOD) / REST_ART_PAN_PERIOD
	return {
		"scale": 1.0 + REST_ART_BREATH * breath,
		"offset": Vector2(sin(clock), sin(2.0 * clock)) * REST_ART_PAN,
	}


## Pure crop math shared by the renderer and focused tests: the breathing,
## drifting image stays oversized for the sewn frame, so the source region never
## reaches an image edge and the drawn rect is exactly the full frame.
static func rest_art_crop(image_size: Vector2, frame: Rect2, motion: Dictionary) -> Dictionary:
	if image_size.x <= 0.0 or image_size.y <= 0.0 or frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return {}
	var scale := maxf(1.0, float(motion.get("scale", 1.0)))
	var offset: Vector2 = motion.get("offset", Vector2.ZERO)
	var cover := maxf(frame.size.x / image_size.x, frame.size.y / image_size.y) * REST_ART_OVERSAMPLE
	var full_size := image_size * cover * scale
	var origin := frame.get_center() + offset - full_size * 0.5
	return {
		"rect": frame,
		"region": Rect2(image_size * (frame.position - origin) / full_size,
			image_size * frame.size / full_size),
	}


## Motion runs only while a genuinely bound open visit is on a visible mounted
## panel with the authored asset loaded and reduced motion not requested. Every
## stop path (close/bind(null)/rebind, hide, free, missing art, reduced motion)
## restores the exact static baseline transform.
func rest_art_active() -> bool:
	return _visit != null and is_visible_in_tree() and rest_art_texture != null \
		and not _reduced_motion_active()


## Current decorative transform: the static baseline whenever motion is stopped,
## otherwise the deterministic transform at the accumulated presentation time.
func rest_art_transform() -> Dictionary:
	if not rest_art_active():
		return {"scale": 1.0, "offset": Vector2.ZERO}
	return rest_art_transform_at(_rest_art_elapsed)


## Deterministic presentation-time advance for focused tests; live play
## accumulates the same clock through _process with the engine delta.
func advance_rest_art(delta: float) -> void:
	if delta <= 0.0 or not rest_art_active():
		return
	_rest_art_elapsed += delta
	queue_redraw()


func set_reduced_motion_override(value: Variant) -> void:
	reduced_motion_override = value
	if not rest_art_active():
		_reset_rest_art()


func _reduced_motion_active() -> bool:
	if reduced_motion_override != null:
		return bool(reduced_motion_override)
	return bool(ProjectSettings.get_setting(REST_REDUCED_MOTION_SETTING, false))


func _reset_rest_art() -> void:
	if _rest_art_elapsed == 0.0:
		return
	_rest_art_elapsed = 0.0
	if is_inside_tree():
		queue_redraw()


func _on_rest_art_visibility_changed() -> void:
	if not is_visible_in_tree():
		_reset_rest_art()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_reset_rest_art()


## Accumulated presentation delta alone drives the decoration; it never calls the
## visit, the recovery service, the route or any RNG.
func _process(delta: float) -> void:
	if not rest_art_active():
		_reset_rest_art()
		return
	if delta > 0.0:
		_rest_art_elapsed += delta
		queue_redraw()


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
	_reset_rest_art()
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
		_focus_default()


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


## The authentic read-only preview alone decides the safe default: a party that
## can genuinely recover HP starts on Heal, a fully healed party starts on
## Leave so a stray Enter cannot spend the one visit on a zero-gain Heal.
## A Torn hero is never zero-gain: the same preview revives it above 0 HP.
func _preview_gain_positive() -> bool:
	var heroes: Array = _snapshot.get("heroes", [])
	if heroes.size() != 3 or _preview.size() != 3:
		return false
	for i in range(3):
		if int(_preview[i].get("hp", 0)) > int(heroes[i].get("hp", 0)):
			return true
	return false


## Grab keyboard focus for the default choice only while the bound source is
## current and the target is a valid, visible, focusable button.
func _focus_default() -> void:
	if heal_button == null or leave_button == null or not _source_current():
		return
	var target := heal_button if _preview_gain_positive() else leave_button
	if target.disabled or not target.is_visible_in_tree() \
			or target.focus_mode == Control.FOCUS_NONE:
		return
	target.grab_focus()


func _hero_text(i: int) -> String:
	var hero: Dictionary = _snapshot["heroes"][i]
	var forecast: Dictionary = _preview[i]
	var display_name: String = str(hero.get("name", "")).strip_edges()
	if display_name.is_empty():
		display_name = str(hero["id"]).replace("_", " ").capitalize()
	var before: int = int(hero["hp"])
	var after: int = int(forecast["hp"])
	var maximum: int = int(hero["max_hp"])
	var gain: int = after - before
	var gain_text := "FULL" if gain == 0 else ("(+%d HP)" % gain)
	var note := "  ·  TORN → REVIVED" if before == 0 else ""
	return "%s    %d → %d / %d HP  ·  %s%s" % [display_name, before, after, maximum, gain_text, note]


func _display_current() -> bool:
	if title_label == null or title_label.text != "CAMPFIRE" \
			or heal_button.text != HEAL_TEXT or leave_button.text != LEAVE_TEXT:
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
	# The authenticated preview alone admits Heal: a party whose forecast
	# recovers no HP cannot spend its one visit on a zero-gain Heal. Leave
	# stays available for every genuinely open visit.
	heal_button.disabled = not valid or not _preview_gain_positive()
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


func _request(action: String, generation: int, source: RunCampfireVisit) -> bool:
	if generation != _epoch or source == null or not is_same(_visit, source) \
			or not is_inside_tree() or not is_visible_in_tree() \
			or not _source_current() or not _display_current() \
			or (action != "heal" and action != "leave"):
		return false
	var button := heal_button if action == "heal" else leave_button
	if button.disabled or not button.is_visible_in_tree():
		return false
	_submitted = true
	heal_button.disabled = true
	leave_button.disabled = true
	decision_requested.emit({
		"action": action,
		"source_visit": source,
		"node_id": _snapshot["node_id"],
		"expected_heroes": _snapshot["heroes"].duplicate(true),
	})
	return true


## Numbered shortcuts belong to this Campfire only while one of its own controls
## owns keyboard focus, so a key typed into another screen's focused control is
## never stolen. The panel itself stays a valid owner if it ever takes focus.
func _owns_focus() -> bool:
	if not is_inside_tree():
		return false
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner))


## Physical 1/0 hands the numbered action to the same generation-bound pressed
## callback the mouse and focus paths use (2 stays a working Leave alias), so
## the bound visit, snapshot, submission, visibility and disabled state still
## decide. Closed, hidden, spent, disabled, modified, unfocused and unnumbered
## keys are inert.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo or not event.pressed:
		return
	var key := event as InputEventKey
	if key.shift_pressed or key.alt_pressed or key.ctrl_pressed or key.meta_pressed:
		return
	if not _owns_focus():
		return
	if key.keycode == KEY_1 or key.keycode == KEY_KP_1:
		if not is_inside_tree() or not is_visible_in_tree():
			return
		if _submitted or _visit == null or _snapshot.is_empty() or not _source_current() or not _display_current():
			return
		if heal_button.disabled or not heal_button.is_visible_in_tree():
			return
		if _request("heal", _epoch, _visit):
			get_viewport().set_input_as_handled()
	elif key.keycode == KEY_2 or key.keycode == KEY_KP_2 \
			or key.keycode == KEY_0 or key.keycode == KEY_KP_0:
		if not is_inside_tree() or not is_visible_in_tree():
			return
		if _submitted or _visit == null or _snapshot.is_empty() or not _source_current() or not _display_current():
			return
		if leave_button.disabled or not leave_button.is_visible_in_tree():
			return
		if _request("leave", _epoch, _visit):
			get_viewport().set_input_as_handled()
