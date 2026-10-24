class_name LiveRestPatchResewPicker
extends Control
## The run owner authenticates and commits re-sews; this view only offers sewn choices.

signal re_sew_requested(patch_id: String, from_hero: String, to_hero: String,
		rest_node_id: String, exact_snapshot: Dictionary)

const CREAM := Color("#eee2ca")
const PAPER := Color("#c8b99e")
const SLATE := Color("#252f39")
const STITCH := Color("#7f8b89")
const GOLD := Color("#f3d28f")

## The mounted owner references these first real buttons for focus and its
## exact destination index guard. Neither opens a dropdown.
class SewnChip extends Button:
	var selected := -1

	func _draw() -> void:
		var thread := Color("#a3a69b") if not button_pressed else Color("#625947")
		for x in range(12, int(size.x) - 10, 15):
			draw_line(Vector2(x, size.y - 5), Vector2(x + 7, size.y - 5), thread, 1.0)

var source_selector: SewnChip
var destination_selector: SewnChip
var source_tags: HFlowContainer
var destination_tags: HFlowContainer
var source_scroll: ScrollContainer
var destination_scroll: ScrollContainer
var _source_buttons: Array[Button] = []
var _destination_buttons: Array[Button] = []
var confirm_button: Button
var scraps_label: Label
var preview_label: Label
var feedback_label: Label

var _wardrobe: RunPatchWardrobe
var _torn: RunTornMending
var _snapshot: Dictionary = {}
var _node_id := ""
var _options: Array = []
var _sources: Array = []
var _destinations: Array = []
var _pending := false


func _ready() -> void:
	_build()
	_clear("Awaiting an active Rest")


func present(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		exact_snapshot: Dictionary, rest_node_id: String,
		owner_message: String = "") -> bool:
	if source_selector == null:
		_build()
	_wardrobe = wardrobe
	_torn = torn
	_snapshot = exact_snapshot.duplicate(true)
	_node_id = rest_node_id
	_pending = false
	var model := RunRestPatchResewOptions.project(wardrobe, torn, _snapshot, _node_id)
	if model.get("ok") != true:
		_clear("Re-sew unavailable (closed Rest, stale state, or insufficient scraps)")
		if wardrobe != null and wardrobe.is_valid() and _snapshot == wardrobe.get_snapshot():
			scraps_label.text = "Scraps: %d" % int(_snapshot.get("scraps", 0))
		return false
	_options = model["options"].duplicate(true)
	scraps_label.text = "Scraps: %d" % model["scraps"]
	feedback_label.text = owner_message if not owner_message.is_empty() else "Choose a patch and a recipient."
	_sources.clear()
	_reset_tags(source_tags, _source_buttons, source_selector)
	_reset_tags(destination_tags, _destination_buttons, destination_selector)
	for option in _options:
		var identity := {"patch_id": option["patch_id"], "from_hero": option["from_hero"]}
		if _sources.has(identity):
			continue
		_sources.append(identity)
		var i := _sources.size() - 1
		var button: SewnChip = source_selector if i == 0 else SewnChip.new()
		if i > 0:
			source_tags.add_child(button)
		_configure_tag(button, "Source_%d" % i, "%s / %s
%s%s" % [
			_nice(option["from_hero"]), option["slot"], _nice(option["patch_id"]),
			" • torn/inactive" if not option["source_active"] else ""], 250)
		button.pressed.connect(_choose_source.bind(i))
		_source_buttons.append(button)
	if _sources.is_empty():
		_update_preview()
	else:
		_choose_source(0, true)
	_relink_focus.call_deferred()
	return true


func selected_option() -> Dictionary:
	if destination_selector == null or _pending or _destinations.is_empty():
		return {}
	var i := destination_selector.selected
	if i < 0 or i >= _destinations.size():
		return {}
	return _destinations[i].duplicate(true)


func _choose_source(index: int, initial: bool = false) -> void:
	if _pending or index < 0 or index >= _sources.size():
		return
	source_selector.selected = index
	for i in range(_source_buttons.size()):
		_source_buttons[i].button_pressed = i == index
		_style_chip(_source_buttons[i], i == index)
	_refresh_destinations(initial)


func _refresh_destinations(select_first: bool = false) -> void:
	_reset_tags(destination_tags, _destination_buttons, destination_selector)
	_destinations.clear()
	if _sources.is_empty() or source_selector.selected < 0:
		_update_preview()
		return
	var chosen: Dictionary = _sources[source_selector.selected]
	for option in _options:
		if option["patch_id"] != chosen["patch_id"] or option["from_hero"] != chosen["from_hero"]:
			continue
		_destinations.append(option.duplicate(true))
		var i := _destinations.size() - 1
		var button: SewnChip = destination_selector if i == 0 else SewnChip.new()
		if i > 0:
			destination_tags.add_child(button)
		var detail := "empty %s" % option["slot"] if option["kind"] == "MOVE" else (
			"swap %s" % _nice(option["exchanged_id"]))
		_configure_tag(button, "Destination_%d" % i,
			"%s / %s
%s%s" % [_nice(option["to_hero"]), option["kind"], detail,
			" • torn/inactive" if not option["destination_active"] else ""], 345)
		button.pressed.connect(_choose_destination.bind(i))
		_destination_buttons.append(button)
	if select_first and not _destinations.is_empty():
		_choose_destination(0)
	else:
		_update_preview()
	_relink_focus.call_deferred()


