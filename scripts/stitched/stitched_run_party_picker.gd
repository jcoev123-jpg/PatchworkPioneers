class_name StitchedRunPartyPicker
extends GridContainer
## Presentation-only four-of-eight doll board. The App owns the draft and session.

signal draft_changed(picks: Array)

const MAX_PICKS := StitchedPartyAdmission.RANK_COUNT
const PORTRAIT_ROOT := "res://assets/paper/heroes/"
const TILE_SKIN := "res://assets/paper/ui/reward_button.png"
const BONE := Color("#f4e1b8")
const AMBER := Color("#efbb69")
const OXBLOOD := Color("#742c38")
const WARNING_BONE := Color("#ffe8c3")
const SHADOW := Color("#221517")

var tiles: Dictionary = {}
var _selected: Array = []
var _reorder_pending := false
var _base_tooltips: Dictionary = {}
var _rank_cues: Dictionary = {}
var _uncued_faces: Dictionary = {}
var _shoulder_held: Dictionary = {}


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
	_base_tooltips.clear()
	_rank_cues.clear()
	_uncued_faces.clear()
	var signature_kits := StitchedS14Abilities.kits()
	for id in StitchedPartyAdmission.HERO_IDS:
		if id in default_picks and not id in _selected and _selected.size() < MAX_PICKS:
			_selected.append(id)
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile := Button.new()
		tile.name = "HeroTile_" + id
		tile.set_meta("hero_id", id)
		tile.tooltip_text = StitchedPartyKitHints.tooltip(id, signature_kits)
		_base_tooltips[id] = tile.tooltip_text
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
		nameplate.add_theme_color_override("font_shadow_color", SHADOW)
		nameplate.add_theme_constant_override("shadow_offset_x", 1)
		nameplate.add_theme_constant_override("shadow_offset_y", 2)
		nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(nameplate)
		tile.set_pressed_no_signal(id in _selected)
		_update_name(id)
		tile.toggled.connect(_on_tile_toggled.bind(id))
	_arrange_tiles()


## Share the digit shortcut's live-page authentication with shoulder browsing.
## A retained/hidden picker or focus outside its real page cannot capture input.
func _live_focus_owner() -> Control:
	if not is_inside_tree() or not is_visible_in_tree() or not tiles_match_draft():
		return null
	var content := get_parent() as Control
	var frame := content.get_parent() if content != null else null
	var page := frame.get_parent() as Control if frame != null else null
	var app := page.get_parent() if page != null else null
	var focus_owner := get_viewport().gui_get_focus_owner()
	if (content == null or page == null or page.name != "StitchedRunPage"
			or page.get_meta("page_kind", "") != "picker" or not page.is_visible_in_tree()
			or app == null or app.get("stitched_run_panel") != page
			or get_meta("stitched_run_epoch", -1) != app.get("_stitched_run_epoch")
			or focus_owner == null or not content.is_ancestor_of(focus_owner)):
		return null
	return focus_owner


## Only pressed shoulder edges navigate; releases merely rearm their own button.
## Native Accept, spatial D-pad neighbors and the tile's toggled signal are unchanged.
func _unhandled_input(event: InputEvent) -> void:
	var shoulder := event as InputEventJoypadButton
	if shoulder == null or (shoulder.button_index != JOY_BUTTON_LEFT_SHOULDER
			and shoulder.button_index != JOY_BUTTON_RIGHT_SHOULDER):
		return
	var held_key := Vector2i(shoulder.device, shoulder.button_index)
	if not shoulder.pressed:
		_shoulder_held.erase(held_key)
		return
	if _shoulder_held.has(held_key):
		return
	_shoulder_held[held_key] = true
	var focus_owner := _live_focus_owner()
	if focus_owner == null or get_child_count() != StitchedPartyAdmission.HERO_IDS.size():
		return
	var direction := 1 if shoulder.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
	var index := focus_owner.get_index() if focus_owner.get_parent() == self else -1
	if index >= 0:
		var id: String = focus_owner.get_meta("hero_id", "")
		if tiles.get(id) != focus_owner:
			return
	else:
		var app := get_parent().get_parent().get_parent().get_parent()
		var actions: Array = app.get("stitched_run_buttons")
		if (actions.size() != 2 or (focus_owner != actions[0] and focus_owner != actions[1])
				or focus_owner.disabled or not focus_owner.is_visible_in_tree()):
			return
		index = -1 if direction > 0 else 0
	var next_index := posmod(index + direction, get_child_count())
	var next_tile := get_child(next_index) as Button
	if (next_tile == null or tiles.get(next_tile.get_meta("hero_id", "")) != next_tile
			or next_tile.disabled or not next_tile.is_visible_in_tree()):
		return
	next_tile.grab_focus()
	get_viewport().set_input_as_handled()


