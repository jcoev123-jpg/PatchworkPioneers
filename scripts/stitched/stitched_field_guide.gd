class_name StitchedFieldGuide
extends Control
## A read-only, focus-trapped village field guide. It owns no run or RNG.

signal close_requested

const FELT := preload("res://assets/paper/ui/panel_felt.png")
const GOTHIC := preload("res://themes/gothic_theme.tres")
const PART_INSPECTOR_SCENE := preload("res://scenes/stitched_part_inspector.tscn")
const WARDEN_PARTS := "res://data/parts/warden_parts.json"
const FOE_PARTS := "res://data/parts/enemy_parts.json"
const BONE := Color("#f4e5cd")
const BRASS := Color("#e0b977")
const PAGES := [
	[
		"FRONT TO BACK  |  Friendly ranks are 1 (front) through 4 (back). Foes also occupy ranks 1–4. A fight begins with 2–3 foes; the fourth arrives only by summon or split.",
		"ROUND ORDER  |  Every round, seeded RNG rolls SPEED + 1d8 for each unit. Ties favour heroes, then lower ranks. Each unit gets one turn, except certain two-turn bosses.",
		"EQUIPPED PARTS  |  HEAD / ARMS / TORSO / LEGS: four slots, one ability each. Every ability has legal launch ranks and target ranks.",
		"OTHER ACTIONS  |  MOVE swaps with an adjacent ally. RE-TIE is available only after that hero's thread was snipped. Or PASS."
	],
	[
		"RETREAT  |  In non-boss fights, each attempt has a 75% chance to escape. Failure consumes that hero's turn. Success gives EACH hero +15 Fray and forfeits all rewards.",
		"SNIPPED THREAD  |  A cut stops the hero's movement, and healing or guard cannot cross that cut until the thread is re-tied.",
		"ZERO HP  |  At 0 HP, a hero is Hanging by a Thread, but can still act. The first transition tears one random non-torso part.",
		"FURTHER HITS  |  A further hit checks the seam: 67% to hold, 33% to lose the seam."
	],
	[
		"FRAY  |  Fray ranges from 0–200. At 100, a resolve check gives 25% Steadfast (return to 45 Fray) or 75% Unravelled.",
		"COMING APART  |  At 200 Fray: Comes Apart, then Fray becomes 150.",
		"CANDLE  |  Begins at 100. Bright 76–100; Dim 51–75; Gloom 26–50; Dark 1–25; Snuffed 0.",
		"FUTURE S6 INTEGRATION  |  Losing 8 Candle per map node is scheduled for S6 run integration. It is NOT active in current S4 play."
	]
]
const TABS := ["Ranks & turns", "Seams & retreat", "Fray & candle"]

var tab_buttons: Array[Button] = []
var page_labels: Array[Label] = []
var close_button: Button
var atlas_button: Button
var atlas_status: Label
var part_atlas: StitchedPartInspector
# Fixed live sources. The mounted regression can replace one with a missing path
# to prove that a partial catalog never leaves stale or selectable parts.
var catalog_paths: Array[String] = [WARDEN_PARTS, FOE_PARTS]
var page_index := 0
var _active := false


func _ready() -> void:
	name = "StitchedFieldGuide"
	# Live play inherits App's Gothic theme; a local Theme would break the shared
	# downstream-control theme inheritance contract.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_view()
	visibility_changed.connect(_on_visibility_changed)
	hide()


func is_open() -> bool:
	return _active


func open_guide() -> bool:
	if _active or not is_inside_tree() or not get_parent().is_visible_in_tree():
		return false
	_active = true
	show()
	select_page(0)
	tab_buttons[0].grab_focus()
	return true


func dismiss() -> void:
	_close_part_atlas(false)
	_active = false
	hide()


func select_page(index: int) -> void:
	if not _active or index < 0 or index >= page_labels.size():
		return
	page_index = index
	for i in range(page_labels.size()):
		page_labels[i].visible = i == index
		tab_buttons[i].button_pressed = i == index


func page_text(index: int) -> String:
	if index < 0 or index >= page_labels.size():
		return ""
	return page_labels[index].text


