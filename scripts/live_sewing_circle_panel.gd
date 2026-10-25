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
## A regenerated occurrence list has its own guard: retiring rows on a mode or
## stitch-stage change must invalidate queued/old pressed callbacks as well.
var _rows_epoch := 0
## Trusted row/button bindings are separate from mutable UI metadata.
var _row_indices: Dictionary = {}
var _submitted := false
var _mode := ""
var _first := -1
var _second := -1
var _preview: Dictionary = {}
## The one detached payload this session's own Confirm emitted, held until the
## bound controller consumes it. Nothing outside _confirm may mint it.
var _confirmed: Dictionary = {}
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
	_confirmed.clear()
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
	_rows_epoch += 1
	_row_indices.clear()
	option_buttons.clear()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	choice_scroll.scroll_vertical = 0


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
		option_buttons.append(_option_row(option, _mode == "upgrade"))
	if _mode == "stitch" and _first >= 0:
		var chosen_first: Dictionary = {}
		for candidate in _visit.stitch_first_options():
			if candidate.index == _first:
				chosen_first = candidate
				break
		if not chosen_first.is_empty():
			preview_label.text = "First: %s | %s | copy #%d | %d energy.\nChoose a DIFFERENT owner's card below.\nPress Stitch again to change the first card." % [
				chosen_first.owner.capitalize(), chosen_first.name, _first + 1, chosen_first.cost]
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
	if epoch != _epoch or not _active() or not is_visible_in_tree():
		return
	var action: Button = upgrade_button if mode == "upgrade" else stitch_button if mode == "stitch" else leave_button if mode == "leave" else null
	if action == null or action.disabled or not action.is_visible_in_tree():
		return
	_reset_selection()
	_mode = mode
	_refresh()
	if not option_buttons.is_empty():
		option_buttons[0].grab_focus()
	elif not confirm_button.disabled:
		confirm_button.grab_focus()



func _select(index: int, epoch: int, rows_epoch: int = -1, row: Variant = null) -> void:
	if epoch != _epoch or not _active() or not is_visible_in_tree() \
			or (rows_epoch >= 0 and rows_epoch != _rows_epoch):
		return
	if rows_epoch >= 0 and (not is_instance_valid(row) or not option_buttons.has(row)
			or _row_indices.get(row, -1) != index or row.disabled or not row.is_visible_in_tree()):
		return
	var options: Array = _visit.upgrade_options() if _mode == "upgrade" else \
		(_visit.stitch_first_options() if _first < 0 else _visit.stitch_second_options(_first))
	for option in options:
		if option.index != index:
			continue
		if _mode == "upgrade":
			_first = index
			_mark_selected(index, option.owner)
			_preview = option.duplicate(true)
			preview_label.text = "%s | copy #%d\n%s -> %s\nEnergy: %d -> %d\nBefore: %s\nAfter: %s\nCost: free. Only copy #%d changes." % [option.owner.capitalize(), index + 1, option.display_name, option.plus_display_name, option.cost, option.plus_cost, _effects(option.effects), _effects(option.plus_effects), index + 1]
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
			_mark_selected(index, option.owner)
			preview_label.text = "%s\nFirst (%s): %s | %d energy | %s\nSecond (%s): %s | %d energy | %s\nOrdered halves: %s THEN %s\nEnergy: %d. Scraps: %d -> %d (cost %d)\nDeck: %d -> %d cards. Consumes copies #%d and #%d in this order.\nBoth owners must be alive in legal FROM positions to play." % [_preview.display_name, _preview.first_owner.capitalize(), _preview.first_name, _preview.first_cost, _effects(_preview.first_half.effects), _preview.second_owner.capitalize(), _preview.second_name, _preview.second_cost, _effects(_preview.second_half.effects), _preview.first_name, _preview.second_name, _preview.energy_cost, _source.remaining_scraps, _preview.remaining_scraps, _preview.scrap_cost, _preview.deck_before_count, _preview.deck_after_count, _first + 1, _second + 1]
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
	if epoch != _epoch or not _active() or confirm_button.disabled \
			or not is_visible_in_tree() or not confirm_button.is_visible_in_tree():
		return
	var intent := {"action": _mode, "first_index": _first, "second_index": _second,
		"visit_id": _source.visit_id, "node_id": _source.node_id,
		"source_snapshot": _source.duplicate(true)}
	# Capture the exact selection this physical Confirm owns before the panel
	# forgets it, so a controller may settle only this one emitted decision.
	_confirmed = intent.duplicate(true)
	_submitted = true
	_reset_selection()
	_refresh()
	# Each emission owns its nested snapshot; observers cannot alter the binding.
	intent_requested.emit(intent.duplicate(true))


