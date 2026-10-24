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
## The optional authored picture for a stitch half: cards/art/<base_id>.png,
## with only a final "_plus" sharing its base card's illustration.
const ART_DIR := "res://assets/paper/cards/art/"
const FIRST_THUMB_RECT := Rect2(532, 43, 100, 70)
const SECOND_THUMB_RECT := Rect2(532, 119, 100, 70)

var first_selector: OptionButton
var second_selector: OptionButton
var confirm_button: Button
var summary_label: Label
var step_label: Label
var first_half_label: Label
var second_half_label: Label
var consequence_label: Label
var first_thumbnail: TextureRect
var second_thumbnail: TextureRect

var first_tile_scroll: ScrollContainer
var first_tile_container: HBoxContainer
var second_tile_scroll: ScrollContainer
var second_tile_container: HBoxContainer
var change_first_button: Button
var first_tiles: Array[Button] = []
var second_tiles: Array[Button] = []

var _selected_first_index: int = -1
var _selected_second_index: int = -1
var _first_thumb: Dictionary = {}
var _second_thumb: Dictionary = {}
var _left_edge: ColorRect
var _right_edge: ColorRect
var _model := RunRestStitchPairOptions.new()
var _epoch := 0
var _submitted := false
var _first_callback: Callable
var _second_callback: Callable
var _confirm_callback: Callable


func _ready() -> void:
	# Binding before mounting is supported too: retain the detached receipt
	# while constructing controls, then connect this UI session normally.
	var early_service: RunRestStitchCards = _model._service
	var early_source: Dictionary = _model._source.duplicate(true)
	custom_minimum_size = Vector2(710, 500)
	if size.x < 710 or size.y < 500:
		size = Vector2(710, 500)
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
	_left_edge.size = Vector2(8, 486)
	_left_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_edge)
	_right_edge = ColorRect.new()
	_right_edge.color = OWNER_COLORS["tinker"]
	_right_edge.position = Vector2(695, 7)
	_right_edge.size = Vector2(8, 486)
	_right_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right_edge)
	# Tiny cream thread dashes on both owner-coloured felt seams.
	for y in range(15, 489, 17):
		for x in [9, 697]:
			var thread := ColorRect.new()
			thread.color = Color("#f9edd2")
			thread.position = Vector2(x, y)
			thread.size = Vector2(4, 3)
			thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(thread)

	var title := Label.new()
	title.text = "REST • STITCH TWO ORIGINAL CARDS"
	title.position = Vector2(27, 12)
	title.size = Vector2(650, 24)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	step_label = Label.new()
	step_label.text = "Step 1: Choose first original card (3 scraps)"
	step_label.position = Vector2(30, 36)
	step_label.size = Vector2(650, 18)
	step_label.add_theme_color_override("font_color", Color("#4a5d73"))
	step_label.add_theme_font_size_override("font_size", 13)
	step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(step_label)

	# Illustrated sewn-card tile surfaces
	first_tile_scroll = ScrollContainer.new()
	first_tile_scroll.name = "FirstTileScroll"
	first_tile_scroll.position = Vector2(30, 56)
	first_tile_scroll.size = Vector2(650, 114)
	first_tile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	first_tile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	first_tile_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(first_tile_scroll)

	first_tile_container = HBoxContainer.new()
	first_tile_container.name = "FirstTileContainer"
	first_tile_container.add_theme_constant_override("separation", 8)
	first_tile_scroll.add_child(first_tile_container)

	second_tile_scroll = ScrollContainer.new()
	second_tile_scroll.name = "SecondTileScroll"
	second_tile_scroll.position = Vector2(30, 56)
	second_tile_scroll.size = Vector2(650, 114)
	second_tile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	second_tile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	second_tile_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	second_tile_scroll.visible = false
	add_child(second_tile_scroll)

	second_tile_container = HBoxContainer.new()
	second_tile_container.name = "SecondTileContainer"
	second_tile_container.add_theme_constant_override("separation", 8)
	second_tile_scroll.add_child(second_tile_container)

	# Legacy dropdown selectors kept synchronized for existing contracts/tests.
	# Outside the normal visible Tab loop so they do not steal keyboard focus from real tiles.
	first_selector = _option(Vector2(30, 60), "Choose first original card")
	second_selector = _option(Vector2(30, 117), "Choose other-hero card")
	first_selector.modulate = Color(1, 1, 1, 0)
	second_selector.modulate = Color(1, 1, 1, 0)
	first_selector.focus_mode = Control.FOCUS_ALL
	second_selector.focus_mode = Control.FOCUS_ALL
	first_selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	second_selector.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_panel := Panel.new()
	preview_panel.position = Vector2(30, 174)
	preview_panel.size = Vector2(650, 248)
	var inset := StyleBoxFlat.new()
	inset.bg_color = Color("#fff8e9")
	inset.border_color = Color("#968c7e")
	inset.set_border_width_all(2)
	inset.set_corner_radius_all(3)
	preview_panel.add_theme_stylebox_override("panel", inset)
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_panel)
	summary_label = Label.new()
	summary_label.position = Vector2(14, 8)
	summary_label.size = Vector2(622, 31)
	summary_label.add_theme_color_override("font_color", INK)
	summary_label.add_theme_font_size_override("font_size", 18)
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(summary_label)
	first_half_label = _detail_label(preview_panel, Vector2(14, 41))
	second_half_label = _detail_label(preview_panel, Vector2(14, 117))
	consequence_label = Label.new()
	consequence_label.position = Vector2(14, 194)
	consequence_label.size = Vector2(622, 52)
	consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	consequence_label.add_theme_color_override("font_color", INK)
	consequence_label.add_theme_font_size_override("font_size", 14)
	consequence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(consequence_label)
	_first_thumb = _thumbnail_surface(preview_panel, FIRST_THUMB_RECT)
	_second_thumb = _thumbnail_surface(preview_panel, SECOND_THUMB_RECT)
	first_thumbnail = _first_thumb["picture"]
	second_thumbnail = _second_thumb["picture"]
	_clear_thumbnails()

	confirm_button = Button.new()
	confirm_button.text = "Confirm Stitch • 3 scraps"
	confirm_button.position = Vector2(30, 440)
	confirm_button.size = Vector2(650, 44)
	confirm_button.focus_mode = Control.FOCUS_ALL
	add_child(confirm_button)
	first_selector.focus_next = first_selector.get_path_to(second_selector)
	second_selector.focus_next = second_selector.get_path_to(confirm_button)
	if early_service != null:
		bind(early_service, early_source)
	else:
		clear()


