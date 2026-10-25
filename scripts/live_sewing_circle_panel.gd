class_name LiveSewingCirclePanel
extends Control
## Independently mounted presentation. Only the recipient controller settles intent.
signal intent_requested(intent: Dictionary)

const BUTTON_ART := "res://assets/paper/ui/reward_button.png"
const INK := Color("#28313c")
## Readable, visibly duller ink for an action the visit cannot pay for.
const DISABLED_INK := Color("#7a7267")
var upgrade_button: Button
var stitch_button: Button
var leave_button: Button
var confirm_button: Button
var status_label: Label
var preview_label: Label
var choice_scroll: ScrollContainer
var preview_scroll: ScrollContainer
var choices: VBoxContainer
var option_buttons: Array[Button] = []
var _visit: RunSewingCircleVisit
var _source: Dictionary = {}
var _epoch := 0
var _submitted := false
var _mode := ""
var _first := -1
var _second := -1
var _preview: Dictionary = {}
## This session's own button callbacks, by button. Only these are retired on a
## rebind or close, so any listener a recipient attached stays untouched.
var _session: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(940, 620)
	size = custom_minimum_size
	var paper := Panel.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f4e9d1")
	style.border_color = INK
	style.set_border_width_all(3)
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)
	var title := _label("SEWING CIRCLE - choose once", Vector2(24, 16), Vector2(890, 36))
	title.theme_type_variation = "PatchHeading"
	title.add_theme_font_size_override("font_size", 26)
	upgrade_button = _button("Upgrade - free", Vector2(24, 62), Vector2(280, 48))
	stitch_button = _button("Stitch - %d scraps" % RunRestStitchCards.SCRAP_COST, Vector2(330, 62), Vector2(280, 48))
	leave_button = _button("Leave - free", Vector2(636, 62), Vector2(280, 48))
	status_label = _label("", Vector2(24, 120), Vector2(892, 54))
	choice_scroll = ScrollContainer.new()
	choice_scroll.position = Vector2(24, 184)
	choice_scroll.size = Vector2(440, 350)
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(choice_scroll)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 8)
	choice_scroll.add_child(choices)
	preview_scroll = ScrollContainer.new()
	preview_scroll.position = Vector2(488, 184)
	preview_scroll.size = Vector2(428, 350)
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(preview_scroll)
	preview_label = Label.new()
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_color_override("font_color", INK)
	preview_label.add_theme_font_size_override("font_size", 18)
	preview_scroll.add_child(preview_label)
	confirm_button = _button("Confirm choice", Vector2(24, 556), Vector2(892, 44))
	_connect_session()
	_refresh()
	# A visit bound before this panel was mounted becomes keyboard-ready here:
	# the first primary action takes focus, exactly as a rebind does.
	if _active():
		upgrade_button.grab_focus()