func _choose_destination(index: int) -> void:
	if _pending or index < 0 or index >= _destinations.size():
		return
	destination_selector.selected = index
	for i in range(_destination_buttons.size()):
		_destination_buttons[i].button_pressed = i == index
		_style_chip(_destination_buttons[i], i == index)
	_update_preview()


func _request_selected() -> void:
	if _pending or not is_visible_in_tree() or not confirm_button.is_visible_in_tree() \
			or confirm_button.disabled or source_selector.selected < 0 \
			or destination_selector.selected < 0:
		return
	var option := selected_option()
	if option.is_empty():
		return
	# Only the ledger can commit; revalidate both legality and authored powers.
	var model := RunRestPatchResewOptions.project(_wardrobe, _torn, _snapshot, _node_id)
	var forecast := RunRestPatchResewOptions.forecast(
		_wardrobe, _torn, _snapshot, _node_id, option)
	if model.get("ok") != true or not model["options"].has(option) \
			or forecast.get("ok") != true:
		_clear("Choice expired: refresh the Rest before trying again")
		return
	_pending = true
	confirm_button.disabled = true
	for button in _source_buttons:
		button.disabled = true
	for button in _destination_buttons:
		button.disabled = true
	feedback_label.text = "Waiting for run owner to accept or reject this request…"
	re_sew_requested.emit(option["patch_id"], option["from_hero"],
		option["to_hero"], _node_id, _snapshot.duplicate(true))


func _update_preview() -> void:
	var option := selected_option()
	if option.is_empty():
		preview_label.text = "Select a destination tag to see its 1-scrap re-sew forecast." \
			if not _destinations.is_empty() else "No eligible re-sew choices"
		confirm_button.disabled = true
		return
	var estimate := RunRestPatchResewOptions.forecast(
		_wardrobe, _torn, _snapshot, _node_id, option)
	if estimate.get("ok") != true:
		_clear("Preview expired: refresh the Rest before trying again")
		return
	var exchange := "empty destination" if estimate["kind"] == "MOVE" else (
		"swap with %s" % _nice(estimate["exchanged_id"]))
	preview_label.text = "%s • %s • %s → %s • %s • Cost: %d scrap
%s
%s
%s
%s" % [
		estimate["kind"], estimate["slot"], _nice(estimate["source"]["hero_id"]),
		_nice(estimate["destination"]["hero_id"]), exchange, estimate["cost"],
		_wearer_preview(estimate["source"], "before"),
		_wearer_preview(estimate["source"], "after"),
		_wearer_preview(estimate["destination"], "before"),
		_wearer_preview(estimate["destination"], "after")]
	confirm_button.disabled = _pending


static func _wearer_preview(wearer: Dictionary, phase: String) -> String:
	var state: Dictionary = wearer[phase]
	var summary := []
	for slot in RunRestPatchResewOptions.SLOTS:
		var patch: Dictionary = state["slots"][slot]
		var id: String = patch["id"]
		if id == "":
			summary.append("%s empty" % slot)
		else:
			var activity := "active" if patch["active"] else "dormant"
			var power: String = " — " + patch["effect"] if not patch["effect"].is_empty() else ""
			summary.append("%s %s (%s)%s" % [slot, _nice(id), activity, power])
	return "%s %s • HP %d/%d, effective cap %d • %s" % [
		_nice(wearer["hero_id"]), phase.to_upper(),
		state["hp"], state["base_max_hp"], state["effective_max_hp"],
		" | ".join(summary)]


func _reset_tags(container: HFlowContainer, buttons: Array[Button], first: SewnChip) -> void:
	for button in buttons:
		if button != first:
			container.remove_child(button)
			button.queue_free()
	for connection in first.pressed.get_connections():
		first.pressed.disconnect(connection.callable)
	buttons.clear()
	first.selected = -1
	first.button_pressed = false
	first.disabled = true
	first.visible = false


func _configure_tag(button: SewnChip, node_name: String, caption: String, width: float) -> void:
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = Vector2(width, 48)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.button_pressed = false
	button.disabled = false
	button.visible = true
	_style_chip(button, false)


func _relink_focus() -> void:
	if not is_inside_tree():
		return
	var controls: Array[Control] = []
	for button in _source_buttons:
		if button.visible and not button.disabled:
			controls.append(button)
	for button in _destination_buttons:
		if button.visible and not button.disabled:
			controls.append(button)
	if not confirm_button.disabled:
		controls.append(confirm_button)
	var close: Control = get_parent().get_node_or_null("DismissResew")
	if close != null:
		controls.append(close)
	if controls.is_empty():
		return
	for i in range(controls.size()):
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(
			controls[(i + controls.size() - 1) % controls.size()])


