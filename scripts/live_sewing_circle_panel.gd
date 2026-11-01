class_name LiveSewingCirclePanel
extends Control
## Independently mounted presentation. Only the recipient controller settles intent.
signal intent_requested(intent: Dictionary)

const BUTTON_ART := "res://assets/paper/ui/reward_button.png"
const INK := Color("#28313c")
## Readable, visibly duller ink for an action the visit cannot pay for.
const DISABLED_INK := Color("#7a7267")
## Printed shortcuts. Each caption names the physical key that activates the
## very same Button, so the mapping stays visible on the shipped screen.
const UPGRADE_TEXT := "1 Upgrade - free"
const STITCH_TEXT := "2 Stitch - %d scraps"
const LEAVE_TEXT := "0 Leave - free"
const CONFIRM_TEXT := "3 Confirm choice"
## ART v3 (owner order 7): the already-authored sewn panel image is the only
## decoration this stop animates. One input-inert, clipped, faint copy of that
## same image drifts and breathes behind the fixed cream felt, labels,
## scrollers, buttons and focus rectangles; no actual control, price, focus or
## scroll position ever moves. The motion is a pure deterministic function of
## accumulated presentation delta (7 s breath, 11 s drift, no RNG, no wall
## clock), stops and returns to the exact static baseline on every close, hide,
## rebind, invalid/stale/consumed source, missing art or accessibility
## reduced_motion request, and has a nullable override for focused tests.
const PANEL_ART := "res://assets/paper/ui/reward_panel.png"
## Decorative drift of the authored panel image: about a 1% scale breath plus a
## few pixels of drift, both exactly at rest at elapsed zero and at every
## shared period. No RNG and no wall clock; the caller accumulates a
## deterministic delta.
const PANEL_ART_BREATH := 0.012
const PANEL_ART_PAN := Vector2(3.0, 2.0)
const PANEL_ART_BREATH_PERIOD := 7.0
const PANEL_ART_PAN_PERIOD := 11.0
## The drifting copy stays oversized for the sewn frame by this margin, so its
## breath and drift never expose an image edge or an empty seam; the felt
## backing additionally clips it to the panel's own 940x620 rect.
const PANEL_ART_OVERSCAN := 10.0
## Faint draw of the authored image over the cream felt, so the dark ink, costs
## and stitched outline keep their readable contrast.
const PANEL_ART_TINT := Color(1.0, 1.0, 1.0, 0.18)
const REDUCED_MOTION_SETTING := "accessibility/reduced_motion"
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
var filter_buttons: Array[Button] = []
var _owner_filter := ""
var _filter_owners: Dictionary = {}
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

## The already-authored sewn panel image, honoured by the optional faint
## drifting layer. A missing image keeps the flat cream felt fallback and
## installs no drifting layer at all.
var panel_art_texture: Texture2D
## Nullable explicit reduced-motion override for focused tests and hosts; null
## follows ProjectSettings accessibility/reduced_motion (default false).
var reduced_motion_override: Variant = null
## The one animated decoration: an input-inert child Panel of the felt backing,
## under every label, scroller and button of this panel, holding a faint second
## static-image stylebox that only ever breathes and drifts. Never a button,
## never focusable, never a layout member.
var _art_drift: Panel = null
var _art_drift_base := Vector2.ZERO
var _art_motion_elapsed := 0.0


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
	# Anything the faint drifting copy paints outside the sewn frame is clipped
	# away, so the animation can never show an image edge or an empty seam.
	paper.clip_contents = true
	if panel_art_texture == null:
		panel_art_texture = _load_panel_art()
	_install_art_drift(paper)
	visibility_changed.connect(_on_art_visibility_changed)
	var title := _label("SEWING CIRCLE - choose once", Vector2(24, 16), Vector2(890, 36))
	title.theme_type_variation = "PatchHeading"
	title.add_theme_font_size_override("font_size", 26)
	upgrade_button = _button(UPGRADE_TEXT, Vector2(24, 62), Vector2(280, 48))
	stitch_button = _button(STITCH_TEXT % RunRestStitchCards.SCRAP_COST, Vector2(330, 62), Vector2(280, 48))
	leave_button = _button(LEAVE_TEXT, Vector2(636, 62), Vector2(280, 48))
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
	confirm_button = _button(CONFIRM_TEXT, Vector2(24, 556), Vector2(892, 44))
	_connect_session()
	_refresh()
	# A visit bound before this panel was mounted becomes keyboard-ready here:
	# the first primary action takes focus, exactly as a rebind does.
	_focus_initial()


