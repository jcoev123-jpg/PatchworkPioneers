class_name BaseScreen
extends Control
## The Quilt Village: the patchwork base between the title and a run.
## Presentation only. It allocates no run, RNG, deck or currency state and
## reports only sewn actions, Set out, the Heroes Path picks and Back to title,
## which the host validates by view identity and visibility before acting on
## them. The Heroes and Tinker options are authored elsewhere: the host presents
## their readable names and confirms each pick, so this view owns no Path rules,
## no authored data and no deck.
##
## The owner's base_village.png is mounted as a cover backdrop only when
## ResourceLoader confirms the art exists. The matte quilt ground, sewn houses
## and tents, central spool and running-stitch paths are always drawn, so the
## village stays readable and identifiable with or without the optional image.

signal path_choice_requested(path_id: String)
signal tinker_path_choice_requested(path_id: String)
signal warden_path_choice_requested(path_id: String)
signal set_out_requested
signal back_requested

const BASE_BACKDROP := "res://assets/paper/backgrounds/base_village.png"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
## The Heroes house's pinned Path board sits below it, clear of the Camp tent.
const HEROES_PANEL_RECT := Rect2(96, 392, 352, 218)
## The Tinker's own pinned board sits beside the Seamstress one, in the same lower
## band: it never covers the Seamstress board, the buildings or the sewn actions.
const TINKER_PANEL_RECT := Rect2(472, 392, 336, 218)
const WARDEN_PANEL_RECT := Rect2(832, 392, 352, 218)
const WARDEN_SLATE := Color("#4a5d73")
## Dark slate ink for Warden text on the sewn bone paper board.
const WARDEN_INK := Color("#33404f")
const WARDEN_BONE := Color("#d9cfb8")
const WARDEN_RUST := Color("#a4552f")
const INK := Color("#2b3135")
const PAPER := Color("#ecdfbd")
const THREAD := Color("#c9b996")
const MATTE := Color("#414c48")
const PIN_PAPER := Color("#f3e8cd")
const PIN_THREAD := Color("#85715b")
const LABEL_FONT_SIZE := 18
## VIS V6 display hierarchy. The shipped Theme supplies the faces
## (PatchTitle = Londrina Solid Black, PatchHeading = Londrina Solid Regular);
## these are the sizes the village asks for, keeping body text at 18 px or more.
const TITLE_SIZE := 42
const PATH_HEADING_SIZE := 22
const HINT_SIZE := 18
const STATUS_SIZE := 18
## A Path option keeps its 18 px caption and still fits its pinned paper board.
const PATH_OPTION_HEIGHT := 36.0
## Every Path option caption wears the master display face at this body floor.
const PATH_OPTION_SIZE := 18

var set_out_button: Button
var back_button: Button
var village_title_label: Label
var wallet_label: Label
var path_panel: PanelContainer
var path_option_box: VBoxContainer
var path_buttons: Array[Button] = []
var path_hint_label: Label
var path_status_label: Label
var tinker_panel: PanelContainer
var tinker_option_box: VBoxContainer
var tinker_buttons: Array[Button] = []
var tinker_hint_label: Label
var tinker_status_label: Label
var warden_panel: PanelContainer
var warden_option_box: VBoxContainer
var warden_buttons: Array[Button] = []
var warden_hint_label: Label
var warden_status_label: Label

var _open := false
var _set_out_pending := false
var _back_pending := false
var _path_pending := false
var _path_options: Array = []
var _path_previews: Dictionary = {}
var _path_hover_id := ""
var _path_focus_id := ""
var _selected_path_id := ""
var _selected_path_name := ""
var _tinker_pending := false
var _tinker_options: Array = []
var _tinker_previews: Dictionary = {}
var _tinker_hover_id := ""
var _tinker_focus_id := ""
var _selected_tinker_id := ""
var _selected_tinker_name := ""
var _warden_pending := false
var _warden_options: Array = []
var _warden_previews: Dictionary = {}
var _warden_hover_id := ""
var _warden_focus_id := ""
var _selected_warden_id := ""
var _selected_warden_name := ""
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
	_build_heroes_choice()
	_build_tinker_choice()
	_build_warden_choice()
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
	_path_pending = false
	_warden_pending = false
	set_out_button.disabled = false
	back_button.disabled = false
	for button in path_buttons:
		if is_instance_valid(button):
			button.disabled = not _selected_path_id.is_empty()
	for button in tinker_buttons:
		if is_instance_valid(button):
			button.disabled = not _selected_tinker_id.is_empty()
	for button in warden_buttons:
		if is_instance_valid(button):
			button.disabled = not _selected_warden_id.is_empty()
	if is_instance_valid(warden_panel):
		warden_panel.visible = not _warden_options.is_empty()
	if is_instance_valid(path_panel):
		path_panel.visible = not _path_options.is_empty()
	if is_instance_valid(tinker_panel):
		tinker_panel.visible = not _tinker_options.is_empty()
	if is_instance_valid(wallet_label):
		wallet_label.text = "Gold %d  ·  Scraps %d" % [gold, scraps]
	visible = true
	queue_redraw()
	_wire_focus()
	set_out_button.grab_focus()
	return true