func _label(text: String, at: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	return label


func _button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = dimensions
	button.size = dimensions
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	# The shared theme leaves Button ink at engine defaults, where hover, press
	# and focus are near-white on this cream felt: every state keeps dark ink,
	# and an action the visit cannot pay for stays legible but visibly duller.
	for color_name in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, INK)
	button.add_theme_color_override("font_disabled_color", DISABLED_INK)
	if ResourceLoader.exists(BUTTON_ART, "Texture2D"):
		var fabric := StyleBoxTexture.new()
		fabric.texture = load(BUTTON_ART)
		fabric.set_texture_margin_all(22)
		button.add_theme_stylebox_override("normal", fabric)
		var dimmed := StyleBoxTexture.new()
		dimmed.texture = fabric.texture
		dimmed.set_texture_margin_all(22)
		dimmed.modulate_color = Color(0.72, 0.72, 0.74)
		button.add_theme_stylebox_override("disabled", dimmed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("#2e5b88")
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	add_child(button)
	return button


## Capture the original source, including visit identity, without retaining caller data.
func bind(visit: RunSewingCircleVisit) -> void:
	_epoch += 1
	_visit = visit
	_source = visit.read_state() if visit != null else {}
	_submitted = false
	_reset_selection()
	if is_node_ready():
		_connect_session()
		_refresh()
		if _active():
			upgrade_button.grab_focus()


func close() -> void:
	bind(null)
	visible = false


func _active() -> bool:
	return _visit != null and not _submitted and _visit.quote().get("ok", false) \
		and _visit.read_state() == _source


func _reset_selection() -> void:
	_mode = ""
	_first = -1
	_second = -1
	_preview = {}


## Connect this session's own callbacks. A rebind or close first retires the
## previous session's four, and only those: a recipient's own listener on one of
## these buttons is never silently dropped, and a retired callback can only act
## through its old epoch, which no longer matches.
func _connect_session() -> void:
	_retire_session()
	if not _active():
		return
	_session[upgrade_button] = _choose_mode.bind("upgrade", _epoch)
	_session[stitch_button] = _choose_mode.bind("stitch", _epoch)
	_session[leave_button] = _choose_mode.bind("leave", _epoch)
	_session[confirm_button] = _confirm.bind(_epoch)
	for button in _session:
		button.pressed.connect(_session[button])


func _retire_session() -> void:
	for button in _session:
		if is_instance_valid(button) and button.pressed.is_connected(_session[button]):
			button.pressed.disconnect(_session[button])
	_session.clear()


func _clear_options() -> void:
	option_buttons.clear()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()


func _refresh() -> void:
	visible = true
	_clear_options()
	var active := _active()
	upgrade_button.disabled = not active or _visit.upgrade_options().is_empty()
	stitch_button.disabled = not active or _visit.stitch_first_options().is_empty()
	leave_button.disabled = not active
	confirm_button.disabled = true
	preview_label.text = "Choose Upgrade, Stitch or Leave, then confirm."
	if not active:
		status_label.text = "Visit closed or awaiting controller settlement."
		return
	status_label.text = "%d scraps. Upgrade: free. Stitch: %d scraps. Leave: free." % [
		_source.remaining_scraps, RunRestStitchCards.SCRAP_COST]
	if _source.remaining_scraps < RunRestStitchCards.SCRAP_COST:
		status_label.text += " Insufficient scraps to stitch."
	elif _visit.stitch_first_options().is_empty():
		status_label.text += " No different-owner pair available."
	var options: Array = []
	match _mode:
		"upgrade": options = _visit.upgrade_options()
		"stitch":
			options = _visit.stitch_first_options() if _first < 0 else _visit.stitch_second_options(_first)
		"leave":
			preview_label.text = "Leave without changing your deck or spending scraps."
			confirm_button.disabled = false
	for option in options:
		var caption := "%s | %s | copy #%d" % [option.get("display_name", option.get("name", "")), option.owner, option.index + 1]
		var button := _button(caption, Vector2.ZERO, Vector2(414, 52))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		remove_child(button)
		choices.add_child(button)
		button.set_meta("option", option.duplicate(true))
		button.pressed.connect(_select.bind(option.index, _epoch))
		button.focus_entered.connect(choice_scroll.ensure_control_visible.bind(button))
		option_buttons.append(button)
	if _mode == "stitch" and _first >= 0:
		preview_label.text = "First: copy #%d. Choose a different owner's card.\nPress Stitch again to change the first card." % (_first + 1)
	_wire_focus()


func _wire_focus() -> void:
	var chain: Array[Button] = []
	for button in [upgrade_button, stitch_button, leave_button] + option_buttons + [confirm_button]:
		if not button.disabled:
			chain.append(button)
	for i in range(chain.size()):
		chain[i].focus_next = chain[i].get_path_to(chain[(i + 1) % chain.size()])
		chain[i].focus_previous = chain[i].get_path_to(chain[(i - 1 + chain.size()) % chain.size()])


func _choose_mode(mode: String, epoch: int) -> void:
	if epoch != _epoch or not _active():
		return
	_reset_selection()
	_mode = mode
	_refresh()
	if not option_buttons.is_empty():
		option_buttons[0].grab_focus()
	elif not confirm_button.disabled:
		confirm_button.grab_focus()


func _select(index: int, epoch: int) -> void:
	if epoch != _epoch or not _active():
		return
	var options: Array = _visit.upgrade_options() if _mode == "upgrade" else \
		(_visit.stitch_first_options() if _first < 0 else _visit.stitch_second_options(_first))
	for option in options:
		if option.index != index:
			continue
		if _mode == "upgrade":
			_first = index
			_preview = option.duplicate(true)
			preview_label.text = "%s -> %s\nEnergy: %d -> %d\nBefore: %s\nAfter: %s\nCost: free. Only copy #%d changes." % [option.display_name, option.plus_display_name, option.cost, option.plus_cost, _effects(option.effects), _effects(option.plus_effects), index + 1]
		elif _mode == "stitch" and _first < 0:
			_first = index
			_refresh()
			if not option_buttons.is_empty():
				option_buttons[0].grab_focus()
			return
		elif _mode == "stitch":
			_second = index
			_preview = _visit.stitch_preview(_first, _second)
			if _preview.is_empty():
				return
			preview_label.text = "%s\nFirst (%s): %s\nSecond (%s): %s\nEnergy: %d. Scraps: %d -> %d\nDeck: %d -> %d cards. Consumes copies #%d and #%d in this order." % [_preview.display_name, _preview.first_owner, _effects(_preview.first_half.effects), _preview.second_owner, _effects(_preview.second_half.effects), _preview.energy_cost, _source.remaining_scraps, _preview.remaining_scraps, _preview.deck_before_count, _preview.deck_after_count, _first + 1, _second + 1]
		else:
			return
		confirm_button.disabled = false
		_wire_focus()
		confirm_button.grab_focus()
		return


func _effects(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in effects:
		parts.append("%s %s" % [str(key).replace("_", " "), str(effects[key])])
	return ", ".join(parts)


func preview() -> Dictionary:
	return _preview.duplicate(true)


func _confirm(epoch: int) -> void:
	if epoch != _epoch or not _active() or confirm_button.disabled:
		return
	var intent := {"action": _mode, "first_index": _first, "second_index": _second,
		"visit_id": _source.visit_id, "node_id": _source.node_id,
		"source_snapshot": _source.duplicate(true)}
	_submitted = true
	_reset_selection()
	_refresh()
	# Each emission owns its nested snapshot; observers cannot alter the binding.
	intent_requested.emit(intent.duplicate(true))