## The physical number keys are an alias for the four mounted Buttons. A valid
## press only forwards to that Button's own `pressed` signal, so keyboard, mouse,
## Tab and Enter keep one authenticated path: the handler never calls the visit,
## spends scraps or mints an intent of its own. It stays inert when the panel is
## hidden, the visit is closed/stale/rebound, the GUI focus already belongs to
## another panel, the event is a release/echo/modified key, or the addressed
## action is disabled.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed:
		return
	var button := _shortcut_action(key.keycode)
	if button == null or not is_visible_in_tree() or not _active():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or (focus_owner != self and not is_ancestor_of(focus_owner)):
		return
	if button.disabled or not button.is_visible_in_tree():
		return
	get_viewport().set_input_as_handled()
	button.pressed.emit()


func _shortcut_action(keycode: int) -> Button:
	match keycode:
		KEY_1, KEY_KP_1: return upgrade_button
		KEY_2, KEY_KP_2: return stitch_button
		KEY_0, KEY_KP_0: return leave_button
		KEY_3, KEY_KP_3: return confirm_button
	return null


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
	# A different bound visit (or none at all) restarts the decorative drift
	# from its exact static baseline; the motion never influences the binding.
	_reset_art_motion()
	_visit = visit
	_source = visit.read_state() if visit != null else {}
	_submitted = false
	_confirmed.clear()
	_reset_selection()
	if is_node_ready():
		_connect_session()
		_refresh()
		_focus_initial()


func close() -> void:
	bind(null)
	visible = false


func _active() -> bool:
	return _visit != null and not _submitted and _visit.quote().get("ok", false) \
		and _visit.read_state() == _source


func _reset_selection() -> void:
	_mode = ""
	_owner_filter = ""
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
	_filter_owners.clear()
	filter_buttons.clear()
	option_buttons.clear()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	choice_scroll.scroll_vertical = 0


func _refresh() -> void:
	visible = true
	_clear_options()
	var active := _active()
	# An inactive/confirmed visit must restore the physical art layer now, even
	# when _process is paused (e.g. a mounted deterministic test).
	if not active:
		_reset_art_motion()
	var quoted: Array = _visit.quote().get("choices", []) if active else []
	upgrade_button.disabled = not active or not quoted.has("upgrade") or _visit.upgrade_options().is_empty()
	stitch_button.disabled = not active or not quoted.has("stitch") or _visit.stitch_first_options().is_empty()
	leave_button.disabled = not active or not quoted.has("leave")
	confirm_button.disabled = true
	preview_label.text = "Choose Upgrade, Stitch or Leave, then confirm."
	if not active:
		status_label.text = "Visit closed or awaiting controller settlement."
		return
	preview_label.text = _neutral_prompt(quoted)
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
	if not options.is_empty():
		_add_filters(options)
	for option in options:
		if not _owner_filter.is_empty() and option.owner != _owner_filter:
			continue
		var row := _option_row(option, _mode == "upgrade")
		if row != null:
			option_buttons.append(row)
	if _mode == "stitch" and _first >= 0 and not option_buttons.is_empty():
		var pair := _stitch_projection(_first, _row_indices[option_buttons[0]])
		if not pair.is_empty():
			preview_label.text = "FIRST | %s\nChoose a DIFFERENT owner's card for THEN.\nBoth owners must be alive, each in their own legal FROM position to play.\nPress Stitch again to change the first card." % [
				_card_detail(pair.first_half, _first)]
	_wire_focus()


