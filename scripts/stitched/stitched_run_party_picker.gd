class_name StitchedRunPartyPicker
extends GridContainer
## Presentation-only four-of-eight doll board. The App owns the draft and session.

signal draft_changed(picks: Array)

const MAX_PICKS := StitchedPartyAdmission.RANK_COUNT
const PORTRAIT_ROOT := "res://assets/paper/heroes/"
const TILE_SKIN := "res://assets/paper/ui/reward_button.png"
const BONE := Color("#f4e1b8")
const AMBER := Color("#efbb69")

var tiles: Dictionary = {}
var _selected: Array = []
var _reorder_pending := false


func _init() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func build(default_picks: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	tiles.clear()
	_selected.clear()
	var signature_kits := StitchedS14Abilities.kits()
	for id in StitchedPartyAdmission.HERO_IDS:
		if id in default_picks and not id in _selected and _selected.size() < MAX_PICKS:
			_selected.append(id)
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile := Button.new()
		tile.name = "HeroTile_" + id
		tile.set_meta("hero_id", id)
		tile.tooltip_text = StitchedPartyKitHints.tooltip(id, signature_kits)
		tile.toggle_mode = true
		tile.focus_mode = Control.FOCUS_ALL
		tile.custom_minimum_size = Vector2(516, 94)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_skin_tile(tile)
		add_child(tile)
		tiles[id] = tile

		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		var art_path: String = PORTRAIT_ROOT + id + ".png"
		portrait.set_meta("art_path", art_path)
		if ResourceLoader.exists(art_path, "Texture2D"):
			portrait.texture = load(art_path) as Texture2D
		portrait.position = Vector2(16, 5)
		portrait.size = Vector2(90, 84)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(portrait)

		var nameplate := Label.new()
		nameplate.name = "DollName"
		nameplate.position = Vector2(121, 25)
		nameplate.size = Vector2(373, 45)
		nameplate.add_theme_font_size_override("font_size", 23)
		nameplate.add_theme_color_override("font_color", BONE)
		nameplate.add_theme_color_override("font_shadow_color", Color("#221517"))
		nameplate.add_theme_constant_override("shadow_offset_x", 1)
		nameplate.add_theme_constant_override("shadow_offset_y", 2)
		nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(nameplate)
		tile.set_pressed_no_signal(id in _selected)
		_update_name(id)
		tile.toggled.connect(_on_tile_toggled.bind(id))
	_arrange_tiles()


func selected_ids() -> Array:
	return _selected.duplicate()


## Actual top two rows, not click order. Incomplete drafts have no rank receipt.
func displayed_rank_ids() -> Array:
	if _selected.size() != MAX_PICKS or get_child_count() != tiles.size():
		return []
	var ids: Array = []
	for index in range(MAX_PICKS):
		var tile := get_child(index) as Button
		if tile == null or tile.get_parent() != self:
			return []
		ids.append(tile.get_meta("hero_id", ""))
	return ids


## Move the original controls after input dispatch, never while a held pointer/Space
## event is still being delivered to a tile that is changing its grid position.
func _queue_tile_order() -> void:
	if _reorder_pending:
		return
	_reorder_pending = true
	_settle_queued_tile_order.call_deferred()


func _settle_queued_tile_order() -> void:
	if _reorder_pending:
		_arrange_tiles()


## Confirmation is a separate control event: finish only a genuinely queued reflow.
## Never repair unsolicited tile movement, which must fail the App's rank guard.
func settle_pending_tile_order() -> void:
	if _reorder_pending:
		_arrange_tiles()


func _arrange_tiles() -> void:
	_reorder_pending = false
	var focused_tile: Button = get_viewport().gui_get_focus_owner() as Button if is_inside_tree() else null
	var first: Array = _selected.duplicate()
	if first.size() == MAX_PICKS:
		var receipt := StitchedPartyAdmission.admit(first)
		if receipt.get("ok") == true:
			first = receipt["hero_ids"].duplicate()
	for id in StitchedPartyAdmission.HERO_IDS:
		if not id in _selected:
			first.append(id)
	for index in first.size():
		var tile: Button = tiles.get(first[index])
		if is_instance_valid(tile) and tile.get_parent() == self and tile.get_index() != index:
			move_child(tile, index)
	_wire_spatial_focus()
	if is_instance_valid(focused_tile) and focused_tile.get_parent() == self:
		focused_tile.grab_focus()


## Every direction follows the currently displayed two-column grid, not draft order.
## Only build and legitimately queued reflows call this; unsolicited moves stay visible.
func _wire_spatial_focus() -> void:
	if columns != 2 or get_child_count() != StitchedPartyAdmission.HERO_IDS.size() or tiles.size() != get_child_count():
		return
	var row_count: int = get_child_count() / columns
	for index in get_child_count():
		var tile := get_child(index) as Button
		var column := index % columns
		var row: int = index / columns
		var other := get_child(index + (1 if column == 0 else -1)) as Button
		var above := get_child(((row + row_count - 1) % row_count) * columns + column) as Button
		var below := get_child(((row + 1) % row_count) * columns + column) as Button
		if tile == null or other == null or above == null or below == null:
			return
		tile.focus_neighbor_left = tile.get_path_to(other)
		tile.focus_neighbor_right = tile.get_path_to(other)
		tile.focus_neighbor_top = tile.get_path_to(above)
		tile.focus_neighbor_bottom = tile.get_path_to(below)


func tiles_match_draft() -> bool:
	if tiles.size() != StitchedPartyAdmission.HERO_IDS.size():
		return false
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = tiles.get(id)
		if not is_instance_valid(tile) or tile.button_pressed != (id in _selected):
			return false
	return true


func _on_tile_toggled(pressed: bool, id: String) -> void:
	var tile: Button = tiles.get(id)
	if not is_instance_valid(tile) or tile.get_parent() != self or not id in StitchedPartyAdmission.HERO_IDS:
		return
	if pressed:
		if id in _selected or _selected.size() >= MAX_PICKS:
			tile.set_pressed_no_signal(id in _selected)
			return
		_selected.append(id)
	else:
		if not id in _selected:
			tile.set_pressed_no_signal(false)
			return
		_selected.erase(id)
	_update_name(id)
	_queue_tile_order()
	draft_changed.emit(_selected.duplicate())


func _update_name(id: String) -> void:
	var tile: Button = tiles[id]
	var label: Label = tile.get_node("DollName")
	label.text = id.replace("_", " ").capitalize() + ("   ✓" if id in _selected else "")
	label.add_theme_color_override("font_color", AMBER if id in _selected else BONE)


func _skin_tile(tile: Button) -> void:
	var texture: Texture2D = load(TILE_SKIN) as Texture2D if ResourceLoader.exists(TILE_SKIN, "Texture2D") else null
	if texture == null:
		return
	var faces := {
		"normal": Color("#593a3c"),
		"hover": Color("#845755"),
		"pressed": Color("#d4a160"),
		"hover_pressed": Color("#efbd75"),
		"disabled": Color("#5e4b48"),
		"focus": Color("#ffcd79"),
	}
	for face in faces:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.texture_margin_left = 16
		style.texture_margin_right = 16
		style.texture_margin_top = 16
		style.texture_margin_bottom = 16
		style.modulate_color = faces[face]
		if face == "focus":
			style.draw_center = false
			style.expand_margin_left = 3
			style.expand_margin_right = 3
			style.expand_margin_top = 3
			style.expand_margin_bottom = 3
		tile.add_theme_stylebox_override(face, style)