## Host-supplied authored options: [{id, display_name, card_name}, ...] in
## authored order. Presentation only; no ID is resolved here. A fresh setup may
## only be presented before the village's one Path is chosen.
func present_path_options(options: Variant) -> bool:
	if not options is Array or not is_instance_valid(path_option_box):
		return false
	if not _selected_path_id.is_empty():
		return false
	var cleaned: Array = []
	var seen: Dictionary = {}
	for raw in options:
		if not raw is Dictionary:
			return false
		var record: Dictionary = raw
		var path_id := String(record.get("id", ""))
		var display_name := String(record.get("display_name", ""))
		if path_id.strip_edges().is_empty() or display_name.strip_edges().is_empty():
			return false
		if seen.has(path_id):
			return false
		seen[path_id] = true
		cleaned.append({"id": path_id, "display_name": display_name,
			"card_name": String(record.get("card_name", ""))})
	if cleaned.is_empty():
		return false
	for button in path_buttons:
		if is_instance_valid(button):
			path_option_box.remove_child(button)
			button.queue_free()
	path_buttons.clear()
	_selected_path_id = ""
	_selected_path_name = ""
	_path_options = cleaned
	_path_previews.clear()
	_path_hover_id = ""
	_path_focus_id = ""
	for option in cleaned:
		var option_id := String(option["id"])
		var button := Button.new()
		button.name = "PathChoice_" + option_id
		button.text = String(option["display_name"])
		var preview := VillagePathPreview.seamstress(option)
		var tooltip := "Seamstress Path: " + String(option["display_name"]) \
			+ (" · card " + String(option["card_name"]) if not String(option["card_name"]).is_empty() else "")
		if not preview.is_empty():
			_path_previews[option_id] = preview
			tooltip = String(preview["tooltip"])
		button.tooltip_text = tooltip
		button.custom_minimum_size = Vector2(0, PATH_OPTION_HEIGHT)
		_sew_path_option_face(button)
		button.set_meta("path_id", option_id)
		button.pressed.connect(_on_path_pressed.bind(option_id))
		button.focus_entered.connect(_on_path_preview_entered.bind(option_id, true))
		button.focus_exited.connect(_on_path_preview_exited.bind(option_id, true))
		button.mouse_entered.connect(_on_path_preview_entered.bind(option_id, false))
		button.mouse_exited.connect(_on_path_preview_exited.bind(option_id, false))
		button.add_child(SewnEdge.new())
		path_option_box.add_child(button)
		path_buttons.append(button)
	if is_instance_valid(path_hint_label):
		path_hint_label.text = "Choose one Path for this run"
	if is_instance_valid(path_status_label):
		path_status_label.text = "No Path chosen yet"
	if is_instance_valid(path_panel):
		path_panel.visible = _open
	_wire_focus()
	return true


## Detached copy of the presented options, in authored order.
func path_options() -> Array:
	return _path_options.duplicate(true)


## The Path this setup has actually confirmed, or "" before a valid pick.
func selected_path_id() -> String:
	return _selected_path_id


func selected_path_name() -> String:
	return _selected_path_name


## Host confirmation of a validated pick: show the actual selected Path and keep
## it; the other option can no longer be chosen. False leaves the view untouched.
func mark_path_selected(path_id: String, display_name: String) -> bool:
	if not _open or _set_out_pending or _back_pending:
		return false
	if not _selected_path_id.is_empty():
		return false
	if path_id.strip_edges().is_empty() or display_name.strip_edges().is_empty():
		return false
	var chosen := _path_button(path_id)
	if chosen == null:
		return false
	_selected_path_id = path_id
	_selected_path_name = display_name
	var card_name := ""
	for option in _path_options:
		if String(option.get("id", "")) == path_id:
			card_name = String(option.get("card_name", ""))
	for button in path_buttons:
		if not is_instance_valid(button):
			continue
		button.disabled = true
		button.release_focus()
	if is_instance_valid(path_hint_label):
		path_hint_label.text = "Path sewn for this run"
	if is_instance_valid(path_status_label):
		path_status_label.text = "Selected: " + display_name \
			+ (" · card " + card_name if not card_name.is_empty() else "")
		path_status_label.show()
	_wire_focus()
	if is_instance_valid(set_out_button):
		_wire_focus()
	set_out_button.grab_focus()
	return true