## Navigation is derived from this stage's genuine options, never a hero catalog.
## Chips and rows share the same generation, so refreshing either retires both.
func _add_filters(options: Array) -> void:
	var owners: Array[String] = [""]
	for option in options:
		if not owners.has(option.owner):
			owners.append(option.owner)
	var strip := HFlowContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_constant_override("h_separation", 4)
	strip.add_theme_constant_override("v_separation", 4)
	choices.add_child(strip)
	for owner in owners:
		var chip := _button("All" if owner.is_empty() else owner.capitalize(),
			Vector2.ZERO, Vector2(0, 32))
		chip.add_theme_font_size_override("font_size", 14)
		var sewn := chip.get_theme_stylebox("normal").duplicate() as StyleBox
		if sewn is StyleBoxTexture:
			sewn.set_texture_margin_all(8)
		if not ResourceLoader.exists(BUTTON_ART, "Texture2D"):
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color("#e5d6b6")
			flat.border_color = INK
			flat.set_border_width_all(1)
			sewn = flat
		sewn.content_margin_left = 6
		sewn.content_margin_right = 6
		sewn.content_margin_top = 4
		sewn.content_margin_bottom = 4
		chip.add_theme_stylebox_override("normal", sewn)
		chip.add_theme_stylebox_override("hover", sewn)
		var selected := StyleBoxFlat.new()
		selected.bg_color = Color("#e5d6b6")
		selected.border_color = INK
		selected.set_border_width_all(2)
		selected.content_margin_left = 6
		selected.content_margin_right = 6
		selected.content_margin_top = 4
		selected.content_margin_bottom = 4
		chip.add_theme_stylebox_override("pressed", selected)
		chip.add_theme_stylebox_override("hover_pressed", selected)
		chip.toggle_mode = true
		chip.set_pressed_no_signal(owner == _owner_filter)
		remove_child(chip)
		strip.add_child(chip)
		filter_buttons.append(chip)
		_filter_owners[chip] = owner
		chip.pressed.connect(_choose_filter.bind(owner, _epoch, _rows_epoch, chip))
		chip.focus_entered.connect(choice_scroll.ensure_control_visible.bind(chip))


func _choose_filter(owner: String, epoch: int, rows_epoch: int, chip: Variant) -> void:
	if epoch != _epoch or rows_epoch != _rows_epoch or not is_visible_in_tree():
		return
	if not _active():
		_reset_selection()
		_refresh()
		return
	if not is_instance_valid(chip) or not filter_buttons.has(chip) \
			or _filter_owners.get(chip) != owner or chip.disabled or not chip.is_visible_in_tree():
		return
	_owner_filter = owner
	if _mode == "upgrade":
		_first = -1
	# Both modes rebuild below. Stitch keeps its FIRST occurrence so _refresh
	# asks the visit for that occurrence's authoritative THEN options; browsing
	# either stage must retire the old partner, preview and confirmation.
	_second = -1
	_preview.clear()
	_confirmed.clear()
	_refresh()
	for button in filter_buttons:
		if _filter_owners[button] == owner:
			button.grab_focus()
			break


func _neutral_prompt(quoted: Array) -> String:
	var actions: Array[String] = []
	if quoted.has("upgrade") and not upgrade_button.disabled:
		actions.append("Upgrade")
	if quoted.has("stitch") and not stitch_button.disabled:
		actions.append("Stitch")
	if quoted.has("leave") and not leave_button.disabled:
		actions.append("Leave")
	match actions.size():
		3: return "Choose %s, %s or %s, then confirm." % [actions[0], actions[1], actions[2]]
		2: return "Choose %s or %s, then confirm." % [actions[0], actions[1]]
		1: return "Choose %s, then confirm." % actions[0]
	return "Choose Upgrade, Stitch or Leave, then confirm."


func _focus_initial() -> void:
	if not _active():
		return
	for button in [upgrade_button, stitch_button, leave_button]:
		if not button.disabled:
			button.grab_focus()
			return