func _clear(message: String) -> void:
	_pending = false
	_options.clear()
	_sources.clear()
	_destinations.clear()
	_reset_tags(source_tags, _source_buttons, source_selector)
	_reset_tags(destination_tags, _destination_buttons, destination_selector)
	confirm_button.disabled = true
	preview_label.text = "No eligible re-sew choices"
	feedback_label.text = message
	scraps_label.text = "Scraps: --"


func _build() -> void:
	if source_selector != null:
		return
	mouse_filter = Control.MOUSE_FILTER_PASS
	var paper := StyleBoxFlat.new()
	paper.bg_color = SLATE
	paper.border_color = STITCH
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(8)
	var panel := PanelContainer.new()
	panel.name = "StitchedPaperRestPanel"
	panel.add_theme_stylebox_override("panel", paper)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -455
	panel.offset_right = 455
	panel.offset_top = -320
	panel.offset_bottom = 320
	add_child(panel)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 19)
	padding.add_theme_constant_override("margin_right", 19)
	padding.add_theme_constant_override("margin_top", 10)
	padding.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(padding)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	padding.add_child(body)
	body.add_child(_label("REST  /  RE-SEW PATCHES", 22))
	body.add_child(_label("1 scrap per re-sew • Heal / Upgrade / Stitch remains available.", 13))
	scraps_label = _label("Scraps: --", 17)
	body.add_child(scraps_label)
	body.add_child(_label("WORN PATCH  /  SOURCE HERO", 14))
	source_scroll = ScrollContainer.new()
	source_scroll.name = "SewnSourceScroll"
	source_scroll.custom_minimum_size = Vector2(0, 111)
	source_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(source_scroll)
	source_tags = HFlowContainer.new()
	source_tags.name = "SourceTags"
	source_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_tags.add_theme_constant_override("h_separation", 8)
	source_tags.add_theme_constant_override("v_separation", 6)
	source_scroll.add_child(source_tags)
	source_selector = SewnChip.new()
	source_tags.add_child(source_selector)
	body.add_child(_label("RECIPIENT HERO  /  MATCHING SLOT", 14))
	destination_scroll = ScrollContainer.new()
	destination_scroll.name = "SewnDestinationScroll"
	destination_scroll.custom_minimum_size = Vector2(0, 61)
	destination_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(destination_scroll)
	destination_tags = HFlowContainer.new()
	destination_tags.name = "DestinationTags"
	destination_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_tags.add_theme_constant_override("h_separation", 8)
	destination_tags.add_theme_constant_override("v_separation", 6)
	destination_scroll.add_child(destination_tags)
	destination_selector = SewnChip.new()
	destination_tags.add_child(destination_selector)
	preview_label = _label("No eligible re-sew choices", 12)
	preview_label.custom_minimum_size = Vector2(0, 175)
	preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preview_label)
	confirm_button = Button.new()
	confirm_button.name = "ConfirmResew"
	confirm_button.text = "CONFIRM RE-SEW  /  1 SCRAP"
	confirm_button.custom_minimum_size = Vector2(0, 44)
	confirm_button.focus_mode = Control.FOCUS_ALL
	_style_button(confirm_button)
	confirm_button.pressed.connect(_request_selected)
	body.add_child(confirm_button)
	feedback_label = _label("", 12)
	body.add_child(feedback_label)


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _style_chip(button: Button, selected: bool) -> void:
	var base := Color("#d9c49c") if selected else Color("#46565a")
	var ink := SLATE if selected else CREAM
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", SLATE)
	button.add_theme_color_override("font_hover_pressed_color", SLATE)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", Color("#a7aba8"))
	button.add_theme_font_size_override("font_size", 13)
	for name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var surface := StyleBoxFlat.new()
		surface.bg_color = Color("#273239") if name == "disabled" else (
			Color("#efdaad") if name in ["hover", "pressed", "hover_pressed"] else base)
		surface.border_color = GOLD if name == "focus" or selected else STITCH
		surface.set_border_width_all(3 if name == "focus" or selected else 2)
		surface.set_corner_radius_all(5)
		surface.content_margin_top = 3
		surface.content_margin_bottom = 8
		button.add_theme_stylebox_override(name, surface)
	button.queue_redraw()


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", SLATE)
	button.add_theme_color_override("font_focus_color", CREAM)
	button.add_theme_color_override("font_disabled_color", Color("#a7aba8"))
	button.add_theme_color_override("font_hover_pressed_color", SLATE)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#3a4851")
	box.border_color = PAPER
	box.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", box)
	var hovered := box.duplicate()
	hovered.bg_color = Color("#53646a")
	button.add_theme_stylebox_override("hover", hovered)
	var pressed := box.duplicate()
	pressed.bg_color = GOLD
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed.duplicate())
	var disabled := box.duplicate()
	disabled.bg_color = Color("#273239")
	disabled.border_color = STITCH
	button.add_theme_stylebox_override("disabled", disabled)
	var focus := box.duplicate()
	focus.border_color = GOLD
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)


static func _nice(id: String) -> String:
	return id.replace("_", " ").capitalize()