## Host refusal of a Path request: keep the authored options actionable. A Path
## that was already confirmed cannot be released or replaced.
func release_path_choice() -> bool:
	if not _open or _set_out_pending or _back_pending:
		return false
	if not _selected_path_id.is_empty() or _path_options.is_empty():
		return false
	for button in path_buttons:
		if is_instance_valid(button):
			button.disabled = false
	if is_instance_valid(path_hint_label):
		_refresh_path_hint()
	_wire_focus()
	return true


func close_village() -> void:
	_apply_closed_state()


## Host-supplied authored Tinker options: [{id, display_name, card_name}, ...] in
## authored order. Presentation only; no ID is resolved here. This board is
## independent of the Seamstress one: each pick is offered, confirmed and shown
## once on its own.
func present_tinker_path_options(options: Variant) -> bool:
	if not options is Array or not is_instance_valid(tinker_option_box):
		return false
	if not _selected_tinker_id.is_empty():
		return false
	var cleaned: Array = []
	var seen: Dictionary = {}
	for raw in options:
		if not raw is Dictionary:
			return false
		var record: Dictionary = raw
		var path_id := String(record.get("id", ""))
		var display_name := String(record.get("display_name", ""))
		if path_id.strip_edges().is_empty() or display_name.strip_edges().is_empty():
			return false
		if seen.has(path_id):
			return false
		seen[path_id] = true
		cleaned.append({"id": path_id, "display_name": display_name,
			"card_name": String(record.get("card_name", ""))})
	if cleaned.is_empty():
		return false
	for button in tinker_buttons:
		if is_instance_valid(button):
			tinker_option_box.remove_child(button)
			button.queue_free()
	tinker_buttons.clear()
	_selected_tinker_id = ""
	_selected_tinker_name = ""
	_tinker_options = cleaned
	_tinker_previews.clear()
	_tinker_hover_id = ""
	_tinker_focus_id = ""
	for option in cleaned:
		var option_id := String(option["id"])
		var button := Button.new()
		button.name = "TinkerPathChoice_" + option_id
		button.text = String(option["display_name"])
		var preview := VillagePathPreview.tinker(option)
		var tooltip := "Tinker Path: " + String(option["display_name"]) \
			+ (" · card " + String(option["card_name"]) if not String(option["card_name"]).is_empty() else "")
		if not preview.is_empty():
			_tinker_previews[option_id] = preview
			tooltip = String(preview["tooltip"])
		button.tooltip_text = tooltip
		button.custom_minimum_size = Vector2(0, PATH_OPTION_HEIGHT)
		_sew_path_option_face(button)
		button.set_meta("path_id", option_id)
		button.pressed.connect(_on_tinker_path_pressed.bind(option_id))
		button.focus_entered.connect(_on_tinker_preview_entered.bind(option_id, true))
		button.focus_exited.connect(_on_tinker_preview_exited.bind(option_id, true))
		button.mouse_entered.connect(_on_tinker_preview_entered.bind(option_id, false))
		button.mouse_exited.connect(_on_tinker_preview_exited.bind(option_id, false))
		button.add_child(SewnEdge.new())
		tinker_option_box.add_child(button)
		tinker_buttons.append(button)
	if is_instance_valid(tinker_hint_label):
		tinker_hint_label.text = "Choose one Tinker Path for this run"
	if is_instance_valid(tinker_status_label):
		tinker_status_label.text = "No Tinker Path chosen yet"
	if is_instance_valid(tinker_panel):
		tinker_panel.visible = _open
	_wire_focus()
	return true


## Detached copy of the presented Tinker options, in authored order.
func tinker_path_options() -> Array:
	return _tinker_options.duplicate(true)


## The Tinker Path this setup has actually confirmed, or "" before a valid pick.
func selected_tinker_path_id() -> String:
	return _selected_tinker_id


func selected_tinker_path_name() -> String:
	return _selected_tinker_name


## Host confirmation of a validated Tinker pick. The other Tinker option can no
## longer be chosen, and the Seamstress board is left exactly as it was.
func mark_tinker_path_selected(path_id: String, display_name: String) -> bool:
	if not _open or _set_out_pending or _back_pending:
		return false
	if not _selected_tinker_id.is_empty():
		return false
	if path_id.strip_edges().is_empty() or display_name.strip_edges().is_empty():
		return false
	var chosen := _tinker_path_button(path_id)
	if chosen == null:
		return false
	_selected_tinker_id = path_id
	_selected_tinker_name = display_name
	var card_name := ""
	for option in _tinker_options:
		if String(option.get("id", "")) == path_id:
			card_name = String(option.get("card_name", ""))
	for button in tinker_buttons:
		if not is_instance_valid(button):
			continue
		button.disabled = true
		button.release_focus()
	if is_instance_valid(tinker_hint_label):
		tinker_hint_label.text = "Tinker Path sewn for this run"
	if is_instance_valid(tinker_status_label):
		tinker_status_label.text = "Selected: " + display_name \
			+ (" · card " + card_name if not card_name.is_empty() else "")
		tinker_status_label.show()
	_wire_focus()
	if is_instance_valid(set_out_button):
		_wire_focus()
	set_out_button.grab_focus()
	return true