func _wire_focus() -> void:
	var chain: Array[Button] = []
	for button in [upgrade_button, stitch_button, leave_button] + filter_buttons + option_buttons + [confirm_button]:
		button.focus_next = NodePath()
		button.focus_previous = NodePath()
		if not button.disabled:
			chain.append(button)
	for i in range(chain.size()):
		chain[i].focus_next = chain[i].get_path_to(chain[(i + 1) % chain.size()])
		chain[i].focus_previous = chain[i].get_path_to(chain[(i - 1 + chain.size()) % chain.size()])


func _choose_mode(mode: String, epoch: int) -> void:
	if epoch != _epoch or not is_visible_in_tree():
		return
	if not _active():
		_reset_selection()
		_refresh()
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
	if epoch != _epoch or not is_visible_in_tree() \
			or (rows_epoch >= 0 and rows_epoch != _rows_epoch):
		return
	if not _active():
		_reset_selection()
		_refresh()
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
			var definitions := _upgrade_definitions(option)
			if definitions.is_empty():
				return
			_first = index
			_mark_selected(index, option.owner)
			_preview = option.duplicate(true)
			preview_label.text = "Upgrade ONE original card\nBEFORE | %s\nAFTER | %s\nCost: free. Only copy #%d changes." % [
				_card_detail(definitions.before, index),
				_card_detail(definitions.after, index), index + 1]
		elif _mode == "stitch" and _first < 0:
			var partners := _visit.stitch_second_options(index)
			if partners.is_empty() or _stitch_projection(index, partners[0].index).is_empty():
				return
			_first = index
			_owner_filter = ""
			_refresh()
			if not option_buttons.is_empty():
				option_buttons[0].grab_focus()
			return
		elif _mode == "stitch":
			var pair := _stitch_projection(_first, index)
			if pair.is_empty():
				return
			_second = index
			_preview = pair.duplicate(true)
			_mark_selected(index, option.owner)
			preview_label.text = "%s\nFIRST | %s\nTHEN | %s\nEnergy: %d (max half + 1, capped at 3). Scraps: %d -> %d (cost %d)\nDeck: %d -> %d cards. Consumes copies #%d and #%d in this order.\nBoth owners must be alive, each in their own legal FROM position to play." % [
				pair.display_name, _card_detail(pair.first_half, _first),
				_card_detail(pair.second_half, _second), pair.energy_cost,
				_source.remaining_scraps, pair.remaining_scraps, pair.scrap_cost,
				pair.deck_before_count, pair.deck_after_count, _first + 1, _second + 1]
		else:
			return
		confirm_button.disabled = false
		_wire_focus()
		confirm_button.grab_focus()
		return


## Present only the exact fields supplied by the authenticated option/preview.
## Keep the authored actions in a stable reading order, and expose unfamiliar
## source fields as readable key/value text rather than guessing their rules.
func _effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return "No effects"
	var parts: PackedStringArray = []
	var known: Array[String] = ["damage", "block", "heal", "bleed", "weak", "draw"]
	var extras: Array = effects.keys()
	extras.sort()
	var ordered: Array = []
	for key in known:
		if effects.has(key):
			ordered.append(key)
	for key in extras:
		if not known.has(key):
			ordered.append(key)
	for key in ordered:
		var amount: String = str(effects[key])
		var phrase := ""
		match str(key):
			"damage": phrase = "Deal %s damage" % amount
			"block": phrase = "Gain %s Block" % amount
			"heal": phrase = "Heal %s HP" % amount
			"bleed": phrase = "Apply Bleed %s" % amount
			"weak": phrase = "Apply Weak %s" % amount
			"draw": phrase = "Draw %s card%s" % [amount, "" if amount == "1" else "s"]
			_: phrase = "%s: %s" % [str(key).replace("_", " "), amount]
		if not parts.is_empty():
			phrase = phrase.substr(0, 1).to_lower() + phrase.substr(1)
		parts.append(phrase)
	return "; ".join(parts)


func preview() -> Dictionary:
	return _preview.duplicate(true)


func _confirm(epoch: int) -> void:
	if epoch != _epoch or not is_visible_in_tree() or not confirm_button.is_visible_in_tree():
		return
	if not _active():
		_reset_selection()
		_refresh()
		return
	if confirm_button.disabled:
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