## One-shot hand-off for the bound controller: the detached payload this panel's
## own Confirm emitted, and only for that exact intent. A direct listener call, a
## stale payload or an altered action/index gets nothing and consumes nothing.
func take_confirmed(intent: Variant) -> Dictionary:
	if not _submitted or _confirmed.is_empty() or typeof(intent) != TYPE_DICTIONARY \
			or intent != _confirmed:
		return {}
	var confirmed := _confirmed.duplicate(true)
	_confirmed.clear()
	return confirmed


## Every option remains a single source-index Button; decorations cannot
## intercept input or become independent focus/activation targets.
func _option_row(option: Dictionary, upgrade: bool) -> Button:
	var owner: String = option.get("owner", "")
	var name: String = option.get("display_name", option.get("name", ""))
	var caption := "%s | %s | copy #%d | %d energy" % [
		name, owner, option.index + 1, option.get("cost", 0)]
	if upgrade:
		caption += " | Before: %s | After: %s | %d energy | %s" % [
			_effects(option.effects), option.plus_display_name, option.plus_cost,
			_effects(option.plus_effects)]
	var height := 192 if upgrade else 100
	var button := _button(caption, Vector2.ZERO, Vector2(414, height))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Preserve the complete canonical accessible caption while placed ink labels
	# render its lines without the Button's text being painted twice.
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	remove_child(button)
	choices.add_child(button)
	var stripe := ColorRect.new()
	stripe.color = _owner_color(owner)
	stripe.position = Vector2(5, 6)
	stripe.size = Vector2(9, height - 12)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.focus_mode = Control.FOCUS_NONE
	button.add_child(stripe)
	_card_label(button, "%s | copy #%d" % [owner.capitalize(), option.index + 1],
		Vector2(24, 8), Vector2(292, 22), 15)
	_card_label(button, name, Vector2(24, 32), Vector2(288, 37), 17)
	var coin := Panel.new()
	coin.position = Vector2(322, 34)
	coin.size = Vector2(82, 32)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.focus_mode = Control.FOCUS_NONE
	var coin_style: StyleBox
	if ResourceLoader.exists(BUTTON_ART, "Texture2D"):
		var fabric := StyleBoxTexture.new()
		fabric.texture = ResourceLoader.load(BUTTON_ART)
		fabric.set_texture_margin_all(12)
		coin_style = fabric
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("#dfc99a")
		flat.border_color = INK
		flat.set_border_width_all(1)
		coin_style = flat
	coin.add_theme_stylebox_override("panel", coin_style)
	button.add_child(coin)
	var cost_label := _card_label(coin, "%d energy" % option.get("cost", 0),
		Vector2(2, 3), Vector2(78, 25), 14)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if upgrade:
		_card_label(button, "BEFORE | %d energy\n%s" % [option.cost, _effects(option.effects)],
			Vector2(24, 72), Vector2(375, 51), 15)
		_card_label(button, "AFTER | %s | %d energy\n%s" % [
			option.plus_display_name, option.plus_cost, _effects(option.plus_effects)],
			Vector2(24, 126), Vector2(375, 61), 15)
	else:
		_card_label(button, "Source: %d energy. Select this occurrence." % option.cost,
			Vector2(24, 71), Vector2(372, 23), 14)
	button.set_meta("option", option.duplicate(true))
	button.set_meta("selected", false)
	button.set_meta("normal_style", button.get_theme_stylebox("normal"))
	button.set_meta("hover_style", button.get_theme_stylebox("hover"))
	_row_indices[button] = option.index
	button.pressed.connect(_select.bind(option.index, _epoch, _rows_epoch, button))
	button.focus_entered.connect(choice_scroll.ensure_control_visible.bind(button))
	return button


func _card_label(parent: Control, message: String, at: Vector2,
		dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = message
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	parent.add_child(label)
	return label


func _owner_color(owner: String) -> Color:
	match owner:
		"warden": return Color("#477394")
		"seamstress": return Color("#a25775")
		"tinker": return Color("#8b7440")
		_: return Color("#746c60")


func _mark_selected(index: int, owner: String) -> void:
	for button in option_buttons:
		var selected: bool = _row_indices.get(button, -1) == index
		button.set_meta("selected", selected)
		if selected:
			var sewn := StyleBoxFlat.new()
			sewn.bg_color = Color("#e5d6b6")
			sewn.border_color = _owner_color(owner)
			sewn.set_border_width_all(3)
			button.add_theme_stylebox_override("normal", sewn)
			button.add_theme_stylebox_override("hover", sewn)
		else:
			button.add_theme_stylebox_override("normal", button.get_meta("normal_style"))
			button.add_theme_stylebox_override("hover", button.get_meta("hover_style"))