## Host refusal of a Tinker Path request: keep the offered options actionable. A
## Tinker Path that was already confirmed cannot be released or replaced.
func release_tinker_path_choice() -> bool:
	if not _open or _set_out_pending or _back_pending:
		return false
	if not _selected_tinker_id.is_empty() or _tinker_options.is_empty():
		return false
	for button in tinker_buttons:
		if is_instance_valid(button):
			button.disabled = false
	if is_instance_valid(tinker_hint_label):
		_refresh_tinker_hint()
	_wire_focus()
	return true


## Third, independently offered hero board. Only host-owned identity/name/card
## rows enter this view; neither this method nor a button creates a run receipt.
func present_warden_path_options(options: Variant) -> bool:
	if not options is Array or not is_instance_valid(warden_option_box):
		return false
	if not _selected_warden_id.is_empty() or _warden_pending:
		return false
	var cleaned: Array = []
	var seen: Dictionary = {}
	for raw in options:
		if not raw is Dictionary:
			return false
		var record: Dictionary = raw
		var path_id := String(record.get("id", ""))
		var display_name := String(record.get("display_name", ""))
		if path_id.strip_edges().is_empty() or display_name.strip_edges().is_empty() or seen.has(path_id):
			return false
		seen[path_id] = true
		cleaned.append({"id": path_id, "display_name": display_name,
			"card_name": String(record.get("card_name", ""))})
	if cleaned.is_empty():
		return false
	for button in warden_buttons:
		if is_instance_valid(button):
			warden_option_box.remove_child(button)
			button.queue_free()
	warden_buttons.clear()
	_warden_options = cleaned
	_warden_previews.clear()
	_warden_hover_id = ""
	_warden_focus_id = ""
	_selected_warden_id = ""
	_selected_warden_name = ""
	for option in cleaned:
		var path_id := String(option["id"])
		var button := Button.new()
		button.name = "WardenPathChoice_" + path_id
		button.text = String(option["display_name"])
		button.set_meta("path_id", path_id)
		button.custom_minimum_size = Vector2(0, PATH_OPTION_HEIGHT)
		_sew_path_option_face(button)
		_style_warden_button(button)
		var preview := VillagePathPreview.warden(option)
		var tooltip := "Warden Path: " + String(option["display_name"]) \
			+ (" · card " + String(option["card_name"]) if not String(option["card_name"]).is_empty() else "")
		if not preview.is_empty():
			_warden_previews[path_id] = preview
			tooltip = String(preview["tooltip"])
		button.tooltip_text = tooltip
		# Bind the actual control, not only its ID: an old queued button or
		# callback must never authorize a replacement offer with the same ID.
		button.pressed.connect(_on_warden_path_pressed.bind(path_id, button))
		button.focus_entered.connect(_on_warden_preview_entered.bind(path_id, true))
		button.focus_exited.connect(_on_warden_preview_exited.bind(path_id, true))
		button.mouse_entered.connect(_on_warden_preview_entered.bind(path_id, false))
		button.mouse_exited.connect(_on_warden_preview_exited.bind(path_id, false))
		button.add_child(SewnEdge.new())
		warden_option_box.add_child(button)
		warden_buttons.append(button)
	if is_instance_valid(warden_hint_label):
		warden_hint_label.text = "Choose one Warden Path for this run"
	if is_instance_valid(warden_status_label):
		warden_status_label.text = "No Warden Path chosen yet"
	if is_instance_valid(warden_panel):
		warden_panel.visible = _open
	_wire_focus()
	return true


func warden_path_options() -> Array:
	return _warden_options.duplicate(true)


func selected_warden_path_id() -> String:
	return _selected_warden_id


func selected_warden_path_name() -> String:
	return _selected_warden_name