func _option(at: Vector2, placeholder: String) -> OptionButton:
	var result := OptionButton.new()
	result.position = at
	result.size = Vector2(650, 45)
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", 17)
	result.add_theme_color_override("font_color", INK)
	result.add_item(placeholder)
	result.set_item_disabled(0, true)
	result.select(-1)
	add_child(result)
	return result


## A small inert illustration surface for one stitch half.
func _thumbnail_surface(parent: Control, at: Rect2) -> Dictionary:
	var backing := Panel.new()
	backing.position = at.position
	backing.size = at.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)
	var name_label := Label.new()
	name_label.position = Vector2(4, 4)
	name_label.size = at.size - Vector2(8, 8)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color("#fdf6e5"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.add_child(name_label)
	var picture := TextureRect.new()
	picture.position = at.position
	picture.size = at.size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return {"backing": backing, "label": name_label, "picture": picture}


## Presentation-only lookup; only a final "_plus" reuses its base card's image.
static func art_path(card_id: String) -> String:
	return ART_DIR + "%s.png" % card_id.trim_suffix("_plus")


static func _texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _show_thumbnail(state: Dictionary, half: Dictionary) -> void:
	var card_id: String = str(half.get("id", ""))
	var owner: String = str(half.get("owner", ""))
	var backing: Panel = state["backing"]
	var style := StyleBoxFlat.new()
	style.bg_color = OWNER_COLORS.get(owner, INK)
	style.border_color = Color("#f9edd2")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	backing.add_theme_stylebox_override("panel", style)
	backing.visible = true
	var picture: TextureRect = state["picture"]
	picture.texture = _texture(art_path(card_id))
	picture.visible = picture.texture != null
	var label: Label = state["label"]
	label.text = str(half.get("display_name", card_id))
	label.visible = not picture.visible


func _clear_thumbnails() -> void:
	for state in [_first_thumb, _second_thumb]:
		if state.is_empty():
			continue
		var picture: TextureRect = state["picture"]
		picture.texture = null
		picture.visible = false
		var backing: Panel = state["backing"]
		backing.visible = false
		var label: Label = state["label"]
		label.text = ""
		label.visible = false


## Public read-only view of one half's mounted illustration (tests and audits).
func thumbnail_state(which: String) -> Dictionary:
	var state: Dictionary = _first_thumb if which == "first" else _second_thumb
	if state.is_empty():
		return {}
	var picture: TextureRect = state["picture"]
	var backing: Panel = state["backing"]
	var label: Label = state["label"]
	var texture := picture.texture
	var style := backing.get_theme_stylebox("panel") as StyleBoxFlat
	return {
		"visible": picture.visible and picture.is_visible_in_tree(),
		"placeholder_visible": backing.visible and label.visible and not picture.visible,
		"path": texture.resource_path if texture != null else "",
		"texture": texture,
		"owner_color": style.bg_color if style != null else Color.TRANSPARENT,
		"name": label.text,
	}


func _detail_label(parent: Control, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(512, 75)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# --- Illustrated Sewn-Card Tile Construction ---

func _style_tile_button(tile: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = CREAM
	normal.border_color = INK
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	tile.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#fffdf8")
	hover.border_color = Color("#c49a3a")
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(5)
	tile.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("#ebdcc0")
	pressed.border_color = INK
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(5)
	tile.add_theme_stylebox_override("pressed", pressed)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color("#fffdf8")
	focus.border_color = Color("#2e5b88")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(5)
	tile.add_theme_stylebox_override("focus", focus)


func _mark_tile_selected(tile: Button, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color("#fff8e5")
		style.border_color = Color("#c49a3a")
		style.set_border_width_all(3)
		style.set_corner_radius_all(5)
	else:
		style.bg_color = CREAM
		style.border_color = INK
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
	tile.add_theme_stylebox_override("normal", style)


func _create_card_tile(entry: Dictionary, is_first: bool) -> Button:
	var tile := Button.new()
	tile.name = ("FirstTile_%d" if is_first else "SecondTile_%d") % entry["index"]
	tile.custom_minimum_size = Vector2(96, 106)
	tile.size = Vector2(96, 106)
	tile.focus_mode = Control.FOCUS_ALL
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.set_meta("index", entry["index"])
	tile.set_meta("id", entry["id"])
	tile.set_meta("owner", entry["owner"])
	tile.set_meta("name", entry["name"])
	tile.set_meta("cost", entry["cost"])

	_style_tile_button(tile)

	var scroll: ScrollContainer = first_tile_scroll if is_first else second_tile_scroll
	tile.focus_entered.connect(_on_tile_focus_entered.bind(tile, scroll))

	# Owner cloth stripe with hero name
	var owner_str: String = str(entry["owner"])
	var owner_col: Color = OWNER_COLORS.get(owner_str, INK)
	var stripe := Panel.new()
	stripe.position = Vector2(3, 3)
	stripe.size = Vector2(90, 16)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stripe_box := StyleBoxFlat.new()
	stripe_box.bg_color = owner_col
	stripe_box.corner_radius_top_left = 3
	stripe_box.corner_radius_top_right = 3
	stripe.add_theme_stylebox_override("panel", stripe_box)
	tile.add_child(stripe)

	var stripe_label := Label.new()
	stripe_label.position = Vector2(2, 0)
	stripe_label.size = Vector2(86, 16)
	stripe_label.text = "#%d %s" % [entry["index"], owner_str.capitalize()]
	stripe_label.add_theme_font_size_override("font_size", 10)
	stripe_label.add_theme_color_override("font_color", Color("#fdf6e5"))
	stripe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stripe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stripe_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.add_child(stripe_label)

	# Illustration window / fallback
	var art_window := Panel.new()
	art_window.position = Vector2(5, 21)
	art_window.size = Vector2(86, 38)
	art_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_box := StyleBoxFlat.new()
	art_box.bg_color = owner_col.darkened(0.2)
	art_box.border_color = Color("#f9edd2")
	art_box.set_border_width_all(1)
	art_box.set_corner_radius_all(2)
	art_window.add_theme_stylebox_override("panel", art_box)
	tile.add_child(art_window)

	var tex := _texture(art_path(entry["id"]))
	if tex != null:
		var pic := TextureRect.new()
		pic.position = Vector2(0, 0)
		pic.size = Vector2(86, 38)
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_window.add_child(pic)
	else:
		var fallback := Label.new()
		fallback.position = Vector2(2, 2)
		fallback.size = Vector2(82, 34)
		fallback.text = entry["name"]
		fallback.add_theme_font_size_override("font_size", 10)
		fallback.add_theme_color_override("font_color", Color("#fdf6e5"))
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_window.add_child(fallback)

	# Friendly authored name
	var name_lbl := Label.new()
	name_lbl.position = Vector2(3, 61)
	name_lbl.size = Vector2(90, 22)
	name_lbl.text = entry["name"]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", INK)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_lbl)

	# Round sewn cost button
	var cost_badge := Panel.new()
	cost_badge.position = Vector2(36, 84)
	cost_badge.size = Vector2(24, 18)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_box := StyleBoxFlat.new()
	cost_box.bg_color = Color("#c49a3a")
	cost_box.border_color = INK
	cost_box.set_border_width_all(1)
	cost_box.set_corner_radius_all(9)
	cost_badge.add_theme_stylebox_override("panel", cost_box)
	tile.add_child(cost_badge)

	var cost_lbl := Label.new()
	cost_lbl.position = Vector2(0, 0)
	cost_lbl.size = Vector2(24, 18)
	cost_lbl.text = str(entry["cost"])
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", INK)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_child(cost_lbl)

	return tile


func _create_change_first_button(first_idx: int) -> Button:
	var btn := Button.new()
	btn.name = "ChangeFirstButton"
	btn.custom_minimum_size = Vector2(96, 106)
	btn.size = Vector2(96, 106)
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var first_name := ""
	for entry in _model.first_options():
		if entry["index"] == first_idx:
			first_name = entry["name"]
			break
	btn.text = "← Change\nFirst Card\n(#%d %s)" % [first_idx, first_name]
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", INK)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#ebdcc0")
	normal.border_color = INK
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#f4e9d1")
	hover.border_color = Color("#c49a3a")
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("hover", hover)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color("#f4e9d1")
	focus.border_color = Color("#2e5b88")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("focus", focus)

	btn.pressed.connect(_return_to_first_choice)
	return btn


func _on_tile_focus_entered(tile: Button, scroll: ScrollContainer) -> void:
	if is_instance_valid(tile) and is_instance_valid(scroll):
		scroll.ensure_control_visible(tile)


# --- Public Selection Query and Interaction Helpers ---

func is_submitted() -> bool:
	return _submitted


func selected_first_index() -> int:
	return _selected_first_index


func selected_second_index() -> int:
	return _selected_second_index


func first_tile_for_index(deck_index: int) -> Button:
	for tile in first_tiles:
		if is_instance_valid(tile) and tile.get_meta("index") == deck_index:
			return tile
	return null


func second_tile_for_index(deck_index: int) -> Button:
	for tile in second_tiles:
		if is_instance_valid(tile) and tile.get_meta("index") == deck_index:
			return tile
	return null


func select_first_tile(deck_index: int) -> void:
	if _submitted:
		return
	var tile := first_tile_for_index(deck_index)
	if tile != null and not tile.disabled:
		tile.pressed.emit()
	elif _model.is_available():
		_on_first_tile_pressed(deck_index)


func select_second_tile(deck_index: int) -> void:
	if _submitted:
		return
	var tile := second_tile_for_index(deck_index)
	if tile != null and not tile.disabled:
		tile.pressed.emit()
	elif _model.is_available() and _selected_first_index >= 0:
		_on_second_tile_pressed(deck_index)


# --- Rebuilding Navigation Focus Chain ---

func _rebuild_focus_chain() -> void:
	var dismiss: Button = null
	if get_parent() != null:
		dismiss = get_parent().get_node_or_null("DismissStitch") as Button

	if _submitted:
		if first_selector != null:
			first_selector.disabled = true
			first_selector.focus_mode = Control.FOCUS_NONE
		if second_selector != null:
			second_selector.disabled = true
			second_selector.focus_mode = Control.FOCUS_NONE
		if confirm_button != null:
			confirm_button.disabled = true
			confirm_button.focus_mode = Control.FOCUS_NONE
		for tile in first_tiles:
			if is_instance_valid(tile):
				tile.disabled = true
				tile.focus_mode = Control.FOCUS_NONE
		for tile in second_tiles:
			if is_instance_valid(tile):
				tile.disabled = true
				tile.focus_mode = Control.FOCUS_NONE
		if is_instance_valid(change_first_button):
			change_first_button.disabled = true
			change_first_button.focus_mode = Control.FOCUS_NONE
		if dismiss != null:
			dismiss.focus_next = dismiss.get_path_to(dismiss)
			dismiss.focus_previous = dismiss.get_path_to(dismiss)
		return

	first_selector.focus_mode = Control.FOCUS_ALL
	second_selector.focus_mode = Control.FOCUS_ALL
	first_selector.focus_next = first_selector.get_path_to(second_selector)
	second_selector.focus_next = second_selector.get_path_to(confirm_button)

	if first_tile_scroll.visible:
		var active: Array[Button] = []
		for tile in first_tiles:
			if is_instance_valid(tile) and tile.is_inside_tree() and tile.visible and not tile.disabled:
				active.append(tile)
		if active.is_empty():
			if dismiss != null:
				dismiss.focus_next = dismiss.get_path_to(dismiss)
				dismiss.focus_previous = dismiss.get_path_to(dismiss)
			return
		for i in range(active.size()):
			active[i].focus_mode = Control.FOCUS_ALL
			if i > 0:
				active[i].focus_previous = active[i].get_path_to(active[i - 1])
				active[i].focus_neighbor_left = active[i].get_path_to(active[i - 1])
			if i < active.size() - 1:
				active[i].focus_next = active[i].get_path_to(active[i + 1])
				active[i].focus_neighbor_right = active[i].get_path_to(active[i + 1])
		if dismiss != null:
			dismiss.focus_next = dismiss.get_path_to(active.front())
			active.front().focus_previous = active.front().get_path_to(dismiss)
			active.back().focus_next = active.back().get_path_to(dismiss)
			dismiss.focus_previous = dismiss.get_path_to(active.back())
	elif second_tile_scroll.visible:
		var has_confirm: bool = is_instance_valid(confirm_button) and confirm_button.visible and not confirm_button.disabled
		if has_confirm:
			confirm_button.focus_mode = Control.FOCUS_ALL
		if is_instance_valid(change_first_button) and change_first_button.visible:
			change_first_button.focus_mode = Control.FOCUS_ALL

		var active_tiles: Array[Button] = []
		for tile in second_tiles:
			if is_instance_valid(tile) and tile.is_inside_tree() and tile.visible and not tile.disabled:
				tile.focus_mode = Control.FOCUS_ALL
				active_tiles.append(tile)

		for i in range(active_tiles.size()):
			if i > 0:
				active_tiles[i].focus_neighbor_left = active_tiles[i].get_path_to(active_tiles[i - 1])
				active_tiles[i].focus_previous = active_tiles[i].get_path_to(active_tiles[i - 1])
			elif is_instance_valid(change_first_button) and change_first_button.visible:
				active_tiles[i].focus_neighbor_left = active_tiles[i].get_path_to(change_first_button)
				active_tiles[i].focus_previous = active_tiles[i].get_path_to(change_first_button)

			if i < active_tiles.size() - 1:
				active_tiles[i].focus_neighbor_right = active_tiles[i].get_path_to(active_tiles[i + 1])

			if has_confirm:
				active_tiles[i].focus_next = active_tiles[i].get_path_to(confirm_button)
				active_tiles[i].focus_neighbor_bottom = active_tiles[i].get_path_to(confirm_button)
			elif i < active_tiles.size() - 1:
				active_tiles[i].focus_next = active_tiles[i].get_path_to(active_tiles[i + 1])
			elif dismiss != null:
				active_tiles[i].focus_next = active_tiles[i].get_path_to(dismiss)

		if is_instance_valid(change_first_button) and change_first_button.visible:
			if not active_tiles.is_empty():
				change_first_button.focus_next = change_first_button.get_path_to(active_tiles.front())
				change_first_button.focus_neighbor_right = change_first_button.get_path_to(active_tiles.front())
			if dismiss != null:
				change_first_button.focus_previous = change_first_button.get_path_to(dismiss)
				change_first_button.focus_neighbor_left = change_first_button.get_path_to(dismiss)

		if has_confirm:
			var sel_tile: Button = second_tile_for_index(_selected_second_index)
			var target_tile: Button = sel_tile if sel_tile != null else (active_tiles.front() if not active_tiles.is_empty() else null)
			if target_tile != null:
				confirm_button.focus_previous = confirm_button.get_path_to(target_tile)
				confirm_button.focus_neighbor_top = confirm_button.get_path_to(target_tile)
			if dismiss != null:
				confirm_button.focus_next = confirm_button.get_path_to(dismiss)
				dismiss.focus_previous = dismiss.get_path_to(confirm_button)
		elif not active_tiles.is_empty() and dismiss != null:
			dismiss.focus_previous = dismiss.get_path_to(active_tiles.back())

		if dismiss != null:
			if is_instance_valid(change_first_button) and change_first_button.visible:
				dismiss.focus_next = dismiss.get_path_to(change_first_button)
			elif not active_tiles.is_empty():
				dismiss.focus_next = dismiss.get_path_to(active_tiles.front())


func _focus_tile(tile: Button) -> void:
	if _submitted:
		return
	if is_instance_valid(tile) and tile.is_inside_tree() and tile.visible and not tile.disabled:
		tile.grab_focus()


# --- Lifecycle and State ---

func bind(service: RunRestStitchCards, source_snapshot: Variant) -> void:
	clear()
	_submitted = false
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
	_submitted = false
	_selected_first_index = -1
	_selected_second_index = -1
	first_tiles.clear()
	second_tiles.clear()
	if first_tile_container != null:
		for child in first_tile_container.get_children():
			child.queue_free()
	if second_tile_container != null:
		for child in second_tile_container.get_children():
			child.queue_free()
	if first_tile_scroll != null:
		first_tile_scroll.visible = true
	if second_tile_scroll != null:
		second_tile_scroll.visible = false
	if step_label != null:
		step_label.text = "Rest Stitch unavailable"
	if first_selector != null:
		first_selector.clear()
		second_selector.clear()
		first_selector.disabled = true
		second_selector.disabled = true
		confirm_button.disabled = true
		summary_label.text = "Not available — choose two originals (3 scraps)."
		first_half_label.text = ""
		second_half_label.text = ""
		consequence_label.text = ""
		_clear_thumbnails()
		_left_edge.color = OWNER_COLORS["warden"]
		_right_edge.color = OWNER_COLORS["tinker"]


func refresh() -> void:
	_selected_first_index = -1
	_selected_second_index = -1
	first_tiles.clear()
	second_tiles.clear()
	if first_tile_container != null:
		for child in first_tile_container.get_children():
			child.queue_free()
	if second_tile_container != null:
		for child in second_tile_container.get_children():
			child.queue_free()
	if first_tile_scroll != null:
		first_tile_scroll.visible = true
	if second_tile_scroll != null:
		second_tile_scroll.visible = false

	if first_selector == null:
		return
	first_selector.clear()
	second_selector.clear()
	first_selector.disabled = true
	second_selector.disabled = true
	confirm_button.disabled = true
	if step_label != null:
		step_label.text = "Stitch requested — awaiting Rest confirmation." if _submitted else "Rest Stitch unavailable"
	summary_label.text = "Stitch requested — awaiting Rest confirmation." if _submitted else "Not available — no eligible pair (3 scraps required)."
	first_half_label.text = ""
	second_half_label.text = ""
	consequence_label.text = ""
	_clear_thumbnails()
	if _submitted or not is_inside_tree() or not _model.is_available():
		return

	for entry in _model.first_options():
		first_selector.add_item(_entry_text(entry))
		first_selector.set_item_metadata(first_selector.item_count - 1, entry["index"])
		var tile := _create_card_tile(entry, true)
		tile.pressed.connect(_on_first_tile_pressed.bind(entry["index"]))
		first_tile_container.add_child(tile)
		first_tiles.append(tile)

	first_selector.select(-1)
	first_selector.disabled = first_selector.item_count == 0
	if step_label != null:
		step_label.text = "Step 1: Choose first original card (3 scraps)"
	summary_label.text = "Choose the first original, then another hero's card • 3 scraps."
	call_deferred("_rebuild_focus_chain")


func _entry_text(entry: Dictionary) -> String:
	return "#%d  %s • %s (%d energy)" % [entry["index"], entry["name"], entry["owner"].capitalize(), entry["cost"]]


# --- Tile and Selector Interaction Handlers ---

func _on_first_tile_pressed(index: int) -> void:
	if _submitted or not _model.is_available() or not is_inside_tree():
		_disable_choice()
		return
	_selected_first_index = index
	_selected_second_index = -1

	# Synchronize legacy first_selector
	for i in range(first_selector.item_count):
		if first_selector.get_item_metadata(i) == index:
			first_selector.select(i)
			break

	_populate_second_options(index)
	call_deferred("_handoff_focus", _epoch, false)


func _populate_second_options(first_idx: int) -> void:
	if _submitted:
		_disable_choice()
		return
	second_selector.clear()
	second_selector.disabled = true
	confirm_button.disabled = true

	for child in second_tile_container.get_children():
		child.queue_free()
	second_tiles.clear()

	change_first_button = _create_change_first_button(first_idx)
	second_tile_container.add_child(change_first_button)

	var seconds := _model.second_options(first_idx)
	for entry in seconds:
		second_selector.add_item(_entry_text(entry))
		second_selector.set_item_metadata(second_selector.item_count - 1, entry["index"])
		var tile := _create_card_tile(entry, false)
		tile.pressed.connect(_on_second_tile_pressed.bind(entry["index"]))
		second_tile_container.add_child(tile)
		second_tiles.append(tile)

	second_selector.select(-1)
	second_selector.disabled = second_selector.item_count == 0

	first_tile_scroll.visible = false
	second_tile_scroll.visible = true

	if step_label != null:
		step_label.text = "Step 2: Choose second card from a different hero • 3 scraps."
	summary_label.text = "Choose the second original from a different hero • 3 scraps."
	first_half_label.text = ""
	second_half_label.text = ""
	consequence_label.text = ""
	_clear_thumbnails()
	_left_edge.color = _color_for_index(first_idx)
	_right_edge.color = OWNER_COLORS["tinker"]

	call_deferred("_rebuild_focus_chain")


func _on_second_tile_pressed(index: int) -> void:
	if _submitted or not _model.is_available() or not is_inside_tree() or _selected_first_index < 0:
		_disable_choice()
		return
	_selected_second_index = index

	# Synchronize legacy second_selector
	for i in range(second_selector.item_count):
		if second_selector.get_item_metadata(i) == index:
			second_selector.select(i)
			break

	for tile in second_tiles:
		_mark_tile_selected(tile, tile.get_meta("index") == index)

	_update_preview()
	call_deferred("_rebuild_focus_chain")


func _return_to_first_choice() -> void:
	if _submitted:
		return
	_selected_first_index = -1
	_selected_second_index = -1
	second_tile_scroll.visible = false
	first_tile_scroll.visible = true
	first_selector.select(-1)
	second_selector.select(-1)
	second_selector.clear()
	second_selector.disabled = true
	confirm_button.disabled = true

	for tile in first_tiles:
		_mark_tile_selected(tile, false)

	if step_label != null:
		step_label.text = "Step 1: Choose first original card (3 scraps)"
	summary_label.text = "Choose the first original, then another hero's card • 3 scraps."
	first_half_label.text = ""
	second_half_label.text = ""
	consequence_label.text = ""
	_clear_thumbnails()
	_left_edge.color = OWNER_COLORS["warden"]
	_right_edge.color = OWNER_COLORS["tinker"]

	call_deferred("_rebuild_focus_chain")
	call_deferred("_handoff_focus", _epoch, true)


func _handoff_focus(epoch: int, to_first: bool) -> void:
	if _submitted or epoch != _epoch or not is_inside_tree():
		return
	if to_first:
		for tile in first_tiles:
			if is_instance_valid(tile) and tile.is_inside_tree() and tile.visible and not tile.disabled:
				tile.grab_focus()
				return
	else:
		for tile in second_tiles:
			if is_instance_valid(tile) and tile.is_inside_tree() and tile.visible and not tile.disabled:
				tile.grab_focus()
				return


func _on_first_changed(item: int, epoch: int) -> void:
	if _submitted or epoch != _epoch or not _model.is_available() or not is_inside_tree():
		_disable_choice()
		return
	second_selector.clear()
	second_selector.disabled = true
	confirm_button.disabled = true
	if item < 0 or item >= first_selector.item_count:
		_disable_choice()
		return
	var index: Variant = first_selector.get_item_metadata(item)
	if typeof(index) != TYPE_INT:
		_disable_choice()
		return
	_selected_first_index = index
	_selected_second_index = -1
	_populate_second_options(index)


func _on_second_changed(item: int, epoch: int) -> void:
	if _submitted or epoch != _epoch:
		return
	if item < 0 or item >= second_selector.item_count:
		return
	var index: Variant = second_selector.get_item_metadata(item)
	if typeof(index) != TYPE_INT:
		return
	_selected_second_index = index
	for tile in second_tiles:
		_mark_tile_selected(tile, tile.get_meta("index") == index)
	_update_preview()


func _update_preview() -> void:
	confirm_button.disabled = true
	var pair := _current_pair()
	if pair.is_empty():
		_disable_choice()
		return
	summary_label.text = "%s • %d energy • %d scraps (request only)" % [
		pair["display_name"], pair["energy_cost"], pair["scrap_cost"]]
	first_half_label.text = _half_lines("First", pair["first_half"])
	second_half_label.text = _half_lines("Second", pair["second_half"])
	consequence_label.text = _consequence_lines(pair)
	_show_thumbnail(_first_thumb, pair["first_half"])
	_show_thumbnail(_second_thumb, pair["second_half"])
	_left_edge.color = OWNER_COLORS.get(pair["first_owner"], INK)
	_right_edge.color = OWNER_COLORS.get(pair["second_owner"], INK)
	confirm_button.disabled = false


## One compact, index-exact receipt readout below the two authored halves.
func _consequence_lines(pair: Dictionary) -> String:
	return "Replace 0-based originals #%d (%s) + #%d (%s)\n%d → %d shared cards • %d scraps → %d remaining\nNew %s • cannot upgrade or stitch again" % [
		pair["first_index"], pair["first_id"], pair["second_index"], pair["second_id"],
		pair["deck_before_count"], pair["deck_after_count"], pair["scrap_cost"],
		pair["remaining_scraps"], pair["stitched_id"]]


func _positions(positions: Array) -> String:
	if positions.is_empty():
		return "none"
	var values: Array[String] = []
	for pos in positions:
		values.append(str(pos))
	if positions.size() > 1 and positions == range(int(positions[0]), int(positions.back()) + 1):
		return "%s-%s" % [values.front(), values.back()]
	return ", ".join(PackedStringArray(values))


func _target(half: Dictionary) -> String:
	var positions: Array = half["to_positions"]
	match half["target_kind"]:
		"enemy_single":
			return "choose one enemy in positions %s" % _positions(positions)
		"enemy_all":
			return "all eligible enemies in positions %s" % _positions(positions)
		"enemy_random":
			return "random living enemy in positions %s" % _positions(positions) if not positions.is_empty() else "random living enemy"
		"ally_single":
			return "choose one living ally in positions %s" % _positions(
				[1, 2, 3] if positions.is_empty() else positions)
		"party_all":
			return "all allies" if positions.is_empty() else "all allies in positions %s" % _positions(positions)
		"self":
			return "self (no chosen target)"
		"none":
			return "no target to choose"
	return "target unavailable"


func _effects(half: Dictionary) -> String:
	var effects: Dictionary = half["effects"]
	var words: Array[String] = []
	for key in ["damage", "bleed", "bleed_multiplier", "unravel", "exposed", "pinned", "weak",
			"heal", "block", "block_all", "other_ally_block", "guarding", "thorns",
			"draw", "energy", "gain_energy", "self_hp_loss"]:
		if not effects.has(key):
			continue
		match key:
			"damage":
				var damage_text := ""
				if half["target_kind"] == "enemy_random":
					var times_str := "three times" if effects.get("hit_count") == 3 else ("%d times" % effects.get("hit_count", 1))
					damage_text = "%d damage to a random living enemy %s using run RNG" % [effects[key], times_str]
				elif half.get("effects", {}).has("hits") and int(effects.get("hits", 1)) > 1:
					damage_text = "%d damage in %d hits" % [effects[key], effects["hits"]]
				else:
					damage_text = "%d damage%s" % [effects[key],
						" to each eligible enemy" if half["target_kind"] == "enemy_all" else ""]
				var conditional: Variant = effects.get("conditional_damage")
				if typeof(conditional) == TYPE_DICTIONARY:
					damage_text += _conditional_damage_clause(conditional)
				words.append(damage_text)
			"bleed":
				words.append("Bleed %d" % effects[key])
			"bleed_multiplier":
				words.append("Bleed ×%d" % effects[key])
			"unravel":
				words.append("Unravel %d" % effects[key])
			"exposed":
				words.append("Exposed %d" % effects[key])
			"pinned":
				words.append("Pinned")
			"weak":
				words.append("Weak %d" % effects[key])
			"heal":
				if half["target_kind"] == "party_all":
					words.append("heal every ally %d" % effects[key])
				else:
					words.append("heal %d" % effects[key])
			"block":
				words.append("Block %d" % effects[key])
			"block_all":
				words.append("Block %d to all allies" % effects[key])
			"other_ally_block":
				words.append("every other ally gains %d Block" % effects[key])
			"guarding":
				words.append("Guarding")
			"thorns":
				words.append("Thorns %d" % effects[key])
			"draw":
				words.append("draw %d" % effects[key])
			"energy", "gain_energy":
				words.append("gain %d energy" % effects[key])
			"self_hp_loss":
				words.append("%d HP lost" % effects[key])
	var text := "; ".join(PackedStringArray(words))
	if half["owner"] == "seamstress" and effects.has("bleed"):
		text += " (+1 Bleed if applied: Seamstress passive)"
	if half["owner"] == "tinker" and effects.has("damage"):
		text += " (first Tinker attack this turn: +3 damage)"
	return text


func _conditional_damage_clause(conditional: Dictionary) -> String:
	var replacement: Variant = conditional.get("damage")
	if typeof(replacement) != TYPE_INT:
		return ""
	if str(conditional.get("operator", "")) != "or":
		return ""
	var conditions: Variant = conditional.get("conditions")
	if typeof(conditions) != TYPE_ARRAY or conditions.is_empty():
		return ""
	var predicates: Array[String] = []
	for condition in conditions:
		if typeof(condition) != TYPE_DICTIONARY:
			return ""
		var predicate := _conditional_predicate(condition as Dictionary)
		if predicate.is_empty():
			return ""
		predicates.append(predicate)
	return ", or %d instead if %s" % [replacement, " or ".join(PackedStringArray(predicates))]


func _conditional_predicate(condition: Dictionary) -> String:
	if condition.get("status") == "unravelled" and not condition.has("gauge"):
		return "Unravelled"
	if condition.get("gauge") == "unravel" and condition.get("comparison") == "at_least_half" \
			and condition.get("threshold") == "current_target_threshold":
		return "Unravel is at least half its current threshold"
	return ""


func _half_lines(order: String, half: Dictionary) -> String:
	return "%s: %s — %s (%d energy)\nFrom hero positions %s; %s\n%s" % [
		order, half["display_name"], String(half["owner"]).capitalize(),
		half["cost"], _positions(half["from_positions"]), _target(half), _effects(half)]


func _current_pair() -> Dictionary:
	if not is_inside_tree() or not is_visible_in_tree() or not _model.is_available():
		return {}

	# Support both direct tile selection and legacy OptionButton selection
	var f_idx := _selected_first_index
	var s_idx := _selected_second_index
	if f_idx < 0 and first_selector != null and first_selector.selected >= 0 and first_selector.selected < first_selector.item_count:
		var meta: Variant = first_selector.get_item_metadata(first_selector.selected)
		if typeof(meta) == TYPE_INT:
			f_idx = meta
	if s_idx < 0 and second_selector != null and second_selector.selected >= 0 and second_selector.selected < second_selector.item_count:
		var meta: Variant = second_selector.get_item_metadata(second_selector.selected)
		if typeof(meta) == TYPE_INT:
			s_idx = meta

	if f_idx < 0 or s_idx < 0 or f_idx == s_idx:
		return {}

	var pair := _model.preview(f_idx, s_idx)
	if pair.is_empty():
		return {}

	# Audit legacy selectors option mapping against genuine model options.
	# Any forged metadata index must fail closed.
	var firsts := _model.first_options()
	var seconds := _model.second_options(f_idx)
	if first_selector != null and first_selector.item_count > 0:
		if first_selector.item_count != firsts.size():
			return {}
		for i in range(firsts.size()):
			if first_selector.get_item_metadata(i) != firsts[i]["index"] or first_selector.get_item_text(i) != _entry_text(firsts[i]):
				return {}
	if second_selector != null and second_selector.item_count > 0:
		if second_selector.item_count != seconds.size():
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
	_selected_first_index = -1
	_selected_second_index = -1
	if second_tile_scroll != null:
		second_tile_scroll.visible = false
	if first_tile_scroll != null:
		first_tile_scroll.visible = true
	if second_selector != null:
		second_selector.clear()
		second_selector.disabled = true
	if first_selector != null:
		first_selector.select(-1)
		if _submitted:
			first_selector.disabled = true
			first_selector.focus_mode = Control.FOCUS_NONE
	if confirm_button != null:
		confirm_button.disabled = true
		if _submitted:
			confirm_button.focus_mode = Control.FOCUS_NONE
	if _submitted:
		for tile in first_tiles:
			if is_instance_valid(tile):
				tile.disabled = true
				tile.focus_mode = Control.FOCUS_NONE
		for tile in second_tiles:
			if is_instance_valid(tile):
				tile.disabled = true
				tile.focus_mode = Control.FOCUS_NONE
		if is_instance_valid(change_first_button):
			change_first_button.disabled = true
			change_first_button.focus_mode = Control.FOCUS_NONE
	if step_label != null:
		step_label.text = "Stitch requested — awaiting Rest confirmation." if _submitted else "Rest Stitch unavailable"
	if summary_label != null:
		summary_label.text = "Stitch requested — awaiting Rest confirmation." if _submitted else "Not available — select a current eligible pair (3 scraps)."
	if first_half_label != null:
		first_half_label.text = ""
	if second_half_label != null:
		second_half_label.text = ""
	if consequence_label != null:
		consequence_label.text = ""
	_clear_thumbnails()
	call_deferred("_rebuild_focus_chain")


func _on_confirm(epoch: int) -> void:
	if _submitted or epoch != _epoch or confirm_button.disabled:
		return
	var pair := _current_pair()
	if pair.is_empty():
		_disable_choice()
		return
	_submitted = true
	stitch_requested.emit(pair["first_index"], pair["second_index"], pair["source_snapshot"].duplicate(true))
	# This session emits at most one request. The Rest owner decides whether
	# to transact; a fresh binding is needed for any subsequent choice.
	_disable_choice()
	summary_label.text = "Stitch requested — awaiting Rest confirmation."
	if step_label != null:
		step_label.text = "Stitch requested — awaiting Rest confirmation."


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_disable_choice()


func _exit_tree() -> void:
	clear()