## A shortcut acts on the same original Button property as a click, so its
## toggled signal remains the only path to the validated draft_changed signal.
## Ignore keys if this is no longer the focused, mounted New Run page.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if (key == null or not key.pressed or key.echo
			or key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed):
		return
	var index := int(key.physical_keycode) - int(KEY_1)
	if (index < 0 or index >= StitchedPartyAdmission.HERO_IDS.size()
			or key.physical_keycode > KEY_8):
		return
	var focus_owner := _live_focus_owner()
	if focus_owner == null:
		return
	var id: String = StitchedPartyAdmission.HERO_IDS[index]
	var tile: Button = tiles.get(id)
	if (not is_instance_valid(tile) or tile.get_parent() != self
			or not tile.is_visible_in_tree() or tile.disabled):
		return
	# A focused Set out can become disabled on deselection. Like a mouse click,
	# focus the actual tile first, so the next number still has a live focus context.
	# Existing tile-to-tile focus is preserved through the deferred reflow.
	if not is_ancestor_of(focus_owner):
		tile.grab_focus()
	tile.button_pressed = not tile.button_pressed
	get_viewport().set_input_as_handled()


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


## The App calls this only after authenticating the live draft_changed event,
## or when building the initial draft. Incomplete drafts clear all warnings.
## A pending legitimate reflow is allowed; a foreign tile order is not.
func update_opening_rank_cues(accepted_picks: Array) -> void:
	if accepted_picks != _selected or not tiles_match_draft():
		return
	var warnings := {}
	if accepted_picks.size() == MAX_PICKS:
		var receipt := StitchedPartyAdmission.admit(accepted_picks)
		if receipt.get("ok") != true:
			return
		if not _reorder_pending and displayed_rank_ids() != receipt.get("hero_ids", []):
			return
		for hero in StitchedPartyKitHints.opening_rank_stranded(accepted_picks):
			var id: String = hero["id"]
			var rank: int = hero["rank"]
			if id in _selected and receipt["hero_ids"][rank - 1] == id:
				warnings[id] = hero
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = tiles.get(id)
		if not is_instance_valid(tile) or tile.get_parent() != self:
			return
	for id in StitchedPartyAdmission.HERO_IDS:
		_set_opening_rank_cue(id, warnings.get(id, {}))


## Recolour the already-skinned original Button using copies of its existing
## image styles. No extra control, texture, hit target or rank plaque is made.
func _set_opening_rank_cue(id: String, cue: Dictionary) -> void:
	if _rank_cues.get(id, {}) == cue:
		return
	var tile: Button = tiles[id]
	if not _uncued_faces.has(id):
		var originals := {}
		for face in ["pressed", "hover_pressed", "focus"]:
			if tile.has_theme_stylebox_override(face):
				originals[face] = tile.get_theme_stylebox(face)
		_uncued_faces[id] = originals
	var faces: Dictionary = _uncued_faces[id]
	if cue.is_empty():
		_rank_cues.erase(id)
		tile.tooltip_text = _base_tooltips[id]
		for face in faces:
			tile.add_theme_stylebox_override(face, faces[face])
	else:
		_rank_cues[id] = cue.duplicate()
		tile.tooltip_text = _base_tooltips[id] + "\n%s at rank %d cannot launch a signature move; Move/Pass remain possible." % [
			cue["name"], cue["rank"]]
		for face in faces:
			var source: StyleBoxTexture = faces[face] as StyleBoxTexture
			if source == null:
				continue
			var warning_style := source.duplicate(true) as StyleBoxTexture
			warning_style.modulate_color = WARNING_BONE if face == "focus" else (
				Color("#a14b50") if face == "hover_pressed" else OXBLOOD)
			tile.add_theme_stylebox_override(face, warning_style)
	_update_name(id)


func _update_name(id: String) -> void:
	var tile: Button = tiles[id]
	var label: Label = tile.get_node("DollName")
	label.text = id.replace("_", " ").capitalize() + ("   ✓" if id in _selected else "")
	label.add_theme_color_override("font_color", WARNING_BONE if _rank_cues.has(id) else (AMBER if id in _selected else BONE))
	label.add_theme_color_override("font_shadow_color", OXBLOOD if _rank_cues.has(id) else SHADOW)


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