## A host validates the requested ID; only its explicit approval calls this.
func mark_warden_path_selected(path_id: String, display_name: String) -> bool:
	if not _open or _set_out_pending or _back_pending or not is_visible_in_tree():
		return false
	if not _selected_warden_id.is_empty():
		return false
	var chosen := _warden_path_button(path_id)
	if chosen == null:
		return false
	var card_name := ""
	var matches := false
	for option in _warden_options:
		if String(option.get("id", "")) == path_id and String(option.get("display_name", "")) == display_name:
			matches = true
			card_name = String(option.get("card_name", ""))
	if not matches:
		return false
	_warden_pending = false
	_selected_warden_id = path_id
	_selected_warden_name = display_name
	for button in warden_buttons:
		if is_instance_valid(button):
			button.disabled = true
			button.release_focus()
	if is_instance_valid(warden_hint_label):
		warden_hint_label.text = "Warden Path sewn for this run"
	if is_instance_valid(warden_status_label):
		warden_status_label.text = "Selected: " + display_name \
			+ (" · card " + card_name if not card_name.is_empty() else "")
	_wire_focus()
	if is_instance_valid(set_out_button):
		set_out_button.grab_focus()
	return true


## A refused request restores ONLY Warden's offered controls.
func release_warden_path_choice() -> bool:
	if not _open or _set_out_pending or _back_pending or not is_visible_in_tree():
		return false
	if not _selected_warden_id.is_empty() or _warden_options.is_empty():
		return false
	_warden_pending = false
	for button in warden_buttons:
		if is_instance_valid(button):
			button.disabled = false
	if is_instance_valid(warden_status_label):
		warden_status_label.text = "No Warden Path chosen yet"
	_refresh_warden_hint()
	_wire_focus()
	return true


func _apply_closed_state() -> void:
	_open = false
	_set_out_pending = false
	_back_pending = false
	_path_pending = false
	_tinker_pending = false
	_warden_pending = false
	_selected_warden_id = ""
	_selected_warden_name = ""
	_selected_path_id = ""
	_selected_path_name = ""
	_selected_tinker_id = ""
	_selected_tinker_name = ""
	_path_hover_id = ""
	_path_focus_id = ""
	_tinker_hover_id = ""
	_tinker_focus_id = ""
	_warden_hover_id = ""
	_warden_focus_id = ""
	visible = false
	if is_instance_valid(path_panel):
		path_panel.visible = false
	if is_instance_valid(tinker_panel):
		tinker_panel.visible = false
	if is_instance_valid(warden_panel):
		warden_panel.visible = false
	_refresh_warden_hint()
	_refresh_path_hint()
	_refresh_tinker_hint()
	for button in path_buttons:
		if is_instance_valid(button):
			button.disabled = true
			button.release_focus()
	for button in tinker_buttons:
		if is_instance_valid(button):
			button.disabled = true
			button.release_focus()
	for button in warden_buttons:
		if is_instance_valid(button):
			button.disabled = true
			button.release_focus()
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
	for button in path_buttons:
		if is_instance_valid(button):
			button.disabled = not _selected_path_id.is_empty()
	for button in tinker_buttons:
		if is_instance_valid(button):
			button.disabled = not _selected_tinker_id.is_empty()
	for button in warden_buttons:
		if is_instance_valid(button):
			button.disabled = _warden_pending or not _selected_warden_id.is_empty()
	_wire_focus()
	_wire_focus()
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
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.tooltip_text = "Return to the title"
	back_button.pressed.connect(_on_back_pressed)
	back_button.add_child(SewnEdge.new())
	row.add_child(back_button)

	village_title_label = Label.new()
	village_title_label.name = "VillageTitle"
	village_title_label.text = "Quilt village"
	# The master Theme's display title face, at a size the compact strip can carry.
	village_title_label.theme_type_variation = &"PatchTitle"
	village_title_label.add_theme_color_override("font_color", INK)
	village_title_label.add_theme_font_size_override("font_size", TITLE_SIZE)
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


## Pinned Heroes board under its house: the two authored Path options and the
## one pick this run carries. Hidden until the host presents real options.
func _build_heroes_choice() -> void:
	var panel := PanelContainer.new()
	panel.name = "HeroesChoice"
	path_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = HEROES_PANEL_RECT.position
	panel.custom_minimum_size = HEROES_PANEL_RECT.size
	panel.size = HEROES_PANEL_RECT.size
	var paper := StyleBoxFlat.new()
	paper.bg_color = PIN_PAPER
	paper.border_color = Color("#766351")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 14.0
	paper.content_margin_right = 14.0
	paper.content_margin_top = 8.0
	paper.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", paper)
	panel.visible = false
	add_child(panel)

	var column := VBoxContainer.new()
	column.name = "HeroesColumn"
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var heading := Label.new()
	heading.name = "HeroesHeading"
	heading.text = "Heroes · Seamstress Path"
	heading.theme_type_variation = &"PatchHeading"
	heading.add_theme_color_override("font_color", INK)
	heading.add_theme_font_size_override("font_size", PATH_HEADING_SIZE)
	column.add_child(heading)

	path_hint_label = Label.new()
	path_hint_label.name = "PathHint"
	path_hint_label.text = "Choose one Path for this run"
	path_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_hint_label.add_theme_color_override("font_color", Color("#4a4438"))
	path_hint_label.add_theme_font_size_override("font_size", HINT_SIZE)
	column.add_child(path_hint_label)

	path_option_box = VBoxContainer.new()
	path_option_box.name = "PathOptions"
	path_option_box.add_theme_constant_override("separation", 4)
	column.add_child(path_option_box)

	path_status_label = Label.new()
	path_status_label.name = "PathStatus"
	path_status_label.text = "No Path chosen yet"
	path_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The confirmed line sits on the board's lower edge, level with its siblings.
	path_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	path_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	path_status_label.add_theme_color_override("font_color", Color("#33502f"))
	path_status_label.add_theme_font_size_override("font_size", STATUS_SIZE)
	column.add_child(path_status_label)