## Display only a resolved authored definition, never an option's loose effect
## dictionary. The option's exact original occurrence and both catalog records
## must agree before its Help or Confirm becomes available.
func _upgrade_definitions(option: Dictionary) -> Dictionary:
	var index: Variant = option.get("index")
	var deck: Array = _source.get("deck", [])
	if typeof(index) != TYPE_INT or index < 0 or index >= deck.size() \
			or deck[index] != option.get("source_id"):
		return {}
	var before := RunRestStitchCards.resolve_card_definition(option.get("source_id"))
	var after := RunRestStitchCards.resolve_card_definition(option.get("plus_id"))
	if before.is_empty() or after.is_empty() or before.get("id") != option.get("source_id") \
			or after.get("id") != option.get("plus_id"):
		return {}
	for field in ["owner", "display_name", "cost", "effects"]:
		if before.get(field) != option.get(field):
			return {}
	if after.get("owner") != before.get("owner") \
			or after.get("display_name") != option.get("plus_display_name") \
			or after.get("cost") != option.get("plus_cost") \
			or after.get("effects") != option.get("plus_effects"):
		return {}
	return {"before": before, "after": after}


## A pair may come only from the live visit's authentic index-bound projection.
## Its two FULL authored halves are already provided in FIRST/THEN order.
func _stitch_projection(first_index: int, second_index: int) -> Dictionary:
	if not _active():
		return {}
	var pair := _visit.stitch_preview(first_index, second_index)
	var deck: Array = _source.get("deck", [])
	# The visit augments its Rest snapshot with node/visit identity and
	# consumed/valid flags; the stitch projection carries only the Rest ledger.
	var rest_source := _source.duplicate(true)
	for key in ["valid", "consumed", "node_id", "visit_id"]:
		rest_source.erase(key)
	if pair.is_empty() or first_index < 0 or second_index < 0 \
			or first_index >= deck.size() or second_index >= deck.size() \
			or first_index == second_index or pair.get("source_snapshot") != rest_source:
		return {}
	var first: Dictionary = pair.get("first_half", {})
	var second: Dictionary = pair.get("second_half", {})
	if first.is_empty() or second.is_empty() \
			or first.get("id") != deck[first_index] or second.get("id") != deck[second_index] \
			or first.get("owner") == second.get("owner") \
			or pair.get("first_id") != first.get("id") \
			or pair.get("second_id") != second.get("id") \
			or pair.get("first_owner") != first.get("owner") \
			or pair.get("second_owner") != second.get("owner") \
			or pair.get("first_name") != first.get("display_name") \
			or pair.get("second_name") != second.get("display_name") \
			or pair.get("first_cost") != first.get("cost") \
			or pair.get("second_cost") != second.get("cost"):
		return {}
	return pair


func _positions(definition: Dictionary) -> String:
	var target: String = str(definition.get("target_kind", ""))
	var recipient := ""
	match target:
		"enemy_single": recipient = "ENEMY TO %s" % str(definition.get("to_positions", []))
		"enemy_all": recipient = "ALL ENEMIES TO %s" % str(definition.get("to_positions", []))
		"enemy_random": recipient = "RANDOM ENEMY TO %s" % str(definition.get("to_positions", []))
		"self": recipient = "TARGET: self"
		"ally_single": recipient = "TARGET: chosen ally"
		"party_all": recipient = "TARGET: all allies"
		"none": recipient = "TARGET: no chosen target"
		_: recipient = "TARGET: %s" % target
	return "FROM %s | %s" % [str(definition.get("from_positions", [])), recipient]


func _card_detail(definition: Dictionary, index: int) -> String:
	return "%s | %s | %s | copy #%d | %d energy\n%s\n%s" % [
		str(definition.get("owner", "")).capitalize(),
		str(definition.get("display_name", "")), str(definition.get("id", "")),
		index + 1, int(definition.get("cost", 0)), _positions(definition),
		CardShortRules.line(definition)]