func _request_close() -> void:
	if _active:
		close_requested.emit()


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree() or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if _atlas_is_open() and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_cycle_atlas_focus(event.shift_pressed)
	elif event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _atlas_is_open():
			_close_part_atlas(true)
		else:
			_request_close()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_close_part_atlas(false)
		_active = false


## This is an atlas, not a satchel: both real file catalogs must validate in
## full before the existing inspector receives any entries. No gameplay API is
## referenced, and reopening always reloads the authored sources.
func open_part_atlas() -> bool:
	if not _active or not is_inside_tree() or not is_visible_in_tree() or _atlas_is_open():
		return false
	var entries: Array = []
	for path in catalog_paths:
		var result := StitchedParts.load_catalog(path)
		if not bool(result.get("ok", false)):
			_reject_part_atlas()
			return false
		entries.append_array(result["parts"])
	if entries.is_empty():
		_reject_part_atlas()
		return false
	if not is_instance_valid(part_atlas):
		part_atlas = PART_INSPECTOR_SCENE.instantiate() as StitchedPartInspector
		if part_atlas == null:
			_reject_part_atlas()
			return false
		part_atlas.name = "PartAtlasInspector"
		part_atlas.hide()
		add_child(part_atlas)
		part_atlas.close_requested.connect(_on_part_atlas_close_requested)
		var rows := part_atlas.get_node("CatalogPanel/PartScroll/PartRows")
		rows.child_entered_tree.connect(_on_atlas_rows_changed)
		rows.child_exiting_tree.connect(_on_atlas_rows_changed)
	if not part_atlas.present_parts(entries):
		_reject_part_atlas()
		return false
	(part_atlas.get_node("Subtitle") as Label).text = (
		"REFERENCE ONLY  •  Warden parts and foe spoils; nothing is equipped or claimed here.")
	part_atlas.show()
	atlas_status.text = "REFERENCE ONLY  •  Inspect part abilities and tiers; no changes to your party."
	_wire_atlas_focus()
	(part_atlas.get_node("CloseButton") as Button).grab_focus()
	return true


func _atlas_is_open() -> bool:
	return is_instance_valid(part_atlas) and part_atlas.visible


func _reject_part_atlas() -> void:
	_close_part_atlas(false)
	atlas_status.text = "PARTS & SPOILS UNAVAILABLE  •  Catalog validation failed; no parts displayed."


func _on_part_atlas_close_requested() -> void:
	_close_part_atlas(true)


func _close_part_atlas(restore_focus: bool) -> void:
	if is_instance_valid(part_atlas):
		part_atlas.hide()
		# A previous successful readout must never survive hide or a bad reload.
		part_atlas.present_parts([])
	if restore_focus and _active and is_visible_in_tree():
		atlas_button.grab_focus()


func _on_atlas_rows_changed(_node: Node) -> void:
	# Inspector rebuilds its rows on slot/part selection. Re-link the newly
	# generated controls after its old, queued-for-deletion rows are gone.
	_wire_atlas_focus.call_deferred()


func _atlas_focus_buttons() -> Array[Button]:
	var ring: Array[Button] = []
	if not _atlas_is_open():
		return ring
	for path in ["CloseButton", "CatalogPanel/SlotHead", "CatalogPanel/SlotArms",
			"CatalogPanel/SlotTorso", "CatalogPanel/SlotLegs"]:
		var button := part_atlas.get_node(path) as Button
		if not button.disabled:
			ring.append(button)
	for child in part_atlas.get_node("CatalogPanel/PartScroll/PartRows").get_children():
		if child is Button and not child.is_queued_for_deletion() and not child.disabled:
			ring.append(child as Button)
	for path in ["DetailsPanel/TierI", "DetailsPanel/TierII", "DetailsPanel/TierIII"]:
		var button := part_atlas.get_node(path) as Button
		if not button.disabled:
			ring.append(button)
	return ring


func _wire_atlas_focus() -> void:
	var ring := _atlas_focus_buttons()
	for i in range(ring.size()):
		ring[i].focus_next = ring[i].get_path_to(ring[(i + 1) % ring.size()])
		ring[i].focus_previous = ring[i].get_path_to(ring[(i - 1 + ring.size()) % ring.size()])