## The Tinker's own pinned board beside the Heroes one: the two authored Tinker
## Paths and the one pick this run carries. Hidden until the host presents real
## Tinker options, so a host that offers none leaves the village unchanged.
func _build_tinker_choice() -> void:
	var panel := PanelContainer.new()
	panel.name = "TinkerChoice"
	tinker_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = TINKER_PANEL_RECT.position
	panel.custom_minimum_size = TINKER_PANEL_RECT.size
	panel.size = TINKER_PANEL_RECT.size
	var paper := StyleBoxFlat.new()
	paper.bg_color = PIN_PAPER
	paper.border_color = Color("#766351")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 14.0
	paper.content_margin_right = 14.0
	paper.content_margin_top = 8.0
	paper.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", paper)
	panel.visible = false
	add_child(panel)

	var column := VBoxContainer.new()
	column.name = "TinkerColumn"
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var heading := Label.new()
	heading.name = "TinkerHeading"
	heading.text = "Heroes · Tinker Path"
	heading.theme_type_variation = &"PatchHeading"
	heading.add_theme_color_override("font_color", INK)
	heading.add_theme_font_size_override("font_size", PATH_HEADING_SIZE)
	column.add_child(heading)

	tinker_hint_label = Label.new()
	tinker_hint_label.name = "TinkerPathHint"
	tinker_hint_label.text = "Choose one Tinker Path for this run"
	tinker_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tinker_hint_label.add_theme_color_override("font_color", Color("#4a4438"))
	tinker_hint_label.add_theme_font_size_override("font_size", HINT_SIZE)
	column.add_child(tinker_hint_label)

	tinker_option_box = VBoxContainer.new()
	tinker_option_box.name = "TinkerPathOptions"
	tinker_option_box.add_theme_constant_override("separation", 4)
	column.add_child(tinker_option_box)

	tinker_status_label = Label.new()
	tinker_status_label.name = "TinkerPathStatus"
	tinker_status_label.text = "No Tinker Path chosen yet"
	tinker_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tinker_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tinker_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tinker_status_label.add_theme_color_override("font_color", Color("#33502f"))
	tinker_status_label.add_theme_font_size_override("font_size", STATUS_SIZE)
	column.add_child(tinker_status_label)


## Warden's own patch, 24 px after Tinker and above the Set out row.
## Compact one-line hints leave the detailed passive/card text in tooltips.
func _build_warden_choice() -> void:
	var panel := PanelContainer.new()
	panel.name = "WardenChoice"
	warden_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = WARDEN_PANEL_RECT.position
	panel.custom_minimum_size = WARDEN_PANEL_RECT.size
	panel.size = WARDEN_PANEL_RECT.size
	var paper := StyleBoxFlat.new()
	paper.bg_color = PIN_PAPER
	paper.border_color = WARDEN_SLATE
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 14.0
	paper.content_margin_right = 14.0
	paper.content_margin_top = 8.0
	paper.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", paper)
	panel.visible = false
	add_child(panel)

	var column := VBoxContainer.new()
	column.name = "WardenColumn"
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var heading := Label.new()
	heading.name = "WardenHeading"
	heading.text = "Heroes · Warden Path"
	heading.theme_type_variation = &"PatchHeading"
	heading.add_theme_color_override("font_color", INK)
	heading.add_theme_font_size_override("font_size", PATH_HEADING_SIZE)
	column.add_child(heading)

	warden_hint_label = Label.new()
	warden_hint_label.name = "WardenPathHint"
	warden_hint_label.text = "Choose one Warden Path for this run"
	# The authored preview hint is the full sentence: wrap it inside the paper
	# board instead of clipping it away behind the option buttons.
	warden_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warden_hint_label.add_theme_color_override("font_color", WARDEN_INK)
	warden_hint_label.add_theme_font_size_override("font_size", HINT_SIZE)
	column.add_child(warden_hint_label)

	warden_option_box = VBoxContainer.new()
	warden_option_box.name = "WardenPathOptions"
	warden_option_box.add_theme_constant_override("separation", 4)
	column.add_child(warden_option_box)

	warden_status_label = Label.new()
	warden_status_label.name = "WardenPathStatus"
	warden_status_label.text = "No Warden Path chosen yet"
	warden_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warden_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	warden_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	warden_status_label.add_theme_color_override("font_color", WARDEN_INK)
	warden_status_label.add_theme_font_size_override("font_size", STATUS_SIZE)
	column.add_child(warden_status_label)