## Every option remains a single source-index Button; decorations cannot
## intercept input or become independent focus/activation targets.
func _option_row(option: Dictionary, upgrade: bool) -> Button:
	var owner: String = option.get("owner", "")
	var name: String = option.get("display_name", option.get("name", ""))
	var before: Dictionary = {}
	var after: Dictionary = {}
	var stage := "FIRST" if _first < 0 else "THEN"
	if upgrade:
		var definitions := _upgrade_definitions(option)
		if definitions.is_empty():
			return null
		before = definitions.before
		after = definitions.after
	else:
		var pair: Dictionary = {}
		if _first < 0:
			var partners := _visit.stitch_second_options(option.index)
			if not partners.is_empty():
				pair = _stitch_projection(option.index, partners[0].index)
			if not pair.is_empty():
				before = pair.first_half
		else:
			pair = _stitch_projection(_first, option.index)
			if not pair.is_empty():
				before = pair.second_half
		if before.is_empty() or before.get("id") != option.get("id") \
				or before.get("owner") != owner or before.get("cost") != option.get("cost") \
				or before.get("display_name") != name:
			return null
	var caption := "%s | %s | copy #%d | %d energy" % [
		name, owner, option.index + 1, option.get("cost", 0)]
	var detail := ""
	if upgrade:
		detail = "BEFORE | %s\nAFTER | %s\nUpgrade: free. Only this original copy changes." % [
			_card_detail(before, option.index), _card_detail(after, option.index)]
	else:
		detail = "%s | %s\nStitch: %d scraps for a different-owner pair. Both owners alive and at their legal FROM positions." % [
			stage, _card_detail(before, option.index), RunRestStitchCards.SCRAP_COST]
	var height := 116
	var button := _button(caption, Vector2.ZERO, Vector2(414, height))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = detail
	# Preserve the complete accessible caption and full hover/focus Help.
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
		Vector2(24, 8), Vector2(292, 22), 16)
	_card_label(button, name, Vector2(24, 32), Vector2(276, 37), 17)
	var coin := Panel.new()
	coin.position = Vector2(306, 34)
	coin.size = Vector2(98, 32)
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
		Vector2(2, 3), Vector2(94, 25), 16)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if upgrade:
		_card_label(button, "Free upgrade: %s | %d energy" % [after.display_name, after.cost],
			Vector2(24, 72), Vector2(375, 40), 16)
	else:
		_card_label(button, "%s | Stitch pair: %d scraps" % [stage, RunRestStitchCards.SCRAP_COST],
			Vector2(24, 72), Vector2(375, 40), 16)
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


## The optional authored panel art; a missing or unloadable resource stays null
## and the panel keeps today's flat cream felt fallback with no drifting layer
## at all. ResourceLoader follows the .import remap of this PNG to its exported
## CompressedTexture2D (.ctex), so the source PNG need not exist as a loose
## file; FileAccess cannot follow that remap and must never gate this load.
static func _load_panel_art() -> Texture2D:
	if not ResourceLoader.exists(PANEL_ART, "Texture2D"):
		return null
	return ResourceLoader.load(PANEL_ART, "Texture2D") as Texture2D


## The faint authored backdrop style of the drifting layer: the sewn panel
## image drawn gently over the cream felt so dark ink stays readable.
func _art_layer_style() -> StyleBoxTexture:
	var texture := StyleBoxTexture.new()
	texture.texture = panel_art_texture
	texture.modulate_color = PANEL_ART_TINT
	texture.set_texture_margin_all(24)
	return texture


## The one animated decoration: a second, input-inert, faint copy of the
## authored sewn panel image mounted under every label, scroller and action of
## this panel. Only its own presentation transform ever moves; the panel
## itself, the sewn frame and every real rectangle stay exactly fixed.
func _install_art_drift(host_panel: Panel) -> void:
	if panel_art_texture == null:
		return
	var layer := Panel.new()
	layer.name = "PanelArtDrift"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.focus_mode = Control.FOCUS_NONE
	layer.add_theme_stylebox_override("panel", _art_layer_style())
	host_panel.add_child(layer)
	_art_drift_base = Vector2.ONE * -PANEL_ART_OVERSCAN
	layer.custom_minimum_size = custom_minimum_size + Vector2.ONE * (PANEL_ART_OVERSCAN * 2.0)
	layer.size = layer.custom_minimum_size
	layer.position = _art_drift_base
	layer.pivot_offset = layer.size * 0.5
	_art_drift = layer


