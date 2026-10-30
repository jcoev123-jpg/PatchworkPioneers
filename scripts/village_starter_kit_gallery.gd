class_name VillageStarterKitGallery
extends Control
## Read-only reference to the canonical four starter-card occurrences per hero.
## Never allocates a run, selects a party, spends currency or owns any RNG.

signal close_requested

const INK := Color("#28313b")
const PAPER := Color("#eee0bf")
const THREAD := Color("#a36b50")
const DARK := Color("#293544")
const CREAM := Color("#fff0ce")

var hero_buttons: Dictionary = {}
var card_buttons: Array[Button] = []
var close_button: Button
var detail_label: Label
var hero_title: Label
var selected_hero_id := ""
var selected_occurrence := -1
var hero_order: Array[String] = []
var _kits: Dictionary = {}
var _open := false
var _hero_grid: GridContainer
var _card_list: VBoxContainer
var _focus_ring: Array[Button] = []


static func _sewn_box(bg: Color, border: Color = THREAD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(7)
	box.set_content_margin_all(8)
	return box


static func _button_face(button: Button) -> void:
	button.theme_type_variation = &"PatchHeadingButton"
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	for style in ["normal", "disabled"]:
		button.add_theme_stylebox_override(style, _sewn_box(PAPER))
	for style in ["hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(style, _sewn_box(Color("#fff0d3"), Color("#89583e")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	var focus := _sewn_box(Color.TRANSPARENT, Color("#f8cc76"))
	focus.draw_center = false
	focus.set_border_width_all(4)
	button.add_theme_stylebox_override("focus", focus)


static func _label(message: String, size_px: int = 18, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## All items come from the exact same source admission validates; invalid records
## disappear rather than inheriting a guessed hero, card or special-effect claim.
static func canonical_kits() -> Dictionary:
	var records := RunV3PartyAdmission._canonical_records()
	if records.is_empty():
		return {}
	var kits: Dictionary = {}
	for hero_id in RunV3PartyAdmission.HERO_IDS:
		if not records.has(hero_id):
			continue
		var ids := RunV3PartyAdmission._starters(hero_id, null)
		if ids.size() != RunV3PartyAdmission.STARTERS_PER_HERO:
			continue
		var catalog := RunV3PartyAdmission._shipped_catalog(hero_id)
		if catalog == null:
			continue
		var cards: Array[Dictionary] = []
		for card_id in ids:
			var card: Variant = catalog.get_definition(card_id)
			if not card is Dictionary or card.get("id") != card_id or card.get("owner") != hero_id \
					or card.has("upgrade_of") or card_id.ends_with("_plus") \
					or not card.get("display_name") is String or String(card["display_name"]).is_empty() \
					or not card.get("cost") is int or card["cost"] < 0 \
					or not card.get("from_positions") is Array or not card.get("to_positions") is Array \
					or not card.get("target_kind") is String or not card.get("effects") is Dictionary:
				cards.clear()
				break
			var positions_ok := true
			for field in ["from_positions", "to_positions"]:
				for position in card[field]:
					if not position is int or position not in [1, 2, 3]:
						positions_ok = false
			if not positions_ok:
				cards.clear()
				break
			cards.append(card.duplicate(true))
		if cards.size() == RunV3PartyAdmission.STARTERS_PER_HERO:
			kits[hero_id] = {"name": String(records[hero_id].definition.name), "cards": cards}
	return kits


func get_occurrences(hero_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _kits.has(hero_id):
		return result
	for card in _kits[hero_id]["cards"]:
		result.append((card as Dictionary).duplicate(true))
	return result


func selected_card() -> Dictionary:
	var cards := get_occurrences(selected_hero_id)
	if selected_occurrence < 0 or selected_occurrence >= cards.size():
		return {}
	return cards[selected_occurrence].duplicate(true)


func is_open() -> bool:
	return _open and is_visible_in_tree()


func _ready() -> void:
	name = "StarterKitGallery"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build_ui()
	hide()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color("#131c25ef")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var paper := PanelContainer.new()
	paper.name = "SewnGalleryPaper"
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 52
	paper.offset_top = 35
	paper.offset_right = -52
	paper.offset_bottom = -35
	paper.add_theme_stylebox_override("panel", _sewn_box(DARK, Color("#c9a27c")))
	add_child(paper)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 12)
	paper.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 15)
	layout.add_child(heading)
	var title := _label("DECK HOUSE  /  STARTER KITS", 30)
	title.theme_type_variation = &"PatchHeading"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = Button.new()
	close_button.name = "CloseGallery"
	close_button.text = "Close  [Esc]"
	close_button.custom_minimum_size = Vector2(155, 47)
	_button_face(close_button)
	close_button.pressed.connect(_request_close)
	heading.add_child(close_button)
	layout.add_child(_label("Reference only  •  Four starting card occurrences per hero  •  No run is open", 18))

	_hero_grid = GridContainer.new()
	_hero_grid.name = "HeroChoices"
	_hero_grid.columns = 4
	_hero_grid.add_theme_constant_override("h_separation", 9)
	_hero_grid.add_theme_constant_override("v_separation", 7)
	layout.add_child(_hero_grid)

	var seam := HSeparator.new()
	layout.add_child(seam)
	hero_title = _label("Choose a hero", 24, Color("#ffd89e"))
	layout.add_child(hero_title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(385, 0)
	left.add_theme_constant_override("separation", 7)
	body.add_child(left)
	left.add_child(_label("FOUR AUTHORED OCCURRENCES", 18))
	_card_list = VBoxContainer.new()
	_card_list.name = "StarterOccurrences"
	_card_list.add_theme_constant_override("separation", 7)
	left.add_child(_card_list)

	var details_panel := PanelContainer.new()
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_panel.add_theme_stylebox_override("panel", _sewn_box(Color("#f0e1c3"), Color("#ad8461")))
	body.add_child(details_panel)
	var details_margin := MarginContainer.new()
	for side in ["left", "right"]:
		details_margin.add_theme_constant_override("margin_" + side, 13)
	details_margin.add_theme_constant_override("margin_top", 8)
	details_margin.add_theme_constant_override("margin_bottom", 8)
	details_panel.add_child(details_margin)
	var scroll := ScrollContainer.new()
	scroll.name = "CardDetailsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_margin.add_child(scroll)
	detail_label = _label("Choose an authored card.", 18, INK)
	detail_label.name = "CardDetails"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_label)

	layout.add_child(_label("Printed effects describe authored intent, not a guarantee of live combat support.", 17))

	_kits = canonical_kits()
	for hero_id in RunV3PartyAdmission.HERO_IDS:
		if not _kits.has(hero_id):
			continue
		hero_order.append(hero_id)
		var button := Button.new()
		button.name = "Hero_" + hero_id
		button.text = _kits[hero_id]["name"]
		button.custom_minimum_size = Vector2(0, 43)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button_face(button)
		button.pressed.connect(_choose_hero.bind(hero_id))
		_hero_grid.add_child(button)
		hero_buttons[hero_id] = button
	for index in range(RunV3PartyAdmission.STARTERS_PER_HERO):
		var button := Button.new()
		button.name = "StarterOccurrence_%d" % (index + 1)
		button.custom_minimum_size = Vector2(0, 49)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button_face(button)
		button.pressed.connect(_choose_card.bind(index))
		_card_list.add_child(button)
		card_buttons.append(button)
	_wire_focus()


func _wire_focus() -> void:
	_focus_ring.clear()
	for hero_id in hero_order:
		_focus_ring.append(hero_buttons[hero_id])
	_focus_ring.append_array(card_buttons)
	_focus_ring.append(close_button)
	for i in range(_focus_ring.size()):
		_focus_ring[i].focus_next = _focus_ring[i].get_path_to(_focus_ring[(i + 1) % _focus_ring.size()])
		_focus_ring[i].focus_previous = _focus_ring[i].get_path_to(_focus_ring[(i - 1 + _focus_ring.size()) % _focus_ring.size()])


func open_gallery() -> bool:
	if _open or not is_inside_tree() or not get_parent().is_visible_in_tree() or hero_order.is_empty():
		return false
	_open = true
	show()
	_choose_hero(hero_order[0])
	hero_buttons[hero_order[0]].grab_focus()
	return true


func dismiss() -> void:
	_open = false
	hide()
	for button in _focus_ring:
		if is_instance_valid(button):
			button.release_focus()
	selected_hero_id = ""
	selected_occurrence = -1


func _request_close() -> void:
	if not is_open():
		return
	close_requested.emit()


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_request_close()


func _choose_hero(hero_id: String) -> void:
	if not is_open() or not _kits.has(hero_id) or not hero_buttons.has(hero_id):
		return
	selected_hero_id = hero_id
	hero_title.text = "%s  /  BASE STARTERS" % _kits[hero_id]["name"]
	var cards := get_occurrences(hero_id)
	for index in range(card_buttons.size()):
		var button := card_buttons[index]
		button.disabled = index >= cards.size()
		button.text = "%d.  %s  ·  %d EN" % [index + 1, cards[index]["display_name"],
			cards[index]["cost"]] if index < cards.size() else "Unavailable"
	_choose_card(0)


func _choose_card(index: int) -> void:
	if not is_open() or not _kits.has(selected_hero_id):
		return
	var cards := get_occurrences(selected_hero_id)
	if index < 0 or index >= cards.size() or index >= card_buttons.size() or card_buttons[index].disabled:
		return
	selected_occurrence = index
	var card := cards[index]
	var from_positions: Array[String] = []
	var to_positions: Array[String] = []
	for position in card["from_positions"]:
		from_positions.append(str(position))
	for position in card["to_positions"]:
		to_positions.append(str(position))
	var lines: Array[String] = [
		"%s  ·  OCCURRENCE %d / %d" % [card["display_name"], index + 1, cards.size()],
		"ID: %s" % card["id"],
		"OWNER: %s      COST: %d ENERGY" % [card["owner"], card["cost"]],
		"FROM: %s" % (", ".join(from_positions) if not from_positions.is_empty() else "—"),
		"TO: %s" % (", ".join(to_positions) if not to_positions.is_empty() else "—"),
		"TARGET KIND: %s" % card["target_kind"],
		"",
		"AUTHORED EFFECT DESCRIPTORS",
	]
	var short := CardShortRules.describe(card)
	if short.get("known", false) and not String(short.get("line", "")).is_empty():
		lines.append("Short rules: " + String(short["line"]))
	for key in card["effects"]:
		lines.append("%s: %s" % [str(key), JSON.stringify(card["effects"][key])])
	if (card["effects"] as Dictionary).is_empty() or short.get("unknown", false):
		lines.append("Other authored effect semantics: Unavailable.")
	detail_label.text = "\n".join(lines)
	detail_label.tooltip_text = detail_label.text
	var scroll := detail_label.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0