func _cycle_atlas_focus(backwards: bool) -> void:
	_wire_atlas_focus()
	var ring := _atlas_focus_buttons()
	if ring.is_empty():
		return
	var current := ring.find(get_viewport().gui_get_focus_owner())
	var next := 0 if current < 0 else (current + (-1 if backwards else 1) + ring.size()) % ring.size()
	ring[next].grab_focus()


func _build_view() -> void:
	# Both surfaces use the supplied felt image; no paint/StyleBoxFlat/draw calls.
	var veil := TextureRect.new()
	veil.name = "FeltVeil"
	veil.texture = FELT
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.modulate = Color(0.12, 0.08, 0.10, 0.92)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var felt := NinePatchRect.new()
	felt.name = "FeltPanel"
	felt.texture = FELT
	felt.patch_margin_left = 90
	felt.patch_margin_top = 90
	felt.patch_margin_right = 90
	felt.patch_margin_bottom = 90
	felt.anchor_left = 0.5
	felt.anchor_top = 0.5
	felt.anchor_right = 0.5
	felt.anchor_bottom = 0.5
	felt.offset_left = -570
	felt.offset_top = -313
	felt.offset_right = 570
	felt.offset_bottom = 313
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)

	var content := VBoxContainer.new()
	content.name = "GuideContent"
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 104
	content.offset_top = 82
	content.offset_right = -104
	content.offset_bottom = -80
	content.add_theme_constant_override("separation", 12)
	felt.add_child(content)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	content.add_child(heading)
	var title := Label.new()
	title.name = "GuideHeading"
	title.text = "THE STITCHED  •  FIELD NOTES"
	title.theme_type_variation = &"PatchHeading"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title)
	close_button = Button.new()
	close_button.name = "CloseGuideButton"
	close_button.text = "Close  [Esc]"
	close_button.custom_minimum_size = Vector2(152, 46)
	close_button.add_theme_font_size_override("font_size", 19)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_request_close)
	heading.add_child(close_button)
	atlas_button = Button.new()
	atlas_button.name = "PartAtlasButton"
	atlas_button.text = "Parts & spoils"
	atlas_button.tooltip_text = "Reference only: examine Warden parts and foe drops"
	atlas_button.custom_minimum_size = Vector2(190, 46)
	atlas_button.add_theme_font_size_override("font_size", 19)
	atlas_button.focus_mode = Control.FOCUS_ALL
	atlas_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	atlas_button.pressed.connect(open_part_atlas)
	heading.add_child(atlas_button)
	heading.move_child(atlas_button, heading.get_child_count() - 2)

	var tabs := HBoxContainer.new()
	tabs.name = "GuideTabs"
	tabs.add_theme_constant_override("separation", 16)
	content.add_child(tabs)
	for i in range(TABS.size()):
		var button := Button.new()
		button.name = "GuideTab%d" % i
		button.text = TABS[i]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(212, 42)
		button.add_theme_font_size_override("font_size", 19)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(select_page.bind(i))
		tabs.add_child(button)
		tab_buttons.append(button)

	atlas_status = Label.new()
	atlas_status.name = "PartAtlasStatus"
	atlas_status.text = "REFERENCE ONLY  •  Parts & spoils lists abilities, not equipment or rewards."
	atlas_status.add_theme_font_size_override("font_size", 16)
	atlas_status.add_theme_color_override("font_color", BRASS)
	atlas_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(atlas_status)

	# A single visible page at a time, with wrap and scroll as a smaller-screen
	# fallback. At 1280x720 the 18px copy fits the stitched panel without scroll.
	var scroller := ScrollContainer.new()
	scroller.name = "GuidePageScroll"
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroller)
	var pages := VBoxContainer.new()
	pages.name = "GuidePages"
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(pages)
	for i in range(PAGES.size()):
		var label := Label.new()
		label.name = "GuidePage%d" % i
		label.text = "\n\n".join(PAGES[i])
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", BONE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		pages.add_child(label)
		page_labels.append(label)

	var focus_ring: Array[Button] = tab_buttons.duplicate()
	focus_ring.append(atlas_button)
	focus_ring.append(close_button)
	for i in range(focus_ring.size()):
		focus_ring[i].focus_next = focus_ring[i].get_path_to(focus_ring[(i + 1) % focus_ring.size()])
		focus_ring[i].focus_previous = focus_ring[i].get_path_to(focus_ring[(i - 1 + focus_ring.size()) % focus_ring.size()])