## Pure deterministic presentation transform: a slow ~1% scale breath on a 7 s
## period plus a few pixels of drift on an 11 s period, both exactly at rest at
## elapsed zero and at every shared period. No RNG and no wall clock.
static func art_motion_transform_at(elapsed: float) -> Dictionary:
	var breath := 0.5 - 0.5 * cos(TAU * fposmod(elapsed, PANEL_ART_BREATH_PERIOD) / PANEL_ART_BREATH_PERIOD)
	var clock := TAU * fposmod(elapsed, PANEL_ART_PAN_PERIOD) / PANEL_ART_PAN_PERIOD
	return {
		"scale": 1.0 + PANEL_ART_BREATH * breath,
		"offset": Vector2(sin(clock), sin(2.0 * clock)) * PANEL_ART_PAN,
	}


## Motion runs only while a genuinely mounted, visible panel holds an
## authentic, unconsumed, not-yet-submitted bound visit with the authored art
## loaded and reduced motion not requested. It never quotes a price, spends a
## scrap or draws randomness; every stop path restores the exact static
## baseline transform.
func art_motion_active() -> bool:
	return _art_drift != null and is_instance_valid(_art_drift) and panel_art_texture != null \
			and _visit != null and not _submitted and _visit.is_valid() and not _visit.is_consumed() \
			and is_inside_tree() and is_visible_in_tree() and not _reduced_motion_active()


## Current decorative transform: the static baseline whenever motion is
## stopped, otherwise the deterministic transform at the accumulated
## presentation time.
func art_motion_transform() -> Dictionary:
	if not art_motion_active():
		return {"scale": 1.0, "offset": Vector2.ZERO}
	return art_motion_transform_at(_art_motion_elapsed)


## Deterministic presentation-time advance for focused tests; live play
## accumulates the very same clock through _process with the engine delta.
func advance_art_motion(delta: float) -> void:
	if not art_motion_active():
		_reset_art_motion()
		return
	if delta <= 0.0:
		return
	_art_motion_elapsed += delta
	_apply_art_motion()


## The setting defaults to off; a nullable explicit override lets tests and
## hosts force the presentation on or off deterministically.
func set_reduced_motion_override(value: Variant) -> void:
	reduced_motion_override = value
	if not art_motion_active():
		_reset_art_motion()


func _reduced_motion_active() -> bool:
	if reduced_motion_override != null:
		return bool(reduced_motion_override)
	return bool(ProjectSettings.get_setting(REDUCED_MOTION_SETTING, false))


## Every stop path (close/bind(null)/rebind, hide, exit-tree, invalid, stale,
## consumed or externally settled visit, submitted Confirm, missing art,
## reduced motion) restores the exact static baseline position and scale of
## the decorative image.
func _reset_art_motion() -> void:
	if _art_motion_elapsed == 0.0:
		return
	_art_motion_elapsed = 0.0
	if is_instance_valid(_art_drift):
		_art_drift.pivot_offset = _art_drift.size * 0.5
		_art_drift.scale = Vector2.ONE
		_art_drift.position = _art_drift_base


func _apply_art_motion() -> void:
	if not is_instance_valid(_art_drift):
		return
	var motion := art_motion_transform_at(_art_motion_elapsed)
	var offset: Vector2 = motion["offset"]
	_art_drift.pivot_offset = _art_drift.size * 0.5
	_art_drift.scale = Vector2.ONE * float(motion["scale"])
	_art_drift.position = _art_drift_base + offset


func _on_art_visibility_changed() -> void:
	if not is_visible_in_tree():
		_reset_art_motion()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_reset_art_motion()


## Accumulated presentation delta alone drives the decoration; it never calls
## the visit, the stitch/upgrade services, the route or any RNG.
func _process(delta: float) -> void:
	if not art_motion_active():
		_reset_art_motion()
		return
	if delta > 0.0:
		_art_motion_elapsed += delta
		_apply_art_motion()