## All three Path boards share one sewn option face: the master Theme's
## PatchHeadingButton (Londrina Solid Regular) at the 18 px body floor. Only the
## caption face changes; each option keeps its authored name, hint, tooltip and
## signal, and Warden keeps its own bone/slate/rust surfaces.
func _sew_path_option_face(button: Button) -> void:
	button.theme_type_variation = &"PatchHeadingButton"
	button.add_theme_font_size_override("font_size", PATH_OPTION_SIZE)


## Light bone felt / dark slate ink in ALL button states (including focus).
func _style_warden_button(button: Button) -> void:
	var surface := StyleBoxFlat.new()
	surface.bg_color = WARDEN_BONE
	surface.border_color = WARDEN_RUST
	surface.set_border_width_all(2)
	surface.set_corner_radius_all(5)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var state_surface := surface.duplicate() as StyleBoxFlat
		if state == "hover" or state == "hover_pressed":
			state_surface.bg_color = Color("#efe3c9")
		elif state == "pressed":
			state_surface.bg_color = Color("#c4b595")
		elif state == "disabled":
			state_surface.bg_color = Color("#d4cdbb")
		button.add_theme_stylebox_override(state, state_surface)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)
	var focused := StyleBoxFlat.new()
	focused.bg_color = Color.TRANSPARENT
	focused.border_color = WARDEN_SLATE
	focused.set_border_width_all(3)
	focused.set_corner_radius_all(5)
	button.add_theme_stylebox_override("focus", focused)


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
	# The master Theme's display heading face, still far above the 18 px body floor.
	set_out_button.theme_type_variation = &"PatchHeadingButton"
	set_out_button.add_theme_font_size_override("font_size", 30)
	set_out_button.tooltip_text = "Choose this run's opening route"
	set_out_button.pressed.connect(_on_set_out_pressed)
	set_out_button.add_child(SewnEdge.new())
	row.add_child(set_out_button)


## Every live sewn action forms one forward/reverse Tab loop: Back, both authored
## Path options, both authored Tinker options (while still choosable), then Set out.
func _wire_focus() -> void:
	var loop: Array[Control] = []
	if is_instance_valid(back_button) and not back_button.disabled:
		loop.append(back_button)
	for button in path_buttons:
		if is_instance_valid(button) and not button.disabled:
			loop.append(button)
	for button in tinker_buttons:
		if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
			loop.append(button)
	for button in warden_buttons:
		if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
			loop.append(button)
	if is_instance_valid(set_out_button) and not set_out_button.disabled:
		loop.append(set_out_button)
	if loop.is_empty():
		return
	for index in range(loop.size()):
		var node := loop[index]
		node.focus_next = node.get_path_to(loop[(index + 1) % loop.size()])
		node.focus_previous = node.get_path_to(loop[(index - 1 + loop.size()) % loop.size()])


func _path_button(path_id: String) -> Button:
	for button in path_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


func _warden_path_button(path_id: String) -> Button:
	for button in warden_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


func _tinker_path_button(path_id: String) -> Button:
	for button in tinker_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


## Hover and keyboard focus preview exactly the authored record the button stands
## for: the PASSIVE and its one CARD, as formatted by VillagePathPreview. This
## reads no run, deck, currency or RNG state, claims no Path and emits no signal.
func _on_path_preview_entered(path_id: String, from_focus: bool) -> void:
	if from_focus:
		_path_focus_id = path_id
	else:
		_path_hover_id = path_id
	_refresh_path_hint()


## Leaving a preview restores the board's own prompt. Once the host has confirmed
## a Path the selection stays stated, so a late or stale exit resets nothing.
func _on_path_preview_exited(path_id: String, from_focus: bool) -> void:
	if from_focus:
		if _path_focus_id == path_id:
			_path_focus_id = ""
	elif _path_hover_id == path_id:
		_path_hover_id = ""
	_refresh_path_hint()


func _refresh_path_hint() -> void:
	if not is_instance_valid(path_hint_label):
		return
	if not _selected_path_id.is_empty():
		path_hint_label.text = "Path sewn for this run"
		return
	path_hint_label.text = "Choose one Path for this run"
	var active := _path_focus_id if not _path_focus_id.is_empty() else _path_hover_id
	if active.is_empty():
		return
	var preview: Variant = _path_previews.get(active, {})
	if preview is Dictionary:
		var hint := String((preview as Dictionary).get("hint", ""))
		if not hint.is_empty():
			path_hint_label.text = hint


func _on_tinker_preview_entered(path_id: String, from_focus: bool) -> void:
	if from_focus:
		_tinker_focus_id = path_id
	else:
		_tinker_hover_id = path_id
	_refresh_tinker_hint()


func _on_tinker_preview_exited(path_id: String, from_focus: bool) -> void:
	if from_focus:
		if _tinker_focus_id == path_id:
			_tinker_focus_id = ""
	elif _tinker_hover_id == path_id:
		_tinker_hover_id = ""
	_refresh_tinker_hint()


func _refresh_tinker_hint() -> void:
	if not is_instance_valid(tinker_hint_label):
		return
	if not _selected_tinker_id.is_empty():
		tinker_hint_label.text = "Tinker Path sewn for this run"
		return
	tinker_hint_label.text = "Choose one Tinker Path for this run"
	var active := _tinker_focus_id if not _tinker_focus_id.is_empty() else _tinker_hover_id
	if active.is_empty():
		return
	var preview: Variant = _tinker_previews.get(active, {})
	if preview is Dictionary:
		var hint := String((preview as Dictionary).get("hint", ""))
		if not hint.is_empty():
			tinker_hint_label.text = hint


## The view reports the pick; the host validates it and, only on success, calls
## mark_path_selected. A refused request leaves both options actionable.
func _on_path_pressed(path_id: String) -> void:
	if not _open or _path_pending or _set_out_pending or _back_pending:
		return
	if not _selected_path_id.is_empty():
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var button := _path_button(path_id)
	if button == null or button.disabled:
		return
	_path_pending = true
	path_choice_requested.emit(path_id)
	_path_pending = false


## The Tinker board reports its own pick. The host validates it against the
## authored Tinker record and, only on success, calls mark_tinker_path_selected.
func _on_tinker_path_pressed(path_id: String) -> void:
	if not _open or _tinker_pending or _set_out_pending or _back_pending:
		return
	if not _selected_tinker_id.is_empty():
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var button := _tinker_path_button(path_id)
	if button == null or button.disabled:
		return
	_tinker_pending = true
	tinker_path_choice_requested.emit(path_id)
	_tinker_pending = false


func _on_warden_preview_entered(path_id: String, from_focus: bool) -> void:
	if from_focus:
		_warden_focus_id = path_id
	else:
		_warden_hover_id = path_id
	_refresh_warden_hint()


func _on_warden_preview_exited(path_id: String, from_focus: bool) -> void:
	if from_focus:
		if _warden_focus_id == path_id:
			_warden_focus_id = ""
	elif _warden_hover_id == path_id:
		_warden_hover_id = ""
	_refresh_warden_hint()


func _refresh_warden_hint() -> void:
	if not is_instance_valid(warden_hint_label):
		return
	if not _selected_warden_id.is_empty():
		warden_hint_label.text = "Warden Path sewn for this run"
		return
	warden_hint_label.text = "Choose one Warden Path for this run"
	var active := _warden_focus_id if not _warden_focus_id.is_empty() else _warden_hover_id
	var preview: Variant = _warden_previews.get(active, {})
	if preview is Dictionary:
		var hint := String((preview as Dictionary).get("hint", ""))
		if not hint.is_empty():
			warden_hint_label.text = hint


## A press requests validation, never chooses a path or changes live state.
## Pending remains held until explicit host mark or release (unlike the older
## synchronous Seamstress/Tinker callbacks); stale button instances fail closed.
func _on_warden_path_pressed(path_id: String, source: Button) -> void:
	if not _open or _warden_pending or _set_out_pending or _back_pending:
		return
	if not _selected_warden_id.is_empty() or not is_inside_tree() or not is_visible_in_tree():
		return
	if not is_instance_valid(warden_panel) or not warden_panel.is_visible_in_tree():
		return
	if not is_instance_valid(source) or source != _warden_path_button(path_id) or source.disabled:
		return
	_warden_pending = true
	for button in warden_buttons:
		if is_instance_valid(button):
			button.disabled = true
	if is_instance_valid(warden_status_label):
		warden_status_label.text = "Waiting for Warden Path approval"
	_wire_focus()
	warden_path_choice_requested.emit(path_id)


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
